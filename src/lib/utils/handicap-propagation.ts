/**
 * Lògica de propagació de resultats del torneig hàndicap.
 *
 * Flow:
 * 1. Detecta si és una partida de Gran Final (lògica especial)
 * 2. Actualitza calendari_partides (caramboles + entrades)
 * 3. Actualitza handicap_matches (estat + guanyador)
 * 4. Propaga guanyador a winner_slot_dest_id
 * 5. Propaga perdedor a loser_slot_dest_id (o marca eliminat)
 * 6. Resol byes en cascada si un slot acabat d'omplir és oposat a un bye
 * 7. Si és la Gran Final, tanca el torneig si escau
 * 8. Retorna nombre de noves partides programables i informació del campió
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import { autoScheduleReadyMatches } from './handicap-auto-schedule';
import type { SchedulingExecutionResult } from './handicap-scheduler-db';

// ── Tipus ─────────────────────────────────────────────────────────────────────

export interface SaveResultOpts {
	matchId: string;
	isWalkover: boolean;
	/** Null si walkover */
	caramboles1: number | null;
	/** Null si walkover */
	caramboles2: number | null;
	/** Null si walkover */
	entrades: number | null;
	/** Participant que ha guanyat */
	winnerParticipantId: string;
	/** Null si el perdedor ja era un bye */
	loserParticipantId: string | null;
	/** FK a calendari_partides (null si walkover sense programació) */
	calendariPartidaId: string | null;
}

export interface SaveResultResponse {
	ok: true;
	newSchedulableCount: number;
	/** Descripció textual del destí del guanyador */
	winnerDestDesc: string;
	/** Cert si és la Gran Final i el torneig s'ha acabat */
	isChampion: boolean;
	/** Participant campió (null si no és la final) */
	championParticipantId: string | null;
	/** Participant subcampió (null si no és la final) */
	subchampionParticipantId: string | null;
	/** Cert si la GF-R1 ha estat guanyada pel jugador del bracket perdedors i cal jugar el reset match */
	needsResetMatch: boolean;
	/** Resultat de la calendarització automàtica (null si torneig acabat o no hi ha config) */
	autoScheduled: SchedulingExecutionResult | null;
}

export interface SaveResultError {
	ok: false;
	error: string;
}

// ── Funció principal ──────────────────────────────────────────────────────────

export async function saveMatchResult(
	supabase: SupabaseClient,
	opts: SaveResultOpts
): Promise<SaveResultResponse | SaveResultError> {
	const { matchId, isWalkover, caramboles1, caramboles2, entrades, winnerParticipantId, loserParticipantId, calendariPartidaId } = opts;

	// ── 1. Carregar dades del match i slot1 ─────────────────────────────────

	const { data: match, error: mErr } = await supabase
		.from('handicap_matches')
		.select('id, event_id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id')
		.eq('id', matchId)
		.single();

	if (mErr || !match) {
		return { ok: false, error: mErr?.message ?? 'Partida no trobada' };
	}

	const eventId = match.event_id as string;

	// Obtenir bracket_type i ronda del slot1 (per detectar Gran Final)
	const { data: slot1Data, error: s1Err } = await supabase
		.from('handicap_bracket_slots')
		.select('id, bracket_type, ronda, participant_id')
		.eq('id', match.slot1_id)
		.single();

	if (s1Err || !slot1Data) {
		return { ok: false, error: s1Err?.message ?? 'Slot no trobat' };
	}

	const bracketType = slot1Data.bracket_type as string;
	const ronda = slot1Data.ronda as number;
	const isGF1 = bracketType === 'grand_final' && ronda === 1;
	const isGF2 = bracketType === 'grand_final' && ronda === 2;

	// En GF-R1: slot1 = jugador del bracket guanyadors, slot2 = jugador del bracket perdedors
	// Si guanya slot1 → campió directe (no cal R2)
	// Si guanya slot2 → reset match (cal R2)
	const winnersChampionWins = isGF1 && winnerParticipantId === (slot1Data.participant_id as string | null);

	// ── 2. Actualitzar calendari_partides ───────────────────────────────────

	if (calendariPartidaId) {
		const update: Record<string, unknown> = { estat: 'jugada' };
		if (!isWalkover) {
			update.caramboles_jugador1 = caramboles1;
			update.caramboles_jugador2 = caramboles2;
			update.entrades = entrades;
		}
		const { error: cpErr } = await supabase
			.from('calendari_partides')
			.update(update)
			.eq('id', calendariPartidaId);
		if (cpErr) return { ok: false, error: `Error actualitzant calendari: ${cpErr.message}` };
	}

	// ── 3. Actualitzar handicap_match ────────────────────────────────────────

	const newEstat = isWalkover ? 'walkover' : 'jugada';
	const { error: hmErr } = await supabase
		.from('handicap_matches')
		.update({ estat: newEstat, guanyador_participant_id: winnerParticipantId })
		.eq('id', matchId);
	if (hmErr) return { ok: false, error: `Error actualitzant partida: ${hmErr.message}` };

	// ── 4. Propagació condicionada ────────────────────────────────────────────

	let winnerDestDesc = 'Final';
	let needsResetMatch = false;

	if (winnersChampionWins) {
		// GF-R1 guanyada pel jugador del bracket guanyadors:
		// NO propagam a GF-R2 (no cal reset), marquem GF-R2 com a 'bye'
		winnerDestDesc = 'Campió del torneig';

		// Marcar GF-R2 com a bypass (trobem el match que té els slots de GF-R2)
		await markGFR2AsSkipped(supabase, eventId);

		// Marcar perdedor com a eliminat (subcampió → no s'elimina però ja no avança)
		if (loserParticipantId) {
			await supabase
				.from('handicap_participants')
				.update({ eliminat: true })
				.eq('id', loserParticipantId);
		}
	} else if (isGF1) {
		// GF-R1 guanyada pel jugador del bracket perdedors → cal reset match
		needsResetMatch = true;
		winnerDestDesc = 'Gran Final (Reset)';

		// Propagar ambdós jugadors a GF-R2
		if (match.winner_slot_dest_id) {
			const { error: wErr } = await supabase
				.from('handicap_bracket_slots')
				.update({ participant_id: winnerParticipantId })
				.eq('id', match.winner_slot_dest_id);
			if (wErr) return { ok: false, error: `Error propagant a GF-R2: ${wErr.message}` };
		}
		if (match.loser_slot_dest_id && loserParticipantId) {
			const { error: lErr } = await supabase
				.from('handicap_bracket_slots')
				.update({ participant_id: loserParticipantId })
				.eq('id', match.loser_slot_dest_id);
			if (lErr) return { ok: false, error: `Error propagant perdedor a GF-R2: ${lErr.message}` };
		}
	} else {
		// Partida normal (o GF-R2): propagació estàndard

		if (match.winner_slot_dest_id) {
			const { error: wErr } = await supabase
				.from('handicap_bracket_slots')
				.update({ participant_id: winnerParticipantId })
				.eq('id', match.winner_slot_dest_id);
			if (wErr) return { ok: false, error: `Error propagant guanyador: ${wErr.message}` };

			// Descripció del destí
			const { data: destSlot } = await supabase
				.from('handicap_bracket_slots')
				.select('bracket_type, ronda')
				.eq('id', match.winner_slot_dest_id)
				.single();
			if (destSlot) {
				winnerDestDesc = formatSlotDesc(destSlot.bracket_type as string, destSlot.ronda as number);
			}
		}

		if (loserParticipantId) {
			if (match.loser_slot_dest_id) {
				const { error: lErr } = await supabase
					.from('handicap_bracket_slots')
					.update({ participant_id: loserParticipantId })
					.eq('id', match.loser_slot_dest_id);
				if (lErr) return { ok: false, error: `Error propagant perdedor: ${lErr.message}` };
			} else {
				// Sense destí → eliminat
				const { error: elimErr } = await supabase
					.from('handicap_participants')
					.update({ eliminat: true })
					.eq('id', loserParticipantId);
				if (elimErr) return { ok: false, error: `Error marcant eliminat: ${elimErr.message}` };
			}
		}
	}

	// ── 5. Resoldre byes en cascada ──────────────────────────────────────────

	if (!isGF2 && !winnersChampionWins) {
		const byeErr = await resolveCascadeByes(supabase, eventId);
		if (byeErr) return { ok: false, error: byeErr };
	}

	// ── 6. Determinar campió i tancar torneig ─────────────────────────────────

	const isChampion = isGF2 || winnersChampionWins;
	let championParticipantId: string | null = null;
	let subchampionParticipantId: string | null = null;

	if (isChampion) {
		championParticipantId = winnerParticipantId;
		subchampionParticipantId = loserParticipantId;
		await closeTournament(supabase, eventId);
	}

	// ── 7. Calendaritzar automàticament les partides llestes ─────────────────

	let autoScheduled: SchedulingExecutionResult | null = null;
	let newSchedulableCount = 0;

	if (!isChampion) {
		autoScheduled = await autoScheduleReadyMatches(supabase, eventId);
		// newSchedulableCount reflecteix les que no s'han pogut programar (conflictes)
		if (autoScheduled) {
			newSchedulableCount = autoScheduled.conflicts;
		} else {
			newSchedulableCount = await countSchedulable(supabase, eventId);
		}
	}

	return {
		ok: true,
		newSchedulableCount,
		winnerDestDesc,
		isChampion,
		championParticipantId,
		subchampionParticipantId,
		needsResetMatch,
		autoScheduled
	};
}

// ── Tancar torneig ────────────────────────────────────────────────────────────

export async function closeTournament(
	supabase: SupabaseClient,
	eventId: string
): Promise<{ ok: boolean; error?: string }> {
	const { error } = await supabase
		.from('events')
		.update({ estat_competicio: 'finalitzat', actiu: false })
		.eq('id', eventId);
	if (error) return { ok: false, error: error.message };
	return { ok: true };
}

/**
 * Tanca manualment el torneig (botó admin).
 * Verifica que no queden partides pendents o programades.
 */
export async function closeTournamentManual(
	supabase: SupabaseClient,
	eventId: string
): Promise<{ ok: boolean; error?: string; pendingCount?: number }> {
	// Verificar que no queden partides pendents o programades
	const { data: pending } = await supabase
		.from('handicap_matches')
		.select('id')
		.eq('event_id', eventId)
		.in('estat', ['pendent', 'programada']);

	const pendingCount = pending?.length ?? 0;
	if (pendingCount > 0) {
		return { ok: false, error: `Queden ${pendingCount} partides sense jugar.`, pendingCount };
	}

	const result = await closeTournament(supabase, eventId);
	return result;
}

// ── Helpers privats ───────────────────────────────────────────────────────────

/**
 * Marca el match de GF-R2 com a 'bye' (no es jugarà perquè el jugador del
 * bracket guanyadors ha guanyat GF-R1 directament).
 */
async function markGFR2AsSkipped(supabase: SupabaseClient, eventId: string): Promise<void> {
	// Trobar els slots de GF ronda 2
	const { data: gfR2Slots } = await supabase
		.from('handicap_bracket_slots')
		.select('id')
		.eq('event_id', eventId)
		.eq('bracket_type', 'grand_final')
		.eq('ronda', 2);

	if (!gfR2Slots || gfR2Slots.length === 0) return;

	const gfR2SlotIds = gfR2Slots.map((s: any) => s.id as string);

	// Trobar el match que usa aquests slots
	const { data: gfR2Match } = await supabase
		.from('handicap_matches')
		.select('id')
		.eq('event_id', eventId)
		.in('slot1_id', gfR2SlotIds)
		.limit(1)
		.maybeSingle();

	if (gfR2Match) {
		await supabase
			.from('handicap_matches')
			.update({ estat: 'bye' })
			.eq('id', gfR2Match.id);
	}
}

function formatSlotDesc(bracketType: string, ronda: number): string {
	if (bracketType === 'grand_final') {
		return ronda === 1 ? 'Gran Final' : 'Gran Final (Reset)';
	}
	if (bracketType === 'winners') return `Guanyadors R${ronda}`;
	if (bracketType === 'losers') return `Perdedors R${ronda}`;
	return `R${ronda}`;
}

/**
 * Resol byes en cascada:
 * si un match pendent té un slot amb is_bye=true i l'altre ja té participant,
 * el participant avança automàticament.
 */
async function resolveCascadeByes(supabase: SupabaseClient, eventId: string): Promise<string | null> {
	for (let iter = 0; iter < 10; iter++) {
		const { data: matches } = await supabase
			.from('handicap_matches')
			.select('id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id')
			.eq('event_id', eventId)
			.eq('estat', 'pendent');

		if (!matches || matches.length === 0) break;

		const slotIds = matches.flatMap((m: any) => [m.slot1_id, m.slot2_id]);
		const { data: slots } = await supabase
			.from('handicap_bracket_slots')
			.select('id, participant_id, is_bye')
			.in('id', slotIds);

		if (!slots) break;

		const slotMap = new Map(slots.map((s: any) => [s.id as string, s]));
		let resolved = 0;

		for (const m of matches) {
			const s1 = slotMap.get(m.slot1_id);
			const s2 = slotMap.get(m.slot2_id);
			if (!s1 || !s2) continue;

			const s1bye = s1.is_bye as boolean;
			const s2bye = s2.is_bye as boolean;
			const s1pid = s1.participant_id as string | null;
			const s2pid = s2.participant_id as string | null;

			if (s1bye && s2pid) {
				const err = await resolveByeMatch(supabase, m, s2pid);
				if (err) return err;
				resolved++;
			} else if (s2bye && s1pid) {
				const err = await resolveByeMatch(supabase, m, s1pid);
				if (err) return err;
				resolved++;
			} else if (s1bye && s2bye) {
				const { error } = await supabase
					.from('handicap_matches')
					.update({ estat: 'bye' })
					.eq('id', m.id);
				if (error) return error.message;
				resolved++;
			}
		}

		if (resolved === 0) break;
	}

	return null;
}

async function resolveByeMatch(
	supabase: SupabaseClient,
	match: { id: string; winner_slot_dest_id: string | null; loser_slot_dest_id: string | null },
	winnerPid: string
): Promise<string | null> {
	const { error: e1 } = await supabase
		.from('handicap_matches')
		.update({ estat: 'bye', guanyador_participant_id: winnerPid })
		.eq('id', match.id);
	if (e1) return e1.message;

	if (match.winner_slot_dest_id) {
		const { error: e2 } = await supabase
			.from('handicap_bracket_slots')
			.update({ participant_id: winnerPid })
			.eq('id', match.winner_slot_dest_id);
		if (e2) return e2.message;
	}

	return null;
}

async function countSchedulable(supabase: SupabaseClient, eventId: string): Promise<number> {
	const { data: matches } = await supabase
		.from('handicap_matches')
		.select('slot1_id, slot2_id')
		.eq('event_id', eventId)
		.eq('estat', 'pendent');

	if (!matches || matches.length === 0) return 0;

	const slotIds = matches.flatMap((m: any) => [m.slot1_id, m.slot2_id]);
	const { data: slots } = await supabase
		.from('handicap_bracket_slots')
		.select('id, participant_id, is_bye')
		.in('id', slotIds);

	if (!slots) return 0;

	const slotMap = new Map(slots.map((s: any) => [s.id as string, s]));

	return matches.filter((m: any) => {
		const s1 = slotMap.get(m.slot1_id);
		const s2 = slotMap.get(m.slot2_id);
		return s1?.participant_id && s2?.participant_id && !s1.is_bye && !s2.is_bye;
	}).length;
}
