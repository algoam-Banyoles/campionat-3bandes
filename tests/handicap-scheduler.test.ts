import { describe, it, expect } from 'vitest';
import {
	scheduleMatches,
	type MatchToSchedule,
	type ParticipantAvailability,
	type TournamentConfig,
	type OccupiedSlot
} from '../src/lib/utils/handicap-scheduler';

// ── Helpers de construcció ────────────────────────────────────────────────────

function makeConfig(
	inici = '2026-03-02', // Dilluns
	fi = '2026-03-06',   // Divendres (1 setmana)
	horaris_extra?: TournamentConfig['horaris_extra']
): TournamentConfig {
	return { data_inici: inici, data_fi: fi, horaris_extra };
}

function makeAvail(
	id: string,
	dies: string[] = [],
	hores: string[] = []
): ParticipantAvailability {
	return { participant_id: id, preferencies_dies: dies, preferencies_hores: hores };
}

function makeMatch(
	id: string,
	p1: string,
	p2: string,
	ronda = 1,
	matchPos = 1,
	bracket_type: MatchToSchedule['bracket_type'] = 'winners'
): MatchToSchedule {
	return {
		id,
		bracket_type,
		ronda,
		matchPos,
		player1_participant_id: p1,
		player2_participant_id: p2,
		player1_player_id: `pl_${p1}`,
		player2_player_id: `pl_${p2}`
	};
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('scheduleMatches', () => {
	// ── Casos bàsics ──────────────────────────────────────────────────────────

	it('retorna array buit si no hi ha partides', () => {
		const results = scheduleMatches({
			matches: [],
			config: makeConfig(),
			participants: [],
			occupiedSlots: []
		});
		expect(results).toHaveLength(0);
	});

	it('programa correctament 2 jugadors sense restriccions', () => {
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig(),
			participants: [makeAvail('p1'), makeAvail('p2')],
			occupiedSlots: []
		});

		expect(results).toHaveLength(1);
		const r = results[0];
		expect(r.scheduled).toBe(true);
		if (r.scheduled) {
			expect(r.match_id).toBe('m1');
			expect(r.taula).toBeGreaterThanOrEqual(1);
			expect(r.taula).toBeLessThanOrEqual(3);
			expect(r.hora).toMatch(/^\d{2}:\d{2}$/);
			expect(r.data).toMatch(/^\d{4}-\d{2}-\d{2}$/);
		}
	});

	it('programa el primer slot disponible (dilluns 18:00 taula 1)', () => {
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig('2026-03-02', '2026-03-02'), // 1 sol dia
			participants: [makeAvail('p1'), makeAvail('p2')],
			occupiedSlots: []
		});

		expect(results[0].scheduled).toBe(true);
		if (results[0].scheduled) {
			expect(results[0].data).toBe('2026-03-02');
			expect(results[0].hora).toBe('18:00');
			expect(results[0].taula).toBe(1);
		}
	});

	// ── Conflictes d'horari ───────────────────────────────────────────────────

	it('retorna conflicte quan els jugadors no coincideixen en cap dia', () => {
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig(),
			participants: [
				makeAvail('p1', ['dl'], []),
				makeAvail('p2', ['dt'], [])
			],
			occupiedSlots: []
		});

		expect(results[0].scheduled).toBe(false);
		if (!results[0].scheduled) {
			expect(results[0].motiu).toContain('no coincideixen');
		}
	});

	it('retorna conflicte quan els jugadors no coincideixen en cap hora', () => {
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig(),
			participants: [
				makeAvail('p1', [], ['18:00']),
				makeAvail('p2', [], ['19:00'])
			],
			occupiedSlots: []
		});

		expect(results[0].scheduled).toBe(false);
	});

	// ── Restricció: 1 partida per jugador per dia ─────────────────────────────

	it('no programa un jugador dues vegades el mateix dia', () => {
		// 1 sol dia disponible; p1 juga a m1 i m2 → m2 ha de ser conflicte
		const results = scheduleMatches({
			matches: [
				makeMatch('m1', 'p1', 'p2', 1, 1),
				makeMatch('m2', 'p1', 'p3', 1, 2)
			],
			config: makeConfig('2026-03-02', '2026-03-02'),
			participants: [makeAvail('p1'), makeAvail('p2'), makeAvail('p3')],
			occupiedSlots: []
		});

		const m1 = results.find((r) => r.match_id === 'm1')!;
		const m2 = results.find((r) => r.match_id === 'm2')!;
		expect(m1.scheduled).toBe(true);
		expect(m2.scheduled).toBe(false);
	});

	it('distribueix les partides del mateix jugador en dies diferentss', () => {
		// 5 partides totes amb p1; 5 dies disponibles → una per dia
		const matches = Array.from({ length: 5 }, (_, i) =>
			makeMatch(`m${i}`, 'p1', `p${i + 2}`, 1, i + 1)
		);
		const participants = [
			makeAvail('p1'),
			...Array.from({ length: 5 }, (_, i) => makeAvail(`p${i + 2}`))
		];

		const results = scheduleMatches({
			matches,
			config: makeConfig('2026-03-02', '2026-03-06'), // dl-dv = 5 dies
			participants,
			occupiedSlots: []
		});

		const scheduled = results.filter(
			(r): r is Extract<(typeof r), { scheduled: true }> => r.scheduled
		);
		expect(scheduled).toHaveLength(5);

		// Totes en dies diferents (p1 no pot jugar dos vegades el mateix dia)
		const dates = scheduled.map((r) => r.data);
		expect(new Set(dates).size).toBe(5);
	});

	// ── Restricció: no repetir slot+taula ────────────────────────────────────

	it('no programa dues partides al mateix slot+taula', () => {
		// 6 partides, 1 dia, 2h × 3 taules = 6 slots — totes han de ser úniques
		const matches = Array.from({ length: 6 }, (_, i) =>
			makeMatch(`m${i}`, `p${2 * i + 1}`, `p${2 * i + 2}`, 1, i + 1)
		);
		const participants = Array.from({ length: 12 }, (_, i) => makeAvail(`p${i + 1}`));

		const results = scheduleMatches({
			matches,
			config: makeConfig('2026-03-02', '2026-03-02'),
			participants,
			occupiedSlots: []
		});

		const scheduled = results.filter(
			(r): r is Extract<(typeof r), { scheduled: true }> => r.scheduled
		);
		expect(scheduled).toHaveLength(6); // tots programats (6 slots exactament)

		const slotKeys = scheduled.map((r) => `${r.data}|${r.hora}|${r.taula}`);
		expect(new Set(slotKeys).size).toBe(6); // tots únics
	});

	it('retorna conflicte quan no queden slots disponibles', () => {
		// Tots els 6 slots de l'únic dia estan ocupats externament
		const occupied: OccupiedSlot[] = [
			{ data: '2026-03-02', hora: '18:00', taula: 1 },
			{ data: '2026-03-02', hora: '18:00', taula: 2 },
			{ data: '2026-03-02', hora: '18:00', taula: 3 },
			{ data: '2026-03-02', hora: '19:00', taula: 1 },
			{ data: '2026-03-02', hora: '19:00', taula: 2 },
			{ data: '2026-03-02', hora: '19:00', taula: 3 }
		];

		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig('2026-03-02', '2026-03-02'),
			participants: [makeAvail('p1'), makeAvail('p2')],
			occupiedSlots: occupied
		});

		expect(results[0].scheduled).toBe(false);
	});

	it('no usa slots ocupats per campionats socials', () => {
		// Ocupem 5 de 6 slots; la 7a partida ha de trobar l'últim slot lliure
		const occupied: OccupiedSlot[] = [
			{ data: '2026-03-02', hora: '18:00', taula: 1 },
			{ data: '2026-03-02', hora: '18:00', taula: 2 },
			{ data: '2026-03-02', hora: '18:00', taula: 3 },
			{ data: '2026-03-02', hora: '19:00', taula: 1 },
			{ data: '2026-03-02', hora: '19:00', taula: 2 }
			// taula 3 a les 19:00 queda lliure
		];

		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig('2026-03-02', '2026-03-02'),
			participants: [makeAvail('p1'), makeAvail('p2')],
			occupiedSlots: occupied
		});

		expect(results[0].scheduled).toBe(true);
		if (results[0].scheduled) {
			expect(results[0].hora).toBe('19:00');
			expect(results[0].taula).toBe(3);
		}
	});

	// ── Priorització de branques ──────────────────────────────────────────────

	it('prioritza R1 sobre R3 quan comparteixen jugador i només hi ha 1 slot', () => {
		// 1 dia, 1 slot lliure (5 de 6 ocupats)
		// m_r3: p1 vs p2 (R3) i m_r1: p1 vs p3 (R1) → p1 compartit
		// L'slot lliure ha d'anar al match de R1
		const occupied: OccupiedSlot[] = [
			{ data: '2026-03-02', hora: '18:00', taula: 1 },
			{ data: '2026-03-02', hora: '18:00', taula: 2 },
			{ data: '2026-03-02', hora: '18:00', taula: 3 },
			{ data: '2026-03-02', hora: '19:00', taula: 1 },
			{ data: '2026-03-02', hora: '19:00', taula: 2 }
			// 19:00 taula 3 = únic slot lliure
		];

		const results = scheduleMatches({
			matches: [
				makeMatch('r3', 'p1', 'p2', 3, 1, 'winners'),
				makeMatch('r1', 'p1', 'p3', 1, 1, 'winners')
			],
			config: makeConfig('2026-03-02', '2026-03-02'),
			participants: [makeAvail('p1'), makeAvail('p2'), makeAvail('p3')],
			occupiedSlots: occupied
		});

		const r1 = results.find((r) => r.match_id === 'r1')!;
		const r3 = results.find((r) => r.match_id === 'r3')!;
		expect(r1.scheduled).toBe(true);  // R1 obté l'slot
		expect(r3.scheduled).toBe(false); // R3 no queda slot (p1 ja ocupat)
	});

	it('processa winners bracket abans de losers a la mateixa ronda', () => {
		// 1 slot lliure; 2 partides de R1: una de winners i una de losers, amb p1 compartit
		const occupied: OccupiedSlot[] = [
			{ data: '2026-03-02', hora: '18:00', taula: 1 },
			{ data: '2026-03-02', hora: '18:00', taula: 2 },
			{ data: '2026-03-02', hora: '18:00', taula: 3 },
			{ data: '2026-03-02', hora: '19:00', taula: 1 },
			{ data: '2026-03-02', hora: '19:00', taula: 2 }
		];

		const results = scheduleMatches({
			matches: [
				makeMatch('l1', 'p1', 'p2', 1, 1, 'losers'),
				makeMatch('w1', 'p1', 'p3', 1, 1, 'winners')
			],
			config: makeConfig('2026-03-02', '2026-03-02'),
			participants: [makeAvail('p1'), makeAvail('p2'), makeAvail('p3')],
			occupiedSlots: occupied
		});

		const w = results.find((r) => r.match_id === 'w1')!;
		const l = results.find((r) => r.match_id === 'l1')!;
		expect(w.scheduled).toBe(true);
		expect(l.scheduled).toBe(false);
	});

	// ── Franja horària extra ──────────────────────────────────────────────────

	it('programa a la franja extra quan els jugadors només estan disponibles a les 17:00', () => {
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig('2026-03-02', '2026-03-02', { franja: '17:00', dies: ['dl'] }),
			participants: [
				makeAvail('p1', ['dl'], ['17:00']),
				makeAvail('p2', ['dl'], ['17:00'])
			],
			occupiedSlots: []
		});

		expect(results[0].scheduled).toBe(true);
		if (results[0].scheduled) {
			expect(results[0].hora).toBe('17:00');
		}
	});

	it("no habilita la franja extra en dies no configurats", () => {
		// Extra a 17:00 només dilluns; jugadors disponibles 17:00 dimarts
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig('2026-03-02', '2026-03-03', { franja: '17:00', dies: ['dl'] }),
			participants: [
				makeAvail('p1', ['dt'], ['17:00']),
				makeAvail('p2', ['dt'], ['17:00'])
			],
			occupiedSlots: []
		});

		// Dimarts no té slot de 17:00 → no es pot programar
		expect(results[0].scheduled).toBe(false);
	});

	it("usa la franja extra com a primer slot del dia quan s'habilita", () => {
		// Jugadors disponibles a totes les hores; verifiquem que 17:00 es prova primer
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig('2026-03-02', '2026-03-02', { franja: '17:00', dies: ['dl'] }),
			participants: [makeAvail('p1'), makeAvail('p2')],
			occupiedSlots: []
		});

		expect(results[0].scheduled).toBe(true);
		if (results[0].scheduled) {
			expect(results[0].hora).toBe('17:00'); // La primera hora disponible
		}
	});

	// ── Cap de setmana ────────────────────────────────────────────────────────

	it("no programa en cap de setmana", () => {
		// Únic dia és dissabte 2026-03-07
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig('2026-03-07', '2026-03-07'),
			participants: [makeAvail('p1'), makeAvail('p2')],
			occupiedSlots: []
		});

		expect(results[0].scheduled).toBe(false);
	});

	// ── Múltiples rondes ──────────────────────────────────────────────────────

	it('programa múltiples partides de rondes i brackets diferents', () => {
		const matches = [
			makeMatch('w1r1', 'p1', 'p2', 1, 1, 'winners'),
			makeMatch('w2r1', 'p3', 'p4', 1, 2, 'winners'),
			makeMatch('l1r1', 'p5', 'p6', 1, 1, 'losers'),
			makeMatch('w1r2', 'p7', 'p8', 2, 1, 'winners')
		];
		const participants = Array.from({ length: 8 }, (_, i) => makeAvail(`p${i + 1}`));

		const results = scheduleMatches({
			matches,
			config: makeConfig(),
			participants,
			occupiedSlots: []
		});

		expect(results).toHaveLength(4);
		expect(results.every((r) => r.scheduled)).toBe(true);

		// Verificar que no hi ha col·lisions de slot+taula
		const scheduled = results as Array<Extract<(typeof results)[0], { scheduled: true }>>;
		const keys = scheduled.map((r) => `${r.data}|${r.hora}|${r.taula}`);
		expect(new Set(keys).size).toBe(4);
	});

	// ── Participant sense info ────────────────────────────────────────────────

	it('retorna conflicte si el participant no té info de disponibilitat', () => {
		const results = scheduleMatches({
			matches: [makeMatch('m1', 'p1', 'p2')],
			config: makeConfig(),
			participants: [makeAvail('p1')], // p2 no existeix a la llista
			occupiedSlots: []
		});

		expect(results[0].scheduled).toBe(false);
		if (!results[0].scheduled) {
			expect(results[0].motiu).toContain('p2');
		}
	});
});
