import { describe, expect, it } from 'vitest';
import { generateDoublEliminationBracket, type ParticipantInput } from '../src/lib/utils/handicap-bracket-generator';
import { preSchedulingForBracket } from '../src/lib/utils/handicap-pre-scheduler';
import { optimizeSchedule, type ParticipantAvailability } from '../src/lib/utils/handicap-schedule-optimizer';

function fakeParticipants(n: number): ParticipantInput[] {
	return Array.from({ length: n }, (_, i) => ({
		id: `p${i + 1}`,
		seed: i + 1,
		distancia: 30
	}));
}

function ymd(d: Date): string {
	return d.toISOString().slice(0, 10);
}

function isWeekday(d: Date): boolean {
	const wd = d.getDay();
	return wd >= 1 && wd <= 5;
}

describe('handicap-pre-scheduler', () => {
	it('programa tots els matches d\'un bracket de 8 jugadors', () => {
		const participants = fakeParticipants(8);
		const bracket = generateDoublEliminationBracket('evX', participants);
		const matches = bracket.matches.filter(m => m.estat !== 'bye');

		const scheduled = preSchedulingForBracket(
			bracket.slots,
			matches,
			{
				dataInici: new Date('2026-06-01'),
				dataFi: new Date('2026-07-31'),
				horesEstandard: ['18:00', '19:00'],
				billars: 3
			}
		);

		expect(scheduled.size).toBe(matches.length);
		for (const sm of scheduled.values()) {
			expect(sm.horaInici).toMatch(/^\d{2}:\d{2}$/);
			expect(sm.taulaAssignada).toBeGreaterThanOrEqual(1);
			expect(sm.taulaAssignada).toBeLessThanOrEqual(3);
			expect(isWeekday(sm.dataProgramada)).toBe(true);
		}
	});

	it('respecta cap jugador 2 partides el mateix dia (excepte Grand Final)', () => {
		const participants = fakeParticipants(16);
		const bracket = generateDoublEliminationBracket('evX', participants);
		const matches = bracket.matches.filter(m => m.estat !== 'bye');
		const slotsById = new Map(bracket.slots.map(s => [s.id, s]));

		const scheduled = preSchedulingForBracket(
			bracket.slots,
			matches,
			{
				dataInici: new Date('2026-06-01'),
				dataFi: new Date('2026-08-31'),
				horesEstandard: ['18:00', '19:00'],
				billars: 3
			}
		);

		// Predecessors → cada match va estrictament després del seu predecessor
		// (excepte gran final, on s'admet mateix dia).
		for (const m of matches) {
			const sm = scheduled.get(m.id);
			if (!sm) continue;
			const s1 = slotsById.get(m.slot1_id);
			const bracketType = s1?.bracket_type;
			// busca predecessors: matches que alimenten m.slot1_id o m.slot2_id
			for (const other of matches) {
				if (other.id === m.id) continue;
				if (other.winner_slot_dest_id === m.slot1_id || other.winner_slot_dest_id === m.slot2_id
					|| other.loser_slot_dest_id === m.slot1_id || other.loser_slot_dest_id === m.slot2_id) {
					const pred = scheduled.get(other.id);
					if (!pred) continue;
					if (bracketType === 'grand_final') {
						expect(sm.dataProgramada >= pred.dataProgramada).toBe(true);
					} else {
						expect(ymd(sm.dataProgramada) > ymd(pred.dataProgramada)).toBe(true);
					}
				}
			}
		}
	});

	it('cap slot (dia/hora/billar) es repeteix', () => {
		const participants = fakeParticipants(32);
		const bracket = generateDoublEliminationBracket('evX', participants);
		const matches = bracket.matches.filter(m => m.estat !== 'bye');

		const scheduled = preSchedulingForBracket(
			bracket.slots,
			matches,
			{
				dataInici: new Date('2026-06-01'),
				dataFi: new Date('2026-09-30'),
				horesEstandard: ['18:00', '19:00'],
				billars: 3
			}
		);

		const seen = new Set<string>();
		for (const sm of scheduled.values()) {
			const k = `${ymd(sm.dataProgramada)}|${sm.horaInici}|${sm.taulaAssignada}`;
			expect(seen.has(k)).toBe(false);
			seen.add(k);
		}
	});

	it('data màxima d\'un match és anterior a la del seu successor', () => {
		const participants = fakeParticipants(16);
		const bracket = generateDoublEliminationBracket('evX', participants);
		const matches = bracket.matches.filter(m => m.estat !== 'bye');

		const scheduled = preSchedulingForBracket(
			bracket.slots,
			matches,
			{
				dataInici: new Date('2026-06-01'),
				dataFi: new Date('2026-09-30'),
				horesEstandard: ['18:00', '19:00'],
				billars: 3
			}
		);

		for (const m of matches) {
			const sm = scheduled.get(m.id);
			if (!sm) continue;
			// Successors: matches que reben winner/loser des de m
			const succsIds: string[] = [];
			for (const other of matches) {
				if (other.slot1_id === m.winner_slot_dest_id
					|| other.slot2_id === m.winner_slot_dest_id
					|| other.slot1_id === m.loser_slot_dest_id
					|| other.slot2_id === m.loser_slot_dest_id) {
					succsIds.push(other.id);
				}
			}
			for (const sid of succsIds) {
				const succ = scheduled.get(sid);
				if (!succ) continue;
				expect(sm.dataMaximaDisputa < succ.dataProgramada).toBe(true);
			}
		}
	});
});

describe('handicap-schedule-optimizer — proves amb sorteigs aleatoris', () => {
	function randomShuffle<T>(arr: T[], seed: number): T[] {
		// LCG simple per a reproducibilitat
		let s = seed;
		const rng = () => { s = (s * 9301 + 49297) % 233280; return s / 233280; };
		const out = [...arr];
		for (let i = out.length - 1; i > 0; i--) {
			const j = Math.floor(rng() * (i + 1));
			[out[i], out[j]] = [out[j], out[i]];
		}
		return out;
	}

	function randomAvailabilities(n: number, seed: number): Map<string, ParticipantAvailability> {
		let s = seed;
		const rng = () => { s = (s * 1664525 + 1013904223) % 4294967296; return s / 4294967296; };
		const dies = ['dl', 'dt', 'dc', 'dj', 'dv'];
		const hores = ['18:00', '19:00'];
		const out = new Map<string, ParticipantAvailability>();
		for (let i = 1; i <= n; i++) {
			// Cada jugador té entre 2 i 5 dies preferits, i 1-2 hores
			const nDies = 2 + Math.floor(rng() * 4);
			const playerDies = randomShuffle(dies, seed + i).slice(0, nDies);
			const nHores = 1 + Math.floor(rng() * 2);
			const playerHores = randomShuffle(hores, seed + i + 1000).slice(0, nHores);
			out.set(`p${i}`, {
				participantId: `p${i}`,
				preferenciesDies: playerDies,
				preferenciesHores: playerHores
			});
		}
		return out;
	}

	for (const N of [8, 16, 32]) {
		it(`sorteig aleatori amb ${N} jugadors: programa, optimitza i mostra mètriques`, () => {
			const participants = fakeParticipants(N);
			// "Sorteig" aleatori: barreja seeds 1..N
			const shuffled = randomShuffle(participants, 42 + N);
			const bracket = generateDoublEliminationBracket('evX', shuffled);
			const matches = bracket.matches.filter(m => m.estat !== 'bye');

			const dataInici = new Date('2026-06-01');
			const dataPrevista = new Date('2026-07-15');
			const dataFi = new Date('2026-09-30');

			const baseScheduled = preSchedulingForBracket(
				bracket.slots,
				matches,
				{ dataInici, dataFi, horesEstandard: ['18:00', '19:00'], billars: 3 }
			);
			expect(baseScheduled.size).toBe(matches.length);

			const availabilities = randomAvailabilities(N, 123 + N);
			const result = optimizeSchedule({
				slots: bracket.slots,
				matches,
				scheduled: baseScheduled,
				availabilities,
				dataPrevistaFi: dataPrevista
			});

			// Comprovem que retorna scheduled de la mateixa mida i ben formada
			expect(result.scheduled.size).toBe(matches.length);
			expect(result.movimentsAplicats).toBeGreaterThanOrEqual(0);
			expect(result.dataFiEfectiva).not.toBeNull();

			// Log informatiu (apareix amb vitest --reporter=verbose)
			const baseFi = [...baseScheduled.values()].reduce(
				(m, s) => s.dataProgramada > m ? s.dataProgramada : m,
				new Date(0)
			);
			console.log(
				`N=${N}: base data_fi=${ymd(baseFi)} | optim mov=${result.movimentsAplicats} ` +
				`cost=${result.costFinal} fi=${ymd(result.dataFiEfectiva!)}`
			);
		});
	}
});
