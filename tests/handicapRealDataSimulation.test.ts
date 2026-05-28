/**
 * Simulació amb les dades REALS del torneig hàndicap actual.
 *
 * Snapshot (2026-05-28):
 *  - Event: 2026-06-01 → 2026-07-03 (33 dies; ~23 laborables)
 *  - 30 inscrits (bracketSize = 32, 2 byes)
 *  - 3 billars · 18:00 i 19:00 · sense franja extra
 *  - Cada inscrit té preferencies_dies / preferencies_hores reals.
 */
import { describe, expect, it } from 'vitest';
import { generateDoublEliminationBracket, type ParticipantInput } from '../src/lib/utils/handicap-bracket-generator';
import { preSchedulingForBracket } from '../src/lib/utils/handicap-pre-scheduler';
import { optimizeSchedule, type ParticipantAvailability } from '../src/lib/utils/handicap-schedule-optimizer';

interface RealParticipant {
	nom: string;
	distancia: number;
	dies: string[];
	hores: string[];
	restriccions?: string | null;
	dataDisponibleDes?: Date;
}

const REAL_PARTICIPANTS: RealParticipant[] = [
	{ nom: 'José Vicente Aguilella', distancia: 10, dies: ['dl', 'dt', 'dj'], hores: ['18:00', '19:00'] },
	{ nom: 'Pedro Álvarez', distancia: 15, dies: ['dl', 'dt', 'dj'], hores: ['18:00'] },
	{ nom: 'Agustí Boix', distancia: 20, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'José María Campos', distancia: 20, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00'] },
	{ nom: 'Rafael Cervantes', distancia: 20, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Luís Chuecos', distancia: 20, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Jordi Domingo', distancia: 20, dies: ['dl', 'dt', 'dc', 'dv'], hores: ['18:00', '19:00'], restriccions: 'a partir del 9 juny', dataDisponibleDes: new Date('2026-06-09') },
	{ nom: 'Joaquim Gibernau', distancia: 15, dies: ['dl', 'dt', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Albert Gómez', distancia: 20, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Jorge Gómez', distancia: 15, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Mariano Gonzalvo', distancia: 10, dies: ['dl', 'dt', 'dc'], hores: ['18:00', '19:00'] },
	{ nom: 'José Ibáñez', distancia: 10, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Vicens Inocentes', distancia: 15, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Raúl Jarque', distancia: 10, dies: ['dl', 'dt', 'dc', 'dj'], hores: ['18:00'] },
	{ nom: 'Esteve León', distancia: 20, dies: [], hores: [] }, // sense restriccions = qualsevol
	{ nom: 'Antonio Medina', distancia: 15, dies: ['dl', 'dt', 'dc', 'dj'], hores: ['19:00'] },
	{ nom: 'Rafael Moreno', distancia: 15, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00'] },
	{ nom: 'Ricardo Polls', distancia: 10, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Juan Rodríguez', distancia: 15, dies: ['dl', 'dt', 'dc'], hores: ['18:00'] },
	{ nom: 'Joel Roseró', distancia: 20, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Guillem Ruiz', distancia: 10, dies: ['dl', 'dt', 'dc', 'dj'], hores: ['18:00', '19:00'] },
	{ nom: 'Ramon Rull', distancia: 10, dies: ['dl', 'dt', 'dc', 'dj'], hores: ['18:00', '19:00'] },
	{ nom: 'Jesús Sánchez', distancia: 10, dies: ['dl', 'dt', 'dc', 'dj'], hores: ['18:00', '19:00'] },
	{ nom: 'Juan Félix Santos', distancia: 20, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'José Antonio Saucedo', distancia: 15, dies: ['dl', 'dt', 'dc', 'dj'], hores: ['18:00'] },
	{ nom: 'Carlos Sogués', distancia: 20, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Rafael Soto', distancia: 15, dies: ['dl', 'dt', 'dj'], hores: ['19:00'] },
	{ nom: 'Josep Vallés', distancia: 10, dies: ['dl', 'dt', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Josep Vila', distancia: 15, dies: ['dl', 'dt', 'dc', 'dj', 'dv'], hores: ['18:00', '19:00'] },
	{ nom: 'Jaume Zurita', distancia: 10, dies: ['dl', 'dc', 'dj', 'dv'], hores: ['18:00'] }
];

function shuffleSeeded<T>(arr: T[], seed: number): T[] {
	let s = seed;
	const rng = () => { s = (s * 9301 + 49297) % 233280; return s / 233280; };
	const out = [...arr];
	for (let i = out.length - 1; i > 0; i--) {
		const j = Math.floor(rng() * (i + 1));
		[out[i], out[j]] = [out[j], out[i]];
	}
	return out;
}

function ymd(d: Date): string {
	return d.toISOString().slice(0, 10);
}

describe('Simulació amb dades reals del torneig hàndicap 2025-2026', () => {
	const N = REAL_PARTICIPANTS.length; // 30
	const DATA_INICI = new Date('2026-06-01');
	const DATA_FI = new Date('2026-07-03');
	const HORES = ['18:00', '19:00'];

	console.log(`\n═══════════════════════════════════════════════════════════════════`);
	console.log(`SIMULACIÓ DADES REALS — ${N} inscrits, ${ymd(DATA_INICI)} → ${ymd(DATA_FI)}`);
	console.log(`Bracket size = ${(() => { let p = 1; while (p < N) p *= 2; return p; })()} (${(() => { let p = 1; while (p < N) p *= 2; return p; })() - N} byes)`);
	console.log(`Slots/dia disponibles = 3 billars × 2 hores = 6 partides/dia`);
	console.log(`═══════════════════════════════════════════════════════════════════\n`);

	it('5 simulacions de sorteig aleatori + pre-schedule + optimitzar', () => {
		const results: Array<{
			seed: number;
			baseFi: string;
			optimFi: string;
			swaps: number;
			cost: number;
			conflictsResidual: number;
		}> = [];

		for (let seed = 1; seed <= 5; seed++) {
			// Sorteig aleatori: barreja l'ordre dels inscrits
			const shuffled = shuffleSeeded(REAL_PARTICIPANTS, seed * 17);
			const participants: ParticipantInput[] = shuffled.map((p, i) => ({
				id: `${i + 1}-${p.nom}`,
				seed: i + 1,
				distancia: p.distancia
			}));

			const bracket = generateDoublEliminationBracket('real-event', participants);
			const matches = bracket.matches.filter(m => m.estat !== 'bye');

			// Pre-schedule base
			const baseScheduled = preSchedulingForBracket(bracket.slots, matches, {
				dataInici: DATA_INICI,
				dataFi: DATA_FI,
				horesEstandard: HORES,
				billars: 3
			});

			// Disponibilitats per participant (mapejades des de l'ordre del sorteig)
			const availabilities = new Map<string, ParticipantAvailability>();
			for (let i = 0; i < shuffled.length; i++) {
				availabilities.set(participants[i].id, {
					participantId: participants[i].id,
					preferenciesDies: shuffled[i].dies,
					preferenciesHores: shuffled[i].hores,
					dataDisponibleDes: shuffled[i].dataDisponibleDes
				});
			}

			// Optimitza
			const optim = optimizeSchedule({
				slots: bracket.slots,
				matches,
				scheduled: baseScheduled,
				availabilities,
				dataPrevistaFi: DATA_FI
			});

			// Comptar conflictes residuals (matches on un jugador no està disponible)
			const slotsById = new Map(bracket.slots.map(s => [s.id, s]));
			let conflicts = 0;
			for (const m of matches) {
				const sched = optim.scheduled.get(m.id);
				if (!sched) continue;
				const dayCode = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'][sched.dataProgramada.getDay()];
				for (const slotId of [m.slot1_id, m.slot2_id]) {
					const slot = slotsById.get(slotId);
					const pid = slot?.participant_id;
					if (!pid) continue;
					const av = availabilities.get(pid);
					if (!av) continue;
					if (av.dataDisponibleDes && sched.dataProgramada < av.dataDisponibleDes) {
						conflicts++;
						continue;
					}
					const okDia = av.preferenciesDies.length === 0 || av.preferenciesDies.includes(dayCode);
					const okHora = av.preferenciesHores.length === 0 || av.preferenciesHores.includes(sched.horaInici);
					if (!okDia || !okHora) conflicts++;
				}
			}

			const baseFi = [...baseScheduled.values()].reduce((m, s) => s.dataProgramada > m ? s.dataProgramada : m, new Date(0));
			results.push({
				seed,
				baseFi: ymd(baseFi),
				optimFi: ymd(optim.dataFiEfectiva!),
				swaps: optim.movimentsAplicats,
				cost: optim.costFinal,
				conflictsResidual: conflicts
			});
		}

		// Imprimir taula
		console.log('Seed │ data_fi base │ data_fi optim │ swaps │ cost │ conflictes residuals');
		console.log('─────┼──────────────┼───────────────┼───────┼──────┼─────────────────────');
		for (const r of results) {
			console.log(
				` ${String(r.seed).padStart(3)} │  ${r.baseFi}  │   ${r.optimFi}  │  ${String(r.swaps).padStart(3)}  │ ${String(r.cost).padStart(4)} │  ${String(r.conflictsResidual).padStart(5)}`
			);
		}

		// Mètriques agregades
		const totalMatches = (() => {
			const shuffled = shuffleSeeded(REAL_PARTICIPANTS, 17);
			const participants: ParticipantInput[] = shuffled.map((p, i) => ({ id: String(i), seed: i + 1, distancia: p.distancia }));
			const b = generateDoublEliminationBracket('x', participants);
			return b.matches.filter(m => m.estat !== 'bye').length;
		})();
		console.log(`\nTotal matches generats: ${totalMatches}`);
		console.log(`Període: ${ymd(DATA_INICI)} → ${ymd(DATA_FI)}`);
		const diesPeriode = Math.round((DATA_FI.getTime() - DATA_INICI.getTime()) / 86400000) + 1;
		console.log(`Dies del període: ${diesPeriode}\n`);

		expect(results.every(r => r.swaps >= 0)).toBe(true);
	});
});
