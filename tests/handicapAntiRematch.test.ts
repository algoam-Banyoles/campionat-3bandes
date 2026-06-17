import { describe, it, expect } from 'vitest';
import {
	generateDoublEliminationBracket,
	computeWbLoserDrops,
	type ParticipantInput,
	type SlotInsert,
	type MatchInsert
} from '$lib/utils/handicap-bracket-generator';

function makeParticipants(n: number): ParticipantInput[] {
	return Array.from({ length: n }, (_, i) => ({ id: `p${i + 1}`, seed: i + 1, distancia: 10 }));
}

/**
 * Conjunt de participants que poden ocupar cada slot (reachability), propagant
 * pels destins guanyador/perdedor de cada partida.
 */
function computeReach(slots: SlotInsert[], matches: MatchInsert[]): Map<string, Set<string>> {
	const slotById = new Map(slots.map((s) => [s.id, s]));
	const reach = new Map<string, Set<string>>();
	for (const s of slots) reach.set(s.id, s.participant_id ? new Set([s.participant_id]) : new Set());
	const btOrder: Record<string, number> = { winners: 0, losers: 1, grand_final: 2 };
	const ordered = [...matches].sort((a, b) => {
		const sa = slotById.get(a.slot1_id)!;
		const sb = slotById.get(b.slot1_id)!;
		return btOrder[sa.bracket_type] - btOrder[sb.bracket_type] || sa.ronda - sb.ronda;
	});
	for (const m of ordered) {
		const u = new Set<string>([...reach.get(m.slot1_id)!, ...reach.get(m.slot2_id)!]);
		for (const dest of [m.winner_slot_dest_id, m.loser_slot_dest_id]) {
			if (!dest) continue;
			const cur = reach.get(dest)!;
			for (const x of u) cur.add(x);
		}
	}
	return reach;
}

const disjoint = (a: Set<string>, b: Set<string>) => ![...a].some((x) => b.has(x));

/** Nombre màxim d'aparellaments disjunts (matching bipartit, Kuhn). */
function maxDisjointMatching(left: Set<string>[], right: Set<string>[]): number {
	const n = left.length;
	const mr = new Array<number>(n).fill(-1);
	let count = 0;
	const aug = (l: number, seen: boolean[]): boolean => {
		for (let r = 0; r < n; r++) {
			if (seen[r] || !disjoint(left[l], right[r])) continue;
			seen[r] = true;
			if (mr[r] === -1 || aug(mr[r], seen)) {
				mr[r] = l;
				return true;
			}
		}
		return false;
	};
	for (let l = 0; l < n; l++) if (aug(l, new Array<boolean>(n).fill(false))) count++;
	return count;
}

interface DropRound {
	lr: number;
	survivor: Set<string>[];
	dropped: Set<string>[];
	actualDisjoint: number;
}

/** Agrupa per ronda les partides de baixada (un slot del winners, l'altre del losers). */
function dropRounds(slots: SlotInsert[], matches: MatchInsert[]): DropRound[] {
	const slotById = new Map(slots.map((s) => [s.id, s]));
	const reach = computeReach(slots, matches);
	const feederBt = (s: SlotInsert): string | null => {
		const f = s.source_match_id ? matches.find((m) => m.id === s.source_match_id) : undefined;
		return f ? slotById.get(f.slot1_id)!.bracket_type : null;
	};
	const rounds = new Map<number, DropRound>();
	for (const m of matches) {
		const s1 = slotById.get(m.slot1_id)!;
		const s2 = slotById.get(m.slot2_id)!;
		if (s1.bracket_type !== 'losers' || s1.is_bye || s2.is_bye) continue;
		const w1 = feederBt(s1) === 'winners';
		const w2 = feederBt(s2) === 'winners';
		if (w1 === w2) continue; // només baixades (exactament un slot ve del winners)
		const dropSlot = w1 ? s1 : s2;
		const survSlot = w1 ? s2 : s1;
		if (!rounds.has(s1.ronda)) {
			rounds.set(s1.ronda, { lr: s1.ronda, survivor: [], dropped: [], actualDisjoint: 0 });
		}
		const e = rounds.get(s1.ronda)!;
		const rd = reach.get(dropSlot.id)!;
		const rs = reach.get(survSlot.id)!;
		e.dropped.push(rd);
		e.survivor.push(rs);
		if (disjoint(rd, rs)) e.actualDisjoint++;
	}
	return [...rounds.values()].sort((a, b) => a.lr - b.lr);
}

describe('computeWbLoserDrops', () => {
	it('W-R1 baixa a L-R1 slot i (sense canvis)', () => {
		const m = computeWbLoserDrops(8);
		expect(m.get('1:1')).toEqual({ lr: 1, pos: 1 });
		expect(m.get('1:4')).toEqual({ lr: 1, pos: 4 });
	});
	it('cada partida del winners té exactament un destí de perdedor', () => {
		const m = computeWbLoserDrops(32);
		// W-R1..W-R5: 16+8+4+2+1 = 31 partides
		expect(m.size).toBe(31);
		for (const [, v] of m) expect(v.pos).toBeGreaterThan(0);
	});
});

describe('anti-revenja a les baixades del losers bracket', () => {
	for (const n of [8, 16, 32, 64]) {
		it(`${n} jugadors: el generador és òptim — cap revenja evitable a cap baixada`, () => {
			const { slots, matches } = generateDoublEliminationBracket('ev', makeParticipants(n));
			const rounds = dropRounds(slots, matches);
			expect(rounds.length).toBeGreaterThan(0);

			for (const r of rounds) {
				const maxPossible = maxDisjointMatching(r.survivor, r.dropped);
				// El generador assoleix el màxim d'aparellaments sense revenja possibles.
				expect(
					r.actualDisjoint,
					`L-R${r.lr}: ${r.actualDisjoint} disjunts però n'hi caben ${maxPossible}`
				).toBe(maxPossible);
			}

			// La primera ronda de baixada (W-R2 → L-R2) sempre ha de quedar 100% neta.
			const first = rounds[0];
			expect(first.lr).toBe(2);
			expect(first.actualDisjoint).toBe(first.survivor.length);
		});
	}

	it('regressió cas real (32 jugadors): cap revenja a L-R4 (la baixada de W-R3)', () => {
		// Mirall del cas Luis–Juan: Luis guanya Juan a W-R2 (Juan baixa); Luis perd
		// a W-R3 i baixa a L-R4. Amb el creuament, no pot retrobar Juan en baixar.
		const { slots, matches } = generateDoublEliminationBracket('ev', makeParticipants(32));
		const lr4 = dropRounds(slots, matches).find((r) => r.lr === 4)!;
		expect(lr4.survivor).toHaveLength(4);
		expect(lr4.actualDisjoint).toBe(4); // les 4 baixades de L-R4, sense revenja
	});
});
