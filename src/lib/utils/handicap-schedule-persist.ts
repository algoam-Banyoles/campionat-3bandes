/**
 * Persistència de l'horari complet del torneig hàndicap.
 *
 * Pren l'event hàndicap actiu, carrega bracket + participants amb les seves
 * disponibilitats, calcula la pre-programació + l'optimizer, i escriu el
 * resultat a `calendari_partides` (UPSERT per a cada match), enllaçant cada
 * fila amb `handicap_matches.calendari_partida_id`.
 *
 * Els matches de R2+ amb jugadors no resolts queden amb soci_numero NULL —
 * són "pre-reserves" del calendari; quan l'auto-schedule completi resultats
 * posteriors, ja existeix l'entrada i només s'actualitza.
 */
import type { SupabaseClient } from '@supabase/supabase-js';
import {
	preSchedulingForBracket,
	type PreSchedulerSlot,
	type PreSchedulerMatch
} from './handicap-pre-scheduler';
import {
	optimizeSchedule,
	type ParticipantAvailability
} from './handicap-schedule-optimizer';

export interface PersistOptions {
	/** Dies festius o vetats (no es programen partides). */
	diesBloquejats?: Date[];
}

export interface PersistResult {
	programats: number;
	nous: number;
	actualitzats: number;
	errors: string[];
	dataFiEfectiva: string | null;
}

function pad(n: number): string {
	return String(n).padStart(2, '0');
}

function toLocalIsoNoon(d: Date): string {
	// YYYY-MM-DD format usat per al camp data_programada (timestamp).
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/**
 * Parser senzill del camp text `restriccions_especials`. Reconeix:
 *   - "1, 2, 3 i 5 de juny no" → bloqueja dies 1, 2, 3, 5 de juny.
 *   - "no pot el 12 d'agost" → bloqueja dia 12 d'agost.
 *   - "a partir del 9 de juny" → fixa dataDisponibleDes = 9 juny.
 *
 * Si el patró no es reconeix, retorna llistes buides. L'admin pot afinar la
 * disponibilitat amb els camps preferencies_dies / preferencies_hores i amb
 * dies concrets a sobrar — el parser és un best-effort.
 */
const MESOS_CAT: Record<string, number> = {
	gener: 0, febrer: 1, març: 2, marc: 2, abril: 3, maig: 4, juny: 5,
	juliol: 6, agost: 7, setembre: 8, octubre: 9, novembre: 10, desembre: 11
};
export function parseRestriccionsText(
	text: string | null | undefined,
	year: number
): { diesNoDisponibles: Date[]; dataDisponibleDes?: Date } {
	const out: { diesNoDisponibles: Date[]; dataDisponibleDes?: Date } = { diesNoDisponibles: [] };
	if (!text) return out;
	const lower = text.toLowerCase();

	// Patró: dies separats per , o "i", seguit de "de <mes>"
	const dieRe = /(\d+(?:\s*,\s*\d+|\s+i\s+\d+)*)\s+(?:de|d')\s*([a-zçñ]+)/gi;
	let m: RegExpExecArray | null;
	while ((m = dieRe.exec(lower)) !== null) {
		const mes = m[2];
		const mesIdx = MESOS_CAT[mes];
		if (mesIdx === undefined) continue;
		const dies = m[1].split(/[,\s]+|\s+i\s+/).map(s => parseInt(s, 10)).filter(n => !isNaN(n));
		for (const dia of dies) {
			out.diesNoDisponibles.push(new Date(year, mesIdx, dia));
		}
	}

	// Patró "a partir del N de mes" → dataDisponibleDes
	const partirRe = /a partir del?\s+(\d+)(?:\s+(?:de|d'))?\s*([a-zçñ]+)?/i;
	const pm = partirRe.exec(lower);
	if (pm) {
		const dia = parseInt(pm[1], 10);
		const mes = pm[2] ? MESOS_CAT[pm[2]] : undefined;
		if (!isNaN(dia) && mes !== undefined) {
			out.dataDisponibleDes = new Date(year, mes, dia);
		}
	}
	return out;
}

export async function persistFullSchedule(
	supabase: SupabaseClient,
	eventId: string,
	options: PersistOptions = {}
): Promise<PersistResult> {
	const result: PersistResult = {
		programats: 0,
		nous: 0,
		actualitzats: 0,
		errors: [],
		dataFiEfectiva: null
	};

	const { data: ev, error: evErr } = await supabase
		.from('events')
		.select('id, data_inici, data_fi')
		.eq('id', eventId)
		.single();
	if (evErr || !ev?.data_inici || !ev?.data_fi) {
		result.errors.push("Event hàndicap no trobat o sense dates configurades.");
		return result;
	}

	const { data: cfg } = await supabase
		.from('handicap_config')
		.select('horaris_extra')
		.eq('event_id', eventId)
		.maybeSingle();

	const { data: slotsData, error: sErr } = await supabase
		.from('handicap_bracket_slots')
		.select('id, bracket_type, ronda, posicio, participant_id')
		.eq('event_id', eventId);
	if (sErr || !slotsData || slotsData.length === 0) {
		result.errors.push("Bracket no generat encara — fes primer el sorteig.");
		return result;
	}

	const { data: matchesData, error: mErr } = await supabase
		.from('handicap_matches')
		.select('id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id, estat, calendari_partida_id, calendari_fixat')
		.eq('event_id', eventId);
	if (mErr || !matchesData) {
		result.errors.push("Matches no trobats.");
		return result;
	}

	const slots = slotsData as Array<PreSchedulerSlot & { participant_id: string | null }>;
	const matchesAll = matchesData as Array<PreSchedulerMatch & { calendari_partida_id: string | null; calendari_fixat?: boolean }>;
	// Saltem byes, jugats i matches marcats com a fixats (data forçada per l'admin).
	const playables = matchesAll.filter(
		m => m.estat !== 'bye' && m.estat !== 'jugada' && !m.calendari_fixat
	);

	const { data: participants } = await supabase
		.from('handicap_participants')
		.select('id, soci_numero, preferencies_dies, preferencies_hores, restriccions_especials')
		.eq('event_id', eventId);

	const dataInici = new Date(ev.data_inici);
	const dataFi = new Date(ev.data_fi);
	const yearReferencia = dataInici.getFullYear();

	const sociByParticipant = new Map<string, number>();
	const availabilities = new Map<string, ParticipantAvailability>();
	for (const p of participants ?? []) {
		sociByParticipant.set(p.id, p.soci_numero);
		const parsed = parseRestriccionsText(p.restriccions_especials, yearReferencia);
		availabilities.set(p.id, {
			participantId: p.id,
			preferenciesDies: p.preferencies_dies ?? [],
			preferenciesHores: p.preferencies_hores ?? [],
			diesNoDisponibles: parsed.diesNoDisponibles.length > 0 ? parsed.diesNoDisponibles : undefined,
			dataDisponibleDes: parsed.dataDisponibleDes
		});
	}

	let scheduled;
	try {
		scheduled = preSchedulingForBracket(slots, playables, {
			dataInici,
			dataFi,
			horesEstandard: ['18:00', '19:00'],
			horarisExtra: cfg?.horaris_extra ?? null,
			billars: 3,
			diesBloquejats: options.diesBloquejats
		});
	} catch (e: any) {
		result.errors.push(`Error en pre-scheduling: ${e?.message ?? e}`);
		return result;
	}

	const optResult = optimizeSchedule({
		slots,
		matches: playables,
		scheduled,
		availabilities,
		dataPrevistaFi: dataFi,
		calendari: {
			dataInici,
			dataFi,
			horesEstandard: ['18:00', '19:00'],
			horarisExtra: cfg?.horaris_extra ?? null,
			billars: 3
		}
	});
	result.dataFiEfectiva = optResult.dataFiEfectiva
		? toLocalIsoNoon(optResult.dataFiEfectiva)
		: null;

	// PASSADA 1: alliberar tots els slots actuals (taula_assignada = NULL) per
	// evitar conflictes amb l'índex únic 'idx_unique_billar_slot' durant els
	// updates posteriors. L'índex és parcial: només actua amb tots els camps
	// no-null, així posant taula a NULL sortim de l'índex i podem reorganitzar.
	const existingCalendariIds = playables
		.map(m => m.calendari_partida_id)
		.filter((id): id is string => !!id);
	if (existingCalendariIds.length > 0) {
		const { error: clearErr } = await supabase
			.from('calendari_partides')
			.update({ taula_assignada: null, data_programada: null, hora_inici: null })
			.in('id', existingCalendariIds);
		if (clearErr) {
			result.errors.push(`CLEAR slots: ${clearErr.message}`);
		}
	}

	const slotById = new Map(slots.map(s => [s.id, s]));
	for (const m of playables) {
		const sched = optResult.scheduled.get(m.id);
		if (!sched) continue;

		const s1 = slotById.get(m.slot1_id);
		const s2 = slotById.get(m.slot2_id);
		const soci1 = s1?.participant_id ? sociByParticipant.get(s1.participant_id) ?? null : null;
		const soci2 = s2?.participant_id ? sociByParticipant.get(s2.participant_id) ?? null : null;

		const dataIso = toLocalIsoNoon(sched.dataProgramada);
		const partidaData = {
			event_id: eventId,
			categoria_id: null as string | null,
			jugador1_soci_numero: soci1,
			jugador2_soci_numero: soci2,
			data_programada: `${dataIso}T${sched.horaInici}:00`,
			hora_inici: `${sched.horaInici}:00`,
			taula_assignada: sched.taulaAssignada,
			estat: 'generat'
		};

		if (m.calendari_partida_id) {
			const { error } = await supabase
				.from('calendari_partides')
				.update(partidaData)
				.eq('id', m.calendari_partida_id);
			if (error) {
				result.errors.push(`UPDATE ${m.id}: ${error.message}`);
			} else {
				result.actualitzats++;
				result.programats++;
			}
		} else {
			const { data: newRow, error } = await supabase
				.from('calendari_partides')
				.insert(partidaData)
				.select('id')
				.single();
			if (error || !newRow) {
				result.errors.push(`INSERT ${m.id}: ${error?.message ?? '?'}`);
				continue;
			}
			const { error: linkErr } = await supabase
				.from('handicap_matches')
				.update({ calendari_partida_id: newRow.id })
				.eq('id', m.id);
			if (linkErr) {
				result.errors.push(`LINK ${m.id}: ${linkErr.message}`);
			} else {
				result.nous++;
				result.programats++;
			}
		}
	}

	return result;
}
