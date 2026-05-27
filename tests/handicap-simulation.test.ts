import { describe, it, expect } from 'vitest';
import { mulberry32 } from '../src/lib/utils/seeded-rng';
import {
	simulateTournamentEnd,
	aggregateSimulations
} from '../src/lib/utils/handicap-simulation';
import type {
	SimulationState,
	SlotSnapshot,
	MatchSnapshot,
	ParticipantSnapshot
} from '../src/lib/utils/handicap-simulation-state';

// ── Construcció d'un bracket sintètic de 4 jugadors ───────────────────────────
//
// Winners:  R1 (W1, W2) → R2 (W3 final winners)
// Losers:   L1 (perdedors W1 i W2) → L2 (perdedor W3 vs guanyador L1)
// GF:       GF1, GF2
//
// Slots IDs: w-r1-p1, w-r1-p2, w-r1-p3, w-r1-p4, w-r2-p1, w-r2-p2,
//            l-r1-p1, l-r1-p2, l-r2-p1, l-r2-p2,
//            gf-r1-p1, gf-r1-p2, gf-r2-p1, gf-r2-p2

function buildFourPlayerState(): SimulationState {
	const slots: SlotSnapshot[] = [
		{ id: 'w-r1-p1', bracket_type: 'winners', ronda: 1, posicio: 1, is_bye: false, participant_id: 'p1' },
		{ id: 'w-r1-p2', bracket_type: 'winners', ronda: 1, posicio: 2, is_bye: false, participant_id: 'p4' },
		{ id: 'w-r1-p3', bracket_type: 'winners', ronda: 1, posicio: 3, is_bye: false, participant_id: 'p2' },
		{ id: 'w-r1-p4', bracket_type: 'winners', ronda: 1, posicio: 4, is_bye: false, participant_id: 'p3' },
		{ id: 'w-r2-p1', bracket_type: 'winners', ronda: 2, posicio: 1, is_bye: false, participant_id: null },
		{ id: 'w-r2-p2', bracket_type: 'winners', ronda: 2, posicio: 2, is_bye: false, participant_id: null },
		{ id: 'l-r1-p1', bracket_type: 'losers', ronda: 1, posicio: 1, is_bye: false, participant_id: null },
		{ id: 'l-r1-p2', bracket_type: 'losers', ronda: 1, posicio: 2, is_bye: false, participant_id: null },
		{ id: 'l-r2-p1', bracket_type: 'losers', ronda: 2, posicio: 1, is_bye: false, participant_id: null },
		{ id: 'l-r2-p2', bracket_type: 'losers', ronda: 2, posicio: 2, is_bye: false, participant_id: null },
		{ id: 'gf-r1-p1', bracket_type: 'grand_final', ronda: 1, posicio: 1, is_bye: false, participant_id: null },
		{ id: 'gf-r1-p2', bracket_type: 'grand_final', ronda: 1, posicio: 2, is_bye: false, participant_id: null },
		{ id: 'gf-r2-p1', bracket_type: 'grand_final', ronda: 2, posicio: 1, is_bye: false, participant_id: null },
		{ id: 'gf-r2-p2', bracket_type: 'grand_final', ronda: 2, posicio: 2, is_bye: false, participant_id: null }
	];

	const matches: MatchSnapshot[] = [
		{
			id: 'm-w1',
			slot1_id: 'w-r1-p1',
			slot2_id: 'w-r1-p2',
			winner_slot_dest_id: 'w-r2-p1',
			loser_slot_dest_id: 'l-r1-p1',
			estat: 'pendent',
			guanyador_participant_id: null,
			data_programada: null,
			hora_inici: null,
			taula_assignada: null
		},
		{
			id: 'm-w2',
			slot1_id: 'w-r1-p3',
			slot2_id: 'w-r1-p4',
			winner_slot_dest_id: 'w-r2-p2',
			loser_slot_dest_id: 'l-r1-p2',
			estat: 'pendent',
			guanyador_participant_id: null,
			data_programada: null,
			hora_inici: null,
			taula_assignada: null
		},
		{
			id: 'm-w3', // final winners
			slot1_id: 'w-r2-p1',
			slot2_id: 'w-r2-p2',
			winner_slot_dest_id: 'gf-r1-p1',
			loser_slot_dest_id: 'l-r2-p1',
			estat: 'pendent',
			guanyador_participant_id: null,
			data_programada: null,
			hora_inici: null,
			taula_assignada: null
		},
		{
			id: 'm-l1',
			slot1_id: 'l-r1-p1',
			slot2_id: 'l-r1-p2',
			winner_slot_dest_id: 'l-r2-p2',
			loser_slot_dest_id: null,
			estat: 'pendent',
			guanyador_participant_id: null,
			data_programada: null,
			hora_inici: null,
			taula_assignada: null
		},
		{
			id: 'm-l2', // final losers
			slot1_id: 'l-r2-p1',
			slot2_id: 'l-r2-p2',
			winner_slot_dest_id: 'gf-r1-p2',
			loser_slot_dest_id: null,
			estat: 'pendent',
			guanyador_participant_id: null,
			data_programada: null,
			hora_inici: null,
			taula_assignada: null
		},
		{
			id: 'm-gf1',
			slot1_id: 'gf-r1-p1',
			slot2_id: 'gf-r1-p2',
			winner_slot_dest_id: 'gf-r2-p1',
			loser_slot_dest_id: 'gf-r2-p2',
			estat: 'pendent',
			guanyador_participant_id: null,
			data_programada: null,
			hora_inici: null,
			taula_assignada: null
		},
		{
			id: 'm-gf2',
			slot1_id: 'gf-r2-p1',
			slot2_id: 'gf-r2-p2',
			winner_slot_dest_id: null,
			loser_slot_dest_id: null,
			estat: 'pendent',
			guanyador_participant_id: null,
			data_programada: null,
			hora_inici: null,
			taula_assignada: null
		}
	];

	const participants: ParticipantSnapshot[] = [
		{ id: 'p1', preferencies_dies: [], preferencies_hores: [], seed: 1 },
		{ id: 'p2', preferencies_dies: [], preferencies_hores: [], seed: 2 },
		{ id: 'p3', preferencies_dies: [], preferencies_hores: [], seed: 3 },
		{ id: 'p4', preferencies_dies: [], preferencies_hores: [], seed: 4 }
	];

	return {
		eventId: 'test-event',
		estatCompeticio: 'en_curs',
		config: {
			data_inici: '2026-06-01', // Dilluns
			data_fi: '2026-06-30'
		},
		participants,
		matches,
		slots,
		occupiedSlotsExternal: [],
		dataMinima: '2026-06-01'
	};
}

describe('simulateTournamentEnd', () => {
	it('simula un torneig de 4 jugadors fins al final', () => {
		const state = buildFourPlayerState();
		const rng = mulberry32(42);
		const result = simulateTournamentEnd(state, rng);

		expect(result.endDate).not.toBeNull();
		expect(result.endDate!).toMatch(/^2026-\d{2}-\d{2}$/);
		expect(result.endDate! >= '2026-06-01').toBe(true);
		expect(result.endDate! <= '2026-07-31').toBe(true);
		// 6 partides reals + 1 que pot ser GF2 si reset
		expect(result.matchesPlayed).toBeGreaterThanOrEqual(6);
		expect(result.matchesPlayed).toBeLessThanOrEqual(7);
	});

	it('produeix endDate determinista amb la mateixa seed', () => {
		const r1 = simulateTournamentEnd(buildFourPlayerState(), mulberry32(123));
		const r2 = simulateTournamentEnd(buildFourPlayerState(), mulberry32(123));
		expect(r1.endDate).toBe(r2.endDate);
		expect(r1.matchesPlayed).toBe(r2.matchesPlayed);
		expect(r1.usedResetMatch).toBe(r2.usedResetMatch);
	});

	it('aggregate calcula percentils correctament', () => {
		const state = buildFourPlayerState();
		const results = Array.from({ length: 50 }, (_, i) =>
			simulateTournamentEnd(state, mulberry32(i + 1))
		);
		const agg = aggregateSimulations(results, state.config.data_fi);

		expect(agg.dates.length).toBe(50);
		expect(agg.p10).not.toBeNull();
		expect(agg.p50).not.toBeNull();
		expect(agg.p90).not.toBeNull();
		expect(agg.p10! <= agg.p50!).toBe(true);
		expect(agg.p50! <= agg.p90!).toBe(true);
		expect(agg.withinDataFiPct).toBeGreaterThanOrEqual(0);
		expect(agg.withinDataFiPct).toBeLessThanOrEqual(1);
	});

	it('resol incompatibilitat de disponibilitats amb sorteig 50/50', () => {
		const state = buildFourPlayerState();
		// p1 només dilluns, p4 només dijous → han de jugar al W1 amb incompatibilitat total
		state.participants[0].preferencies_dies = ['dl'];
		state.participants[3].preferencies_dies = ['dj'];
		const result = simulateTournamentEnd(state, mulberry32(7));

		expect(result.endDate).not.toBeNull();
		// Almenys un match s'ha resolt per coin flip (el W1)
		expect(result.resolvedByCoinFlip).toBeGreaterThanOrEqual(1);
	});
});
