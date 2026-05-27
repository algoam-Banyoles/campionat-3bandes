/**
 * Carrega l'estat actual d'un torneig hàndicap en una estructura pura
 * (sense client de BD), per a alimentar la simulació Monte Carlo.
 *
 * Separat del motor de simulació per permetre testar el motor amb estats
 * sintètics i sense Supabase.
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import type { TournamentConfig, OccupiedSlot } from './handicap-scheduler';

export type MatchEstat = 'pendent' | 'programada' | 'jugada' | 'bye' | 'walkover';

export interface SlotSnapshot {
	id: string;
	bracket_type: 'winners' | 'losers' | 'grand_final';
	ronda: number;
	posicio: number;
	is_bye: boolean;
	participant_id: string | null;
}

export interface ParticipantSnapshot {
	id: string;
	preferencies_dies: string[];
	preferencies_hores: string[];
	seed: number | null;
}

export interface MatchSnapshot {
	id: string;
	slot1_id: string;
	slot2_id: string;
	winner_slot_dest_id: string | null;
	loser_slot_dest_id: string | null;
	estat: MatchEstat;
	guanyador_participant_id: string | null;
	/** Data 'YYYY-MM-DD' si està programada o jugada. */
	data_programada: string | null;
	hora_inici: string | null;
	taula_assignada: number | null;
}

export interface SimulationState {
	eventId: string;
	estatCompeticio: string;
	config: TournamentConfig;
	participants: ParticipantSnapshot[];
	matches: MatchSnapshot[];
	slots: SlotSnapshot[];
	/** Slots ocupats per altres campionats (no del torneig hàndicap). */
	occupiedSlotsExternal: OccupiedSlot[];
	/** Data més aviat possible per a noves programacions: max(avui, data_inici). */
	dataMinima: string;
}

interface HandicapEventRow {
	id: string;
	estat_competicio: string;
	data_inici: string | null;
	data_fi: string | null;
}

interface HandicapConfigRow {
	horaris_extra: { franja: string; dies: string[] } | null;
}

/**
 * Carrega l'estat del torneig hàndicap actiu (o el que es passi via eventId).
 * Retorna `null` si no hi ha torneig actiu o si no està la configuració mínima.
 */
export async function loadSimulationState(
	supabase: SupabaseClient,
	eventId?: string
): Promise<SimulationState | null> {
	// 1. Event actiu (o el que es passi)
	let event: HandicapEventRow | null = null;
	if (eventId) {
		const { data } = await supabase
			.from('events')
			.select('id, estat_competicio, data_inici, data_fi')
			.eq('id', eventId)
			.maybeSingle();
		event = data as HandicapEventRow | null;
	} else {
		const { data } = await supabase
			.from('events')
			.select('id, estat_competicio, data_inici, data_fi')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.order('creat_el', { ascending: false })
			.limit(1)
			.maybeSingle();
		event = data as HandicapEventRow | null;
	}

	if (!event || !event.data_inici || !event.data_fi) return null;

	// 2. Config (horaris_extra)
	const { data: cfgRow } = await supabase
		.from('handicap_config')
		.select('horaris_extra')
		.eq('event_id', event.id)
		.maybeSingle();
	const cfg = cfgRow as HandicapConfigRow | null;

	const config: TournamentConfig = {
		data_inici: event.data_inici,
		data_fi: event.data_fi,
		horaris_extra: cfg?.horaris_extra ?? undefined
	};

	// 3. Slots
	const { data: slotsRaw } = await supabase
		.from('handicap_bracket_slots')
		.select('id, bracket_type, ronda, posicio, is_bye, participant_id')
		.eq('event_id', event.id);

	const slots: SlotSnapshot[] = (slotsRaw ?? []).map((s: any) => ({
		id: s.id,
		bracket_type: s.bracket_type,
		ronda: s.ronda,
		posicio: s.posicio,
		is_bye: !!s.is_bye,
		participant_id: s.participant_id ?? null
	}));

	if (slots.length === 0) {
		// Bracket no generat encara
		return {
			eventId: event.id,
			estatCompeticio: event.estat_competicio,
			config,
			participants: [],
			matches: [],
			slots: [],
			occupiedSlotsExternal: [],
			dataMinima: computeDataMinima(config.data_inici)
		};
	}

	// 4. Matches
	const { data: matchesRaw } = await supabase
		.from('handicap_matches')
		.select(
			'id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id, estat, guanyador_participant_id, calendari_partida_id'
		)
		.eq('event_id', event.id);

	const calIds = (matchesRaw ?? [])
		.filter((m: any) => m.calendari_partida_id)
		.map((m: any) => m.calendari_partida_id as string);

	let calMap = new Map<string, { data: string; hora: string; taula: number | null }>();
	if (calIds.length > 0) {
		const { data: cals } = await supabase
			.from('calendari_partides')
			.select('id, data_programada, hora_inici, taula_assignada')
			.in('id', calIds);
		for (const c of cals ?? []) {
			const dataStr = (c.data_programada as string | null)?.substring(0, 10) ?? '';
			const horaStr = (c.hora_inici as string | null)?.substring(0, 5) ?? '';
			calMap.set(c.id as string, {
				data: dataStr,
				hora: horaStr,
				taula: (c.taula_assignada as number | null) ?? null
			});
		}
	}

	const matches: MatchSnapshot[] = (matchesRaw ?? []).map((m: any) => {
		const cal = m.calendari_partida_id ? calMap.get(m.calendari_partida_id) ?? null : null;
		return {
			id: m.id,
			slot1_id: m.slot1_id,
			slot2_id: m.slot2_id,
			winner_slot_dest_id: m.winner_slot_dest_id ?? null,
			loser_slot_dest_id: m.loser_slot_dest_id ?? null,
			estat: m.estat as MatchEstat,
			guanyador_participant_id: m.guanyador_participant_id ?? null,
			data_programada: cal?.data ?? null,
			hora_inici: cal?.hora ?? null,
			taula_assignada: cal?.taula ?? null
		};
	});

	// 5. Participants (només els necessaris)
	const partIds = [...new Set(slots.filter((s) => s.participant_id).map((s) => s.participant_id!))];

	let participants: ParticipantSnapshot[] = [];
	if (partIds.length > 0) {
		const { data: partsRaw } = await supabase
			.from('handicap_participants')
			.select('id, seed, preferencies_dies, preferencies_hores')
			.in('id', partIds);

		participants = (partsRaw ?? []).map((p: any) => ({
			id: p.id,
			seed: p.seed ?? null,
			preferencies_dies: Array.isArray(p.preferencies_dies) ? p.preferencies_dies : [],
			preferencies_hores: Array.isArray(p.preferencies_hores) ? p.preferencies_hores : []
		}));
	}

	// 6. Slots ocupats per altres campionats (excloure els d'aquest event)
	const { data: occRaw } = await supabase
		.from('calendari_partides')
		.select('event_id, data_programada, hora_inici, taula_assignada')
		.gte('data_programada', `${config.data_inici}T00:00:00`)
		.lte('data_programada', `${config.data_fi}T23:59:59`)
		.not('data_programada', 'is', null)
		.not('taula_assignada', 'is', null);

	const occupiedSlotsExternal: OccupiedSlot[] = (occRaw ?? [])
		.filter((p: any) => p.event_id !== event!.id)
		.map((p: any) => ({
			data: (p.data_programada as string).substring(0, 10),
			hora: (p.hora_inici as string).substring(0, 5),
			taula: p.taula_assignada as number
		}));

	return {
		eventId: event.id,
		estatCompeticio: event.estat_competicio,
		config,
		participants,
		matches,
		slots,
		occupiedSlotsExternal,
		dataMinima: computeDataMinima(config.data_inici)
	};
}

/** Retorna la data més aviat possible per programar (avui o data_inici, el que sigui més tard). */
function computeDataMinima(dataInici: string): string {
	const today = new Date();
	const y = today.getFullYear();
	const m = String(today.getMonth() + 1).padStart(2, '0');
	const d = String(today.getDate()).padStart(2, '0');
	const todayStr = `${y}-${m}-${d}`;
	return todayStr > dataInici ? todayStr : dataInici;
}
