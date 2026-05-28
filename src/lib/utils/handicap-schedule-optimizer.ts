/**
 * Optimitzador de la programació del bracket d'hàndicap.
 *
 * Donada una pre-programació base (resultat de `preSchedulingForBracket`) i les
 * disponibilitats per jugador (dies/hores en què cada participant pot jugar),
 * cerca una assignació de slots que minimitzi els conflictes de disponibilitat
 * mantenint:
 *   - Les dependències estructurals del bracket (un match no es juga abans dels
 *     seus predecessors + 1 dia).
 *   - La regla "cap jugador 2 partides el mateix dia" (excepte la Gran Final).
 *
 * Estratègia: cerca local greedy.
 *   1. Per a cada match amb conflicte (cap dels jugadors disponible al slot
 *      assignat), intenta intercanviar amb un altre match DE LA MATEIXA RONDA
 *      del mateix bracket. Acceptat si redueix el cost total.
 *   2. Reitera fins que no es millora.
 *
 * El "cost" d'un match = nombre de jugadors NO disponibles al slot assignat.
 * El cost total de la solució = suma de costos de tots els matches + penalització
 * per matches que sobrepassen la data prevista de finalització.
 */

import type { PreSchedulerSlot, PreSchedulerMatch, ScheduledMatch } from './handicap-pre-scheduler';

export interface ParticipantAvailability {
	participantId: string;
	preferenciesDies: string[]; // ['dl','dt',...] buit = qualsevol
	preferenciesHores: string[]; // ['18:00',...] buit = qualsevol
	/** Si el jugador només es pot incorporar a partir d'una data concreta. */
	dataDisponibleDes?: Date;
	/** Si el jugador no pot jugar a partir d'una data (vacances, etc.). */
	dataDisponibleFins?: Date;
}

export interface OptimizerInput {
	slots: PreSchedulerSlot[];
	matches: PreSchedulerMatch[];
	scheduled: Map<string, ScheduledMatch>;
	/** participantId → disponibilitat */
	availabilities: Map<string, ParticipantAvailability>;
	/** Data prevista de finalització del torneig. Si la data del darrer match
	 *  supera aquesta data, hi ha penalització. */
	dataPrevistaFi?: Date;
	/** Configuració necessària per al pas "advance": data inici/fi, hores i
	 *  billars. Si no es passa, l'optimizer salta el pas d'avançament. */
	calendari?: {
		dataInici: Date;
		dataFi: Date;
		horesEstandard: string[];
		horarisExtra?: { franja: string; dies: string[] } | null;
		billars?: number;
		diesActius?: string[];
	};
}

export interface OptimizerResult {
	scheduled: Map<string, ScheduledMatch>;
	/** Nombre d'intercanvis aplicats respecte la solució base. */
	movimentsAplicats: number;
	/** Cost total final (menor = millor). */
	costFinal: number;
	/** Data efectiva de finalització (darrera dataProgramada). */
	dataFiEfectiva: Date | null;
}

const DIES_SETMANA = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];

function diaCodi(date: Date): string {
	return DIES_SETMANA[date.getDay()];
}

function isAvailable(
	avail: ParticipantAvailability | undefined,
	date: Date,
	hora: string
): boolean {
	if (!avail) return true; // si no tenim info, suposem disponible
	if (avail.dataDisponibleDes && date < avail.dataDisponibleDes) return false;
	if (avail.dataDisponibleFins && date > avail.dataDisponibleFins) return false;
	const codi = diaCodi(date);
	const okDia = avail.preferenciesDies.length === 0 || avail.preferenciesDies.includes(codi);
	const okHora = avail.preferenciesHores.length === 0 || avail.preferenciesHores.includes(hora);
	return okDia && okHora;
}

/**
 * Cost d'un match a un slot determinat = nombre de jugadors no disponibles
 * en aquell slot (0, 1 o 2). Si encara no es coneix el jugador (slot sense
 * participant_id), considerem cost 0 per ara.
 */
function matchCost(
	matchId: string,
	sched: ScheduledMatch,
	matches: PreSchedulerMatch[],
	slotsById: Map<string, PreSchedulerSlot & { participant_id?: string | null }>,
	availabilities: Map<string, ParticipantAvailability>
): number {
	const m = matches.find(x => x.id === matchId);
	if (!m) return 0;
	const s1 = slotsById.get(m.slot1_id);
	const s2 = slotsById.get(m.slot2_id);
	let cost = 0;
	for (const s of [s1, s2]) {
		const pid = s?.participant_id;
		if (!pid) continue;
		const avail = availabilities.get(pid);
		if (!isAvailable(avail, sched.dataProgramada, sched.horaInici)) cost += 1;
	}
	return cost;
}

function totalCost(
	scheduled: Map<string, ScheduledMatch>,
	matches: PreSchedulerMatch[],
	slotsById: Map<string, PreSchedulerSlot & { participant_id?: string | null }>,
	availabilities: Map<string, ParticipantAvailability>,
	dataPrevistaFi?: Date
): { cost: number; dataFi: Date | null } {
	let cost = 0;
	let dataFi: Date | null = null;
	for (const [mid, sched] of scheduled) {
		cost += matchCost(mid, sched, matches, slotsById, availabilities);
		if (!dataFi || sched.dataProgramada > dataFi) dataFi = sched.dataProgramada;
	}
	if (dataPrevistaFi && dataFi && dataFi > dataPrevistaFi) {
		const dies = Math.ceil((dataFi.getTime() - dataPrevistaFi.getTime()) / (1000 * 60 * 60 * 24));
		cost += dies * 100; // forta penalització per dia de retard
	}
	return { cost, dataFi };
}

/** Comprova que la regla "no 2 partides/dia mateix jugador" es respecta amb un swap. */
function violatesSameDayRule(
	matchA: PreSchedulerMatch,
	matchB: PreSchedulerMatch,
	schedA: ScheduledMatch,
	schedB: ScheduledMatch,
	slotsById: Map<string, PreSchedulerSlot & { participant_id?: string | null }>,
	scheduled: Map<string, ScheduledMatch>,
	matches: PreSchedulerMatch[]
): boolean {
	// Després del swap, schedA aniria al dia de schedB i viceversa.
	// Per cada participant a A o B, comprovem que no juga 2 partides el mateix dia.
	const participants: string[] = [];
	for (const m of [matchA, matchB]) {
		const s1 = slotsById.get(m.slot1_id);
		const s2 = slotsById.get(m.slot2_id);
		if (s1?.participant_id) participants.push(s1.participant_id);
		if (s2?.participant_id) participants.push(s2.participant_id);
	}

	const isoDay = (d: Date) => d.toISOString().slice(0, 10);
	for (const pid of participants) {
		// Cerca les altres partides d'aquest jugador
		const matchesPlayer = matches.filter(m => {
			const s1 = slotsById.get(m.slot1_id);
			const s2 = slotsById.get(m.slot2_id);
			return (s1?.participant_id === pid || s2?.participant_id === pid)
				&& m.id !== matchA.id && m.id !== matchB.id;
		});
		const ownNewDateA = participants.slice(0, 2).includes(pid) ? schedB.dataProgramada : schedA.dataProgramada;
		const ownNewDateB = participants.slice(2, 4).includes(pid) ? schedA.dataProgramada : schedB.dataProgramada;
		// Determina la data on aniria el jugador després del swap.
		// Simplificat: si juga a A → va a schedB; si juga a B → va a schedA.
		const inA = [matchA.slot1_id, matchA.slot2_id].some(sid => slotsById.get(sid)?.participant_id === pid);
		const newDate = inA ? schedB.dataProgramada : schedA.dataProgramada;
		for (const m of matchesPlayer) {
			const otherSched = scheduled.get(m.id);
			if (!otherSched) continue;
			if (isoDay(otherSched.dataProgramada) === isoDay(newDate)) return true;
		}
		void ownNewDateA; void ownNewDateB;
	}
	return false;
}

/**
 * Optimitza la pre-programació via cerca local greedy (intercanvis entre
 * matches de la mateixa ronda/bracket).
 */
export function optimizeSchedule(input: OptimizerInput): OptimizerResult {
	const { slots, matches, availabilities, dataPrevistaFi } = input;
	const slotsById = new Map(
		slots.map(s => [s.id, s as PreSchedulerSlot & { participant_id?: string | null }])
	);
	// Còpia mutable
	const scheduled = new Map<string, ScheduledMatch>();
	for (const [k, v] of input.scheduled) scheduled.set(k, { ...v });

	const baselineCost = totalCost(scheduled, matches, slotsById, availabilities, dataPrevistaFi).cost;
	let moviments = 0;
	let improved = true;
	let iteracions = 0;
	const MAX_ITER = 100;

	while (improved && iteracions < MAX_ITER) {
		improved = false;
		iteracions++;

		// Agrupar matches per (bracket, ronda) — els swaps només dins de cada grup
		const groups = new Map<string, PreSchedulerMatch[]>();
		for (const m of matches) {
			const s1 = slotsById.get(m.slot1_id);
			const key = `${s1?.bracket_type}-${s1?.ronda}`;
			if (!groups.has(key)) groups.set(key, []);
			groups.get(key)!.push(m);
		}

		for (const group of groups.values()) {
			for (let i = 0; i < group.length; i++) {
				for (let j = i + 1; j < group.length; j++) {
					const mA = group[i];
					const mB = group[j];
					const schedA = scheduled.get(mA.id);
					const schedB = scheduled.get(mB.id);
					if (!schedA || !schedB) continue;

					// Cost actual dels dos matches
					const beforeA = matchCost(mA.id, schedA, matches, slotsById, availabilities);
					const beforeB = matchCost(mB.id, schedB, matches, slotsById, availabilities);
					const before = beforeA + beforeB;
					if (before === 0) continue;

					// Cost si intercanviem slots
					const swappedA: ScheduledMatch = {
						...schedA,
						dataProgramada: schedB.dataProgramada,
						horaInici: schedB.horaInici,
						taulaAssignada: schedB.taulaAssignada
					};
					const swappedB: ScheduledMatch = {
						...schedB,
						dataProgramada: schedA.dataProgramada,
						horaInici: schedA.horaInici,
						taulaAssignada: schedA.taulaAssignada
					};
					const afterA = matchCost(mA.id, swappedA, matches, slotsById, availabilities);
					const afterB = matchCost(mB.id, swappedB, matches, slotsById, availabilities);
					const after = afterA + afterB;
					if (after >= before) continue;

					// Validar que el swap no trenca la regla "no 2 partides/dia"
					if (violatesSameDayRule(mA, mB, swappedA, swappedB, slotsById, scheduled, matches)) continue;

					scheduled.set(mA.id, swappedA);
					scheduled.set(mB.id, swappedB);
					moviments++;
					improved = true;
				}
			}
		}
	}

	// ────────────────────────────────────────────────────────────────────────
	// PAS 2: AVANÇAR matches conflictius a slots anteriors lliures.
	// Per cada match amb cost > 0, intentem moure'l a un slot anterior
	// del calendari sempre que (a) els seus predecessors ja s'hagin
	// programat abans, (b) l'slot estigui lliure, (c) cap dels seus
	// jugadors tingui ja una altra partida aquell dia.
	// ────────────────────────────────────────────────────────────────────────
	if (input.calendari) {
		const cfg = input.calendari;
		const billars = cfg.billars ?? 3;
		const diesActius = cfg.diesActius ?? ['dl', 'dt', 'dc', 'dj', 'dv'];
		const DIES_W = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];
		const ymd = (d: Date) => d.toISOString().slice(0, 10);

		// Generar tots els slots del calendari (mateixa lògica que pre-scheduler).
		type Slot = { date: Date; hora: string; billar: number };
		const allSlots: Slot[] = [];
		for (let d = new Date(cfg.dataInici); d <= cfg.dataFi; d.setDate(d.getDate() + 1)) {
			const codi = DIES_W[d.getDay()];
			if (!diesActius.includes(codi)) continue;
			const hores = [...cfg.horesEstandard];
			if (cfg.horarisExtra && cfg.horarisExtra.dies.includes(codi)) {
				hores.unshift(cfg.horarisExtra.franja);
			}
			for (const h of hores) {
				for (let b = 1; b <= billars; b++) {
					allSlots.push({ date: new Date(d), hora: h, billar: b });
				}
			}
		}

		const slotKey = (s: Slot) => `${ymd(s.date)}|${s.hora}|${s.billar}`;
		const used = new Set<string>();
		for (const sched of scheduled.values()) {
			used.add(`${ymd(sched.dataProgramada)}|${sched.horaInici}|${sched.taulaAssignada}`);
		}

		// Predecessors: matches que alimenten m.slot1_id o m.slot2_id.
		const predecessorsOf = new Map<string, string[]>();
		for (const m of matches) predecessorsOf.set(m.id, []);
		for (const m of matches) {
			if (m.winner_slot_dest_id) {
				for (const other of matches) {
					if (other.slot1_id === m.winner_slot_dest_id || other.slot2_id === m.winner_slot_dest_id) {
						predecessorsOf.get(other.id)!.push(m.id);
						break;
					}
				}
			}
			if (m.loser_slot_dest_id) {
				for (const other of matches) {
					if (other.slot1_id === m.loser_slot_dest_id || other.slot2_id === m.loser_slot_dest_id) {
						predecessorsOf.get(other.id)!.push(m.id);
						break;
					}
				}
			}
		}

		const matchById = new Map(matches.map(m => [m.id, m]));
		const playersOfMatch = (mid: string): string[] => {
			const m = matchById.get(mid);
			if (!m) return [];
			const s1 = slotsById.get(m.slot1_id);
			const s2 = slotsById.get(m.slot2_id);
			const out: string[] = [];
			if (s1?.participant_id) out.push(s1.participant_id);
			if (s2?.participant_id) out.push(s2.participant_id);
			return out;
		};

		// Per cada match, intentem avançar si cost > 0.
		for (const m of matches) {
			const sched = scheduled.get(m.id);
			if (!sched) continue;
			const currentCost = matchCost(m.id, sched, matches, slotsById, availabilities);
			if (currentCost === 0) continue;

			// Data mínima possible: dia DESPRÉS del darrer predecessor.
			const predDates = (predecessorsOf.get(m.id) ?? [])
				.map(pid => scheduled.get(pid)?.dataProgramada)
				.filter((d): d is Date => !!d);
			const earliest = predDates.length > 0
				? new Date(predDates.reduce((a, b) => (a > b ? a : b)).getTime() + 86400000)
				: cfg.dataInici;

			const players = playersOfMatch(m.id);
			const currentKey = `${ymd(sched.dataProgramada)}|${sched.horaInici}|${sched.taulaAssignada}`;

			for (const candidate of allSlots) {
				if (candidate.date < earliest) continue;
				if (candidate.date >= sched.dataProgramada) break;
				const cKey = slotKey(candidate);
				if (used.has(cKey)) continue;

				// Cost si movem a aquest slot
				const newSched: ScheduledMatch = {
					...sched,
					dataProgramada: candidate.date,
					horaInici: candidate.hora,
					taulaAssignada: candidate.billar
				};
				const newCost = matchCost(m.id, newSched, matches, slotsById, availabilities);
				if (newCost >= currentCost) continue;

				// Regla "no 2 partides/dia mateix jugador"
				let conflict = false;
				for (const pid of players) {
					for (const other of matches) {
						if (other.id === m.id) continue;
						const oSched = scheduled.get(other.id);
						if (!oSched) continue;
						const otherPlayers = playersOfMatch(other.id);
						if (!otherPlayers.includes(pid)) continue;
						if (ymd(oSched.dataProgramada) === ymd(candidate.date)) {
							conflict = true;
							break;
						}
					}
					if (conflict) break;
				}
				if (conflict) continue;

				// Aplicar moviment
				used.delete(currentKey);
				used.add(cKey);
				scheduled.set(m.id, newSched);
				moviments++;
				break;
			}
		}
	}

	const final = totalCost(scheduled, matches, slotsById, availabilities, dataPrevistaFi);
	void baselineCost;
	return {
		scheduled,
		movimentsAplicats: moviments,
		costFinal: final.cost,
		dataFiEfectiva: final.dataFi
	};
}
