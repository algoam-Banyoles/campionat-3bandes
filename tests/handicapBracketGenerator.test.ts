import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import {
	generateDoublEliminationBracket,
	calcByes,
	getR1Pairings,
	setIdGenerator,
	resetIdGenerator,
	type ParticipantInput,
	type SlotInsert,
	type MatchInsert
} from '$lib/utils/handicap-bracket-generator';

// ── Helpers ───────────────────────────────────────────────────────────────────

let idCounter = 0;
function makeParticipants(n: number): ParticipantInput[] {
	return Array.from({ length: n }, (_, i) => ({
		id: `p${i + 1}`,
		seed: i + 1,
		distancia: 10 + i * 2
	}));
}

beforeEach(() => {
	idCounter = 0;
	setIdGenerator(() => `id-${++idCounter}`);
});
afterEach(() => {
	resetIdGenerator();
});

function slotsByType(slots: SlotInsert[], bt: string) {
	return slots.filter((s) => s.bracket_type === bt);
}

function pendingMatches(matches: MatchInsert[]) {
	return matches.filter((m) => m.estat === 'pendent');
}

function byeMatches(matches: MatchInsert[]) {
	return matches.filter((m) => m.estat === 'bye');
}

// ── calcByes ──────────────────────────────────────────────────────────────────

describe('calcByes', () => {
	it('retorna 0 per potències de 2', () => {
		expect(calcByes(4)).toBe(0);
		expect(calcByes(8)).toBe(0);
		expect(calcByes(16)).toBe(0);
	});
	it('retorna el nombre correcte de byes', () => {
		expect(calcByes(5)).toBe(3); // → 8
		expect(calcByes(6)).toBe(2); // → 8
		expect(calcByes(7)).toBe(1); // → 8
		expect(calcByes(9)).toBe(7); // → 16
	});
});

// ── getR1Pairings ─────────────────────────────────────────────────────────────

describe('getR1Pairings', () => {
	it('4 jugadors: 1v4, 2v3', () => {
		const p = makeParticipants(4);
		const pairs = getR1Pairings(p);
		expect(pairs).toHaveLength(2);
		expect(pairs[0].seed1.seed).toBe(1);
		expect(pairs[0].seed2!.seed).toBe(4);
		expect(pairs[1].seed1.seed).toBe(2);
		expect(pairs[1].seed2!.seed).toBe(3);
	});
	it('6 jugadors: seed 1 i 2 tenen bye (seed2 = null)', () => {
		const p = makeParticipants(6);
		const pairs = getR1Pairings(p);
		expect(pairs).toHaveLength(4); // size=8, 4 partides R1
		expect(pairs[0].seed1.seed).toBe(1);
		expect(pairs[0].seed2).toBeNull(); // bye
		expect(pairs[1].seed1.seed).toBe(2);
		expect(pairs[1].seed2).toBeNull(); // bye
		expect(pairs[2].seed1.seed).toBe(3);
		expect(pairs[2].seed2!.seed).toBe(6);
		expect(pairs[3].seed1.seed).toBe(4);
		expect(pairs[3].seed2!.seed).toBe(5);
	});
	it('8 jugadors: totes les parelles, cap bye', () => {
		const p = makeParticipants(8);
		const pairs = getR1Pairings(p);
		expect(pairs).toHaveLength(4);
		expect(pairs.every((pair) => pair.seed2 !== null)).toBe(true);
		// seed 1 vs seed 8
		expect(pairs[0].seed1.seed).toBe(1);
		expect(pairs[0].seed2!.seed).toBe(8);
	});
});

// ── generateDoublEliminationBracket ──────────────────────────────────────────

describe('4 jugadors (size=4, k=2, 0 byes)', () => {
	let result: ReturnType<typeof generateDoublEliminationBracket>;

	beforeEach(() => {
		result = generateDoublEliminationBracket('ev1', makeParticipants(4));
	});

	it('nombre total de partides = 2*4-1 = 7', () => {
		// 4 jugadors: 3 winners + 2 losers + 2 GF = 7
		expect(result.matches).toHaveLength(7);
	});

	it('cap partida bye (size perfecte)', () => {
		expect(byeMatches(result.matches)).toHaveLength(0);
	});

	it('slots winners: 4(R1) + 2(R2) = 6', () => {
		expect(slotsByType(result.slots, 'winners')).toHaveLength(6);
	});

	it('slots losers: 2(L-R1) + 2(L-R2) = 4', () => {
		expect(slotsByType(result.slots, 'losers')).toHaveLength(4);
	});

	it('slots grand_final: 4 (R1×2 + R2×2)', () => {
		expect(slotsByType(result.slots, 'grand_final')).toHaveLength(4);
	});

	it('W-R1 slots tenen els participants correctes (seed 1v4, 2v3)', () => {
		const wR1 = slotsByType(result.slots, 'winners').filter((s) => s.ronda === 1);
		expect(wR1.find((s) => s.posicio === 1)?.participant_id).toBe('p1');
		expect(wR1.find((s) => s.posicio === 2)?.participant_id).toBe('p4');
		expect(wR1.find((s) => s.posicio === 3)?.participant_id).toBe('p2');
		expect(wR1.find((s) => s.posicio === 4)?.participant_id).toBe('p3');
	});

	it('W-R1 partides tenen distàncies correctes', () => {
		// p1 distancia=10 (seed 1), p4 distancia=16 (seed 4)
		const wMatches = result.matches.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1 && s1.posicio === 1;
		});
		expect(wMatches[0].distancia_jugador1).toBe(10);
		expect(wMatches[0].distancia_jugador2).toBe(16);
	});

	it('GF-R2 no té destins (partida final)', () => {
		const gfR2match = result.matches.find((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'grand_final' && s1.ronda === 2;
		});
		expect(gfR2match?.winner_slot_dest_id).toBeNull();
		expect(gfR2match?.loser_slot_dest_id).toBeNull();
	});

	it('cada partida pendent té winner_slot_dest (excepte GF-R2)', () => {
		const nonGfR2 = result.matches.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return !(s1.bracket_type === 'grand_final' && s1.ronda === 2);
		});
		expect(nonGfR2.every((m) => m.winner_slot_dest_id !== null)).toBe(true);
	});
});

describe('8 jugadors (size=8, k=3, 0 byes)', () => {
	let result: ReturnType<typeof generateDoublEliminationBracket>;

	beforeEach(() => {
		result = generateDoublEliminationBracket('ev1', makeParticipants(8));
	});

	it('nombre total de partides = 2*8-1 = 15', () => {
		expect(result.matches).toHaveLength(15);
	});

	it('cap partida bye', () => {
		expect(byeMatches(result.matches)).toHaveLength(0);
	});

	it('slots winners: 8+4+2=14', () => {
		expect(slotsByType(result.slots, 'winners')).toHaveLength(14);
	});

	it('slots losers: 4+4+2+2=12', () => {
		expect(slotsByType(result.slots, 'losers')).toHaveLength(12);
	});

	it('W-R1 parella 1: seed 1 vs seed 8', () => {
		const wR1 = slotsByType(result.slots, 'winners').filter((s) => s.ronda === 1);
		expect(wR1.find((s) => s.posicio === 1)?.participant_id).toBe('p1');
		expect(wR1.find((s) => s.posicio === 2)?.participant_id).toBe('p8');
	});

	it('W-R1 parella 4: seed 4 vs seed 5', () => {
		const wR1 = slotsByType(result.slots, 'winners').filter((s) => s.ronda === 1);
		expect(wR1.find((s) => s.posicio === 7)?.participant_id).toBe('p4');
		expect(wR1.find((s) => s.posicio === 8)?.participant_id).toBe('p5');
	});
});

describe('6 jugadors (size=8, 2 byes)', () => {
	let result: ReturnType<typeof generateDoublEliminationBracket>;

	beforeEach(() => {
		result = generateDoublEliminationBracket('ev1', makeParticipants(6));
	});

	it('nombre total de partides = 2*8-1 = 15', () => {
		// El bracket de 8 segueix tenint 15 partides (2 seran bye)
		expect(result.matches).toHaveLength(15);
	});

	it('2 partides bye en W-R1 (seeds 1 i 2 vs bye)', () => {
		const byes = byeMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1;
		});
		expect(byes).toHaveLength(2);
	});

	it('seed 1 i seed 2 avancen automàticament a W-R2', () => {
		const wR2 = slotsByType(result.slots, 'winners').filter((s) => s.ronda === 2);
		const participants = wR2.map((s) => s.participant_id).filter(Boolean);
		expect(participants).toContain('p1');
		expect(participants).toContain('p2');
	});

	it('slots de byes propagats al losers estan marcats com is_bye', () => {
		const lR1Byes = slotsByType(result.slots, 'losers').filter(
			(s) => s.ronda === 1 && s.is_bye
		);
		// 2 byes en W-R1 → 2 slots bye a L-R1
		expect(lR1Byes).toHaveLength(2);
	});

	it('la partida bye a L-R1 entre dos byes no produeix guanyador real', () => {
		const lR1slots = slotsByType(result.slots, 'losers').filter((s) => s.ronda === 1);
		const byeMatch = byeMatches(result.matches).find((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			const s2 = result.slots.find((s) => s.id === m.slot2_id)!;
			return (
				s1.bracket_type === 'losers' && s1.ronda === 1 && s1.is_bye && s2.is_bye
			);
		});
		expect(byeMatch?.guanyador_participant_id).toBeNull();
	});

	it('les 2 partides R1 reals (seeds 3v6 i 4v5) estan pendents', () => {
		const wR1pending = pendingMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1;
		});
		expect(wR1pending).toHaveLength(2);
	});
});

describe('5 jugadors (size=8, 3 byes)', () => {
	let result: ReturnType<typeof generateDoublEliminationBracket>;

	beforeEach(() => {
		result = generateDoublEliminationBracket('ev1', makeParticipants(5));
	});

	it('3 byes en W-R1', () => {
		const wR1Byes = byeMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1;
		});
		expect(wR1Byes).toHaveLength(3);
	});

	it('seed 1,2,3 avancen a W-R2', () => {
		const wR2 = slotsByType(result.slots, 'winners').filter((s) => s.ronda === 2);
		const ids = wR2.map((s) => s.participant_id).filter(Boolean);
		expect(ids).toContain('p1');
		expect(ids).toContain('p2');
		expect(ids).toContain('p3');
	});

	it('només 1 partida real a W-R1 (seed 4 vs seed 5)', () => {
		const wR1real = pendingMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1;
		});
		expect(wR1real).toHaveLength(1);
		expect(wR1real[0].distancia_jugador1).toBe(16); // p4: 10 + 3*2
		expect(wR1real[0].distancia_jugador2).toBe(18); // p5: 10 + 4*2
	});
});

describe('32 jugadors (size=32, k=5, 0 byes)', () => {
	let result: ReturnType<typeof generateDoublEliminationBracket>;

	beforeEach(() => {
		result = generateDoublEliminationBracket('ev1', makeParticipants(32));
	});

	it('nombre total de partides = 2*32-1 = 63', () => {
		expect(result.matches).toHaveLength(63);
	});

	it('cap partida bye', () => {
		expect(byeMatches(result.matches)).toHaveLength(0);
	});

	it('slots winners: 32+16+8+4+2 = 62', () => {
		expect(slotsByType(result.slots, 'winners')).toHaveLength(62);
	});

	it('slots losers: 16+16+8+8+4+4+2+2 = 60', () => {
		expect(slotsByType(result.slots, 'losers')).toHaveLength(60);
	});

	it('totes les partides pendents (excepte GF-R2) tenen winner_slot_dest', () => {
		const nonFinal = result.matches.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return !(s1.bracket_type === 'grand_final' && s1.ronda === 2);
		});
		expect(nonFinal.every((m) => m.winner_slot_dest_id !== null)).toBe(true);
	});
});

describe('17 jugadors (size=32, 15 byes)', () => {
	let result: ReturnType<typeof generateDoublEliminationBracket>;

	beforeEach(() => {
		result = generateDoublEliminationBracket('ev1', makeParticipants(17));
	});

	it('15 byes en W-R1', () => {
		const wR1Byes = byeMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1;
		});
		expect(wR1Byes).toHaveLength(15);
	});

	it('seeds 1..15 avancen automàticament a W-R2', () => {
		const wR2 = slotsByType(result.slots, 'winners').filter((s) => s.ronda === 2);
		const advancedIds = wR2.map((s) => s.participant_id).filter(Boolean);
		expect(advancedIds).toHaveLength(15);
		for (let i = 1; i <= 15; i++) {
			expect(advancedIds).toContain(`p${i}`);
		}
	});

	it('seed 16 i seed 17 juguen la única partida real a W-R1', () => {
		const wR1real = pendingMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1;
		});
		expect(wR1real).toHaveLength(1);
		const participantIds = [wR1real[0], wR1real[0]].map((m, i) =>
			i === 0
				? result.slots.find((s) => s.id === m.slot1_id)?.participant_id
				: result.slots.find((s) => s.id === m.slot2_id)?.participant_id
		);
		expect(participantIds).toContain('p16');
		expect(participantIds).toContain('p17');
	});
});

// ── Propagació correcta de byes al bracket perdedors ─────────────────────────
//
// Bug: quan un slot del losers té is_bye=true però l'altre slot és "pendent"
// (is_bye=false, participant_id=null — rebrà un perdedor real d'una partida futura),
// el generador no ha de marcar aquella partida com a bye. Només s'ha de resoldre quan
// AMBDÓS slots estan "resolts" (is_bye=true o tenen participant_id).

describe('byes al losers bracket - no es propaga incorrectament (bug fix)', () => {
	it('5 jugadors: 3 byes al losers (L-R1 all-bye + L-R1 guaranteed + L-R2 guaranteed)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(5));
		const losersByes = byeMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'losers';
		});
		expect(losersByes).toHaveLength(3);
		// 2 byes a L-R1 (1 all-bye + 1 guaranteed-bye) i 1 bye a L-R2 (guaranteed-bye)
		const lr1Byes = losersByes.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.ronda === 1;
		});
		expect(lr1Byes).toHaveLength(2);
	});

	it('5 jugadors: la partida L-R1 amb slot=bye i slot=pendent és guaranteed-bye pre-resolta', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(5));
		// L-R1 té 2 matches. El segon (slots 3 i 4) té slot3=bye i slot4=pendent.
		// Amb guaranteed-bye, ara es pre-resol com a 'bye' i re-cabla el destí.
		const lR1matches = result.matches.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'losers' && s1.ronda === 1;
		});
		// Les dues partides de L-R1 ara han de ser 'bye' (1 all-bye + 1 guaranteed-bye)
		expect(lR1matches.every((m) => m.estat === 'bye')).toBe(true);
		// La guaranteed-bye (match 2): guanyador desconegut (null)
		const guaranteedByeMatch = lR1matches.find((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			const s2 = result.slots.find((s) => s.id === m.slot2_id)!;
			return (s1.is_bye && !s2.is_bye) || (!s1.is_bye && s2.is_bye);
		});
		expect(guaranteedByeMatch).toBeDefined();
		expect(guaranteedByeMatch!.guanyador_participant_id).toBeNull();
	});

	it('6 jugadors: 2 byes al losers (1 all-bye a L-R1 + 1 guaranteed a L-R2)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(6));
		const losersByes = byeMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'losers';
		});
		expect(losersByes).toHaveLength(2);
		// 1 bye a L-R1 (all-bye) i 1 bye a L-R2 (guaranteed-bye)
		const lr1Byes = losersByes.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.ronda === 1;
		});
		expect(lr1Byes).toHaveLength(1);
	});

	it('17 jugadors (15 byes): 15 byes al losers (7 all-bye L-R1 + 1 guaranteed L-R1 + 7 guaranteed L-R2)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		const losersByes = byeMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'losers';
		});
		// 7 all-bye + 1 guaranteed-bye a L-R1 + 7 guaranteed-bye a L-R2 = 15
		expect(losersByes).toHaveLength(15);
		const lr1Byes = losersByes.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.ronda === 1;
		});
		expect(lr1Byes).toHaveLength(8); // tots 8 matches de L-R1 ara són bye
		const lr2Byes = losersByes.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.ronda === 2;
		});
		expect(lr2Byes).toHaveLength(7); // 7 guaranteed-byes a L-R2
	});

	it('8 jugadors (0 byes): cap bye al losers — tots els slots L-R1 reben perdedors reals', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(8));
		const losersByes = byeMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'losers';
		});
		expect(losersByes).toHaveLength(0);
		// Tots els slots de L-R1 han de ser pendents (no bye)
		const lR1slots = result.slots.filter((s) => s.bracket_type === 'losers' && s.ronda === 1);
		expect(lR1slots.every((s) => !s.is_bye)).toBe(true);
	});

	it('16 jugadors (0 byes): cap bye al losers', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(16));
		const losersByes = byeMatches(result.matches).filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'losers';
		});
		expect(losersByes).toHaveLength(0);
	});
});

// ── Estat detallat dels slots a L-R2+ (verifica que no hi ha BYE vs BYE a R3+) ──

describe('byes al losers bracket - estat detallat dels slots per ronda', () => {
	// Helpers per trobar partides d'una ronda concreta del losers
	function lRoundMatches(result: ReturnType<typeof generateDoublEliminationBracket>, lr: number) {
		return result.matches.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'losers' && s1.ronda === lr;
		});
	}
	function lRoundSlots(result: ReturnType<typeof generateDoublEliminationBracket>, lr: number) {
		return result.slots.filter((s) => s.bracket_type === 'losers' && s.ronda === lr);
	}

	it('17 jugadors: L-R2 té 7 guaranteed-byes i 1 partida pendent (cap BYE vs BYE real)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		const lR2 = lRoundMatches(result, 2);
		expect(lR2).toHaveLength(8); // size=32, phase=1 → 16 slots → 8 matches
		// Matches 1-7: guaranteed-bye (slot imparell is_bye vs slot parell pending-from-W-R2)
		// Match 8: ambdós slots pendents (un de W-R1 re-wired, l'altre de W-R2)
		const lr2Byes = lR2.filter((m) => m.estat === 'bye');
		const lr2Pending = lR2.filter((m) => m.estat === 'pendent');
		expect(lr2Byes).toHaveLength(7);
		expect(lr2Pending).toHaveLength(1);
		// Cap bye a L-R2 té guanyador real (guanyador_participant_id null)
		expect(lr2Byes.every((m) => m.guanyador_participant_id === null)).toBe(true);
	});

	it('17 jugadors: L-R3 slots tots pendents - cap is_bye (evita la cascada buggy)', () => {
		// L-R3 (fase 2, size=32) té 4 partides = les "L17..L20" del bracket
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		const lR3slots = lRoundSlots(result, 3);
		expect(lR3slots).toHaveLength(8); // size=32, phase=2 → 8 slots
		// Cap slot de L-R3 ha de ser is_bye — cap cascada de byes ha de arribar aquí
		expect(lR3slots.every((s) => !s.is_bye)).toBe(true);
		expect(lR3slots.every((s) => s.participant_id === null)).toBe(true);
	});

	it('17 jugadors: L-R3 partides totes pendents (no BYE vs BYE a L-R3)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		const lR3 = lRoundMatches(result, 3);
		expect(lR3.every((m) => m.estat === 'pendent')).toBe(true);
	});

	it('33 jugadors (size=64): L-R3 slots tots pendents — cap cascada a L33+', () => {
		// Amb 33 jugadors, L-R3 conté L33..L40 (les partides que el bug mostrava com BYE vs BYE)
		const result = generateDoublEliminationBracket('ev1', makeParticipants(33));
		const lR3slots = lRoundSlots(result, 3);
		expect(lR3slots).toHaveLength(16); // size=64, phase=2 → 16 slots
		expect(lR3slots.every((s) => !s.is_bye)).toBe(true);
		expect(lR3slots.every((s) => s.participant_id === null)).toBe(true);
	});

	it('33 jugadors: L-R3 partides totes pendents (no BYE vs BYE)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(33));
		const lR3 = lRoundMatches(result, 3);
		expect(lR3.every((m) => m.estat === 'pendent')).toBe(true);
	});

	it('33 jugadors: L-R4 i L-R5 tots pendents — cascada aturada correctament', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(33));
		for (const lr of [4, 5]) {
			const matches = lRoundMatches(result, lr);
			expect(matches.every((m) => m.estat === 'pendent')).toBe(true);
			const slots = lRoundSlots(result, lr);
			expect(slots.every((s) => !s.is_bye)).toBe(true);
		}
	});

	it('5 jugadors: slot pendent a L-R1 pot rebre un perdedor real', () => {
		// L-R1 match 2 (slots 3,4): slot3=bye, slot4=pendent (rebrà perdedor de W-R1 match 4)
		// El slot pendent ha de tenir source_match_id apuntant a la partida real W-R1
		const result = generateDoublEliminationBracket('ev1', makeParticipants(5));
		const pendingLR1slots = result.slots.filter(
			(s) => s.bracket_type === 'losers' && s.ronda === 1 && !s.is_bye && s.participant_id === null
		);
		expect(pendingLR1slots).toHaveLength(1); // un únic slot pendent a L-R1
		const srcMatch = result.matches.find((m) => m.id === pendingLR1slots[0].source_match_id);
		expect(srcMatch).toBeDefined();
		expect(srcMatch!.estat).toBe('pendent'); // partida real, no bye
		// Quan el perdedor real arribi, resolveCascadeByes resoldrà L-R1 match 2
		// i aquell jugador avançarà automàticament (sense jugar contra un BYE)
	});

	it('L-R2 slots senars correctament is_bye quan vénen de L-R1 matches tot-bye', () => {
		// Els slots senars de L-R2 que vénen de partides L-R1 tot-bye SAAN is_bye=true
		// (és el comportament CORRECTE: "cap jugador real ha guanyat aquella L-R1")
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		// Amb 17 jugadors: L-R1 matches 1-7 (slots 1-14) són tot-bye → propaga a L-R2 slots 1,3,5,...,13
		const lR2oddSlots = result.slots.filter(
			(s) => s.bracket_type === 'losers' && s.ronda === 2 && s.posicio % 2 === 1
		);
		const byeOddSlots = lR2oddSlots.filter((s) => s.is_bye);
		// 7 L-R1 tot-bye → 7 L-R2 odd slots is_bye
		expect(byeOddSlots).toHaveLength(7);
		// Però els slots parells de L-R2 (que reben perdedors del winners bracket) NO han de ser bye
		const lR2evenSlots = result.slots.filter(
			(s) => s.bracket_type === 'losers' && s.ronda === 2 && s.posicio % 2 === 0
		);
		expect(lR2evenSlots.every((s) => !s.is_bye)).toBe(true);
	});
});

// ── Re-cablat de guaranteed-byes (Canvi 1) ────────────────────────────────────
//
// Quan una partida losers és guaranteed-bye (un slot=bye, l'altre=pendent),
// el generador re-cabla el loser_slot_dest del match que alimentava el slot pendent
// perquè apunti directament al winner_slot_dest d'aquest match guaranteed-bye.
// Així el jugador real que arribi s'evita una partida intermèdia innecessària.

describe('guaranteed-bye: re-cablat del loser_slot_dest (Canvi 1)', () => {
	it('5 jugadors: W-R1 match real (p4vsp5) té loser_slot_dest a L-R2 (bypass L-R1)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(5));
		// W-R1 match real: l'únic amb participants p4 i p5
		const wR1real = result.matches.find((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			const s2 = result.slots.find((s) => s.id === m.slot2_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1 &&
				((s1.participant_id === 'p4' && s2.participant_id === 'p5') ||
				 (s1.participant_id === 'p5' && s2.participant_id === 'p4'));
		})!;
		expect(wR1real).toBeDefined();
		// Amb guaranteed-bye, el perdedor d'aquest match va directament a L-R2 (no L-R1)
		const loseSlot = result.slots.find((s) => s.id === wR1real.loser_slot_dest_id)!;
		expect(loseSlot.bracket_type).toBe('losers');
		expect(loseSlot.ronda).toBe(2); // bypassa L-R1
	});

	it('5 jugadors: W-R2 match real té loser_slot_dest a L-R3 (bypass L-R2)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(5));
		// W-R2 match 1: el loser va a L-R2 slot 2 originalment, però ara ha de ser re-wired a L-R3
		// Identifiquem W-R2 matches com els que slot1 és winners ronda=2
		const wR2matches = result.matches.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 2;
		});
		// El primer W-R2 match (match 1) tenia loser_slot_dest a L-R2 slot 2, ara ha de ser L-R3
		const reWiredMatch = wR2matches.find((m) => {
			const loseSlot = result.slots.find((s) => s.id === m.loser_slot_dest_id);
			return loseSlot && loseSlot.bracket_type === 'losers' && loseSlot.ronda === 3;
		});
		expect(reWiredMatch).toBeDefined();
	});

	it('17 jugadors: W-R1 match (p16vsp17) té loser_slot_dest a L-R2 (bypass L-R1)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		const wR1real = result.matches.find((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			const s2 = result.slots.find((s) => s.id === m.slot2_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 1 &&
				((s1.participant_id === 'p16' && s2.participant_id === 'p17') ||
				 (s1.participant_id === 'p17' && s2.participant_id === 'p16'));
		})!;
		expect(wR1real).toBeDefined();
		const loseSlot = result.slots.find((s) => s.id === wR1real.loser_slot_dest_id)!;
		expect(loseSlot.bracket_type).toBe('losers');
		expect(loseSlot.ronda).toBe(2); // bypassa L-R1
	});

	it('17 jugadors: 7 W-R2 matches re-cablats → loser_slot_dest a L-R3', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		const wR2matches = result.matches.filter((m) => {
			const s1 = result.slots.find((s) => s.id === m.slot1_id)!;
			return s1.bracket_type === 'winners' && s1.ronda === 2 && m.loser_slot_dest_id !== null;
		});
		const reWiredToLR3 = wR2matches.filter((m) => {
			const loseSlot = result.slots.find((s) => s.id === m.loser_slot_dest_id);
			return loseSlot && loseSlot.bracket_type === 'losers' && loseSlot.ronda === 3;
		});
		// 7 dels 8 W-R2 matches estan re-cablats a L-R3 (el 8è va a L-R2 directament)
		expect(reWiredToLR3).toHaveLength(7);
	});

	it('tots els source_match_id dels slots apunten a partides existents (17 jugadors)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		const matchIds = new Set(result.matches.map((m) => m.id));
		const badSlots = result.slots.filter(
			(s) => s.source_match_id && !matchIds.has(s.source_match_id)
		);
		expect(badSlots).toHaveLength(0);
	});

	it('tots els loser_slot_dest apunten a slots existents (17 jugadors)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(17));
		const slotIds = new Set(result.slots.map((s) => s.id));
		const badMatches = result.matches.filter(
			(m) => m.loser_slot_dest_id && !slotIds.has(m.loser_slot_dest_id)
		);
		expect(badMatches).toHaveLength(0);
	});
});

describe('estructura de connexions', () => {
	it('tots els source_match_id dels slots apunten a partides existents', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(8));
		const matchIds = new Set(result.matches.map((m) => m.id));
		const badSlots = result.slots.filter(
			(s) => s.source_match_id && !matchIds.has(s.source_match_id)
		);
		expect(badSlots).toHaveLength(0);
	});

	it('tots els slot_id de les partides apunten a slots existents', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(8));
		const slotIds = new Set(result.slots.map((s) => s.id));
		for (const m of result.matches) {
			expect(slotIds.has(m.slot1_id)).toBe(true);
			expect(slotIds.has(m.slot2_id)).toBe(true);
			if (m.winner_slot_dest_id) expect(slotIds.has(m.winner_slot_dest_id)).toBe(true);
			if (m.loser_slot_dest_id) expect(slotIds.has(m.loser_slot_dest_id)).toBe(true);
		}
	});

	it('no hi ha slots duplicats (bracket_type, ronda, posicio)', () => {
		const result = generateDoublEliminationBracket('ev1', makeParticipants(16));
		const keys = result.slots.map((s) => `${s.bracket_type}:${s.ronda}:${s.posicio}`);
		const unique = new Set(keys);
		expect(unique.size).toBe(keys.length);
	});
});
