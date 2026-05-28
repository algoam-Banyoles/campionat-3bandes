/**
 * Pre-scheduler estructural per al bracket d'hàndicap.
 *
 * A diferència de `handicap-scheduler.ts` (que opera amb participants ja
 * assignats), aquest mòdul programa el bracket SENSE necessitar el sorteig:
 * només a partir de l'estructura de matches i slots.
 *
 * Regles:
 *   - Cada match té assignat un dia, una hora i un billar.
 *   - Un match no pot programar-se abans que els seus PREDECESSORS estructurals
 *     (matches que l'alimenten via winner_slot_dest_id o loser_slot_dest_id).
 *     A més, no pot anar el MATEIX dia que el seu predecessor (perquè un mateix
 *     jugador no jugui dues partides el mateix dia).
 *   - La Gran Final pot anar el mateix dia que la Final dels Winners (la final
 *     d'eliminació doble s'admet en jornada única).
 *   - La `data_maxima_disputa` d'un match = data programada del primer successor
 *     menys 1 dia. Si no té cap successor → data_fi del torneig.
 */

export type Bracket = 'winners' | 'losers' | 'grand_final';

export interface PreSchedulerSlot {
	id: string;
	bracket_type: Bracket;
	ronda: number;
	posicio: number;
}

export interface PreSchedulerMatch {
	id: string;
	slot1_id: string;
	slot2_id: string;
	winner_slot_dest_id: string | null;
	loser_slot_dest_id: string | null;
	estat?: string; // si és 'bye' s'omet
}

export interface PreSchedulerOptions {
	/** Data d'inici del torneig (inclusiva). */
	dataInici: Date;
	/** Data de fi del torneig (inclusiva). */
	dataFi: Date;
	/** Hores estàndard, ex: ['18:00', '19:00']. */
	horesEstandard: string[];
	/** Franja extra opcional (ex: '17:00') en dies concrets ('dl', 'dt', ...). */
	horarisExtra?: { franja: string; dies: string[] } | null;
	/** Nombre de billars disponibles. Per defecte 3. */
	billars?: number;
	/** Dies de la setmana en què hi ha activitat (per defecte dl..dv). */
	diesActius?: string[];
	/**
	 * Dies addicionals de marge entre el predecessor i el successor a les
	 * PRIMERES rondes (R1 i R2 de Winners; L1, L2 i L3 de Losers). Per defecte
	 * 1, és a dir, separació total de 2 dies entre matches consecutius. Posa
	 * 0 per al comportament minimalista (sense marge extra).
	 */
	diesMargeRondesInicials?: number;
}

export interface ScheduledMatch {
	matchId: string;
	dataProgramada: Date;
	horaInici: string; // 'HH:MM'
	taulaAssignada: number; // 1..billars
	dataMaximaDisputa: Date;
}

const DIES_SETMANA = ['dg', 'dl', 'dt', 'dc', 'dj', 'dv', 'ds'];

function diaCodi(date: Date): string {
	return DIES_SETMANA[date.getDay()];
}

function isSameDay(a: Date, b: Date): boolean {
	return a.getFullYear() === b.getFullYear()
		&& a.getMonth() === b.getMonth()
		&& a.getDate() === b.getDate();
}

function addDays(date: Date, n: number): Date {
	const d = new Date(date);
	d.setDate(d.getDate() + n);
	return d;
}

/**
 * Calcula una programació estructural per a tots els matches del bracket.
 * Retorna un Map<matchId, ScheduledMatch>.
 *
 * Pot llençar Error si l'event no té prou dies per encabir tots els matches.
 */
export function preSchedulingForBracket(
	slots: PreSchedulerSlot[],
	matches: PreSchedulerMatch[],
	options: PreSchedulerOptions
): Map<string, ScheduledMatch> {
	const billars = options.billars ?? 3;
	const diesActius = options.diesActius ?? ['dl', 'dt', 'dc', 'dj', 'dv'];

	const slotById = new Map(slots.map(s => [s.id, s]));

	// Filtrar 'bye' i altres matches no jugables.
	const playables = matches.filter(m => m.estat !== 'bye');

	// Mapa slot → match que ALIMENTA aquest slot (és a dir, slot és destí
	// de winner o loser d'aquell match). Així, per a un match m, els seus
	// PREDECESSORS són els matches que alimenten m.slot1_id i m.slot2_id.
	const slotFedBy = new Map<string, string>(); // slot_id → match_id
	for (const m of playables) {
		if (m.winner_slot_dest_id) slotFedBy.set(m.winner_slot_dest_id, m.id);
		if (m.loser_slot_dest_id) slotFedBy.set(m.loser_slot_dest_id, m.id);
	}

	// SUCCESSORS d'un match m: matches que reben winner o loser des de m.
	// (un per cada destí; total 0, 1 o 2 per match).
	const successorsOf = new Map<string, string[]>();
	for (const m of playables) successorsOf.set(m.id, []);
	for (const m of playables) {
		const wDest = m.winner_slot_dest_id;
		const lDest = m.loser_slot_dest_id;
		if (wDest) {
			// L'slot wDest pertany a un altre match; trobem-lo:
			for (const other of playables) {
				if (other.slot1_id === wDest || other.slot2_id === wDest) {
					successorsOf.get(m.id)!.push(other.id);
					break;
				}
			}
		}
		if (lDest) {
			for (const other of playables) {
				if (other.slot1_id === lDest || other.slot2_id === lDest) {
					successorsOf.get(m.id)!.push(other.id);
					break;
				}
			}
		}
	}

	// PREDECESSORS d'un match m: l'invers.
	const predecessorsOf = new Map<string, string[]>();
	for (const m of playables) predecessorsOf.set(m.id, []);
	for (const [matchId, succs] of successorsOf) {
		for (const s of succs) predecessorsOf.get(s)!.push(matchId);
	}

	// Ordenament topològic estable: tots els predecessors d'un match abans que
	// ell. El "criteri secundari" (per desempatar) és bracket+ronda+posició.
	const order: Record<Bracket, number> = { winners: 0, losers: 1, grand_final: 2 };
	const matchInfo = (m: PreSchedulerMatch) => {
		const s = slotById.get(m.slot1_id);
		return {
			bracket: s?.bracket_type ?? 'winners',
			ronda: s?.ronda ?? 0,
			posicio: s?.posicio ?? 0
		};
	};
	const matchKey = (m: PreSchedulerMatch) => {
		const i = matchInfo(m);
		// Grand Final sempre va a la "ronda virtual" més alta perquè depèn de
		// la final del Winners i del Losers.
		const rondaVirtual = i.bracket === 'grand_final' ? 9999 + i.ronda : i.ronda;
		return [order[i.bracket as Bracket], rondaVirtual, i.posicio] as const;
	};
	const indegree = new Map<string, number>();
	for (const m of playables) indegree.set(m.id, (predecessorsOf.get(m.id) ?? []).length);

	const sortedMatches: PreSchedulerMatch[] = [];
	const playablesById = new Map(playables.map(m => [m.id, m]));
	// Cua amb ordenament estable per matchKey
	const sortQueue = (q: string[]) => {
		q.sort((a, b) => {
			const ma = playablesById.get(a)!;
			const mb = playablesById.get(b)!;
			const ka = matchKey(ma);
			const kb = matchKey(mb);
			for (let i = 0; i < ka.length; i++) {
				if (ka[i] !== kb[i]) return (ka[i] as number) - (kb[i] as number);
			}
			return 0;
		});
	};

	const queue: string[] = [];
	for (const m of playables) if ((indegree.get(m.id) ?? 0) === 0) queue.push(m.id);
	sortQueue(queue);

	while (queue.length > 0) {
		const id = queue.shift()!;
		const m = playablesById.get(id);
		if (m) sortedMatches.push(m);
		for (const succ of successorsOf.get(id) ?? []) {
			indegree.set(succ, (indegree.get(succ) ?? 0) - 1);
			if (indegree.get(succ) === 0) queue.push(succ);
		}
		sortQueue(queue);
	}

	if (sortedMatches.length !== playables.length) {
		throw new Error('Cicle detectat al graf de dependències del bracket.');
	}

	// Generem una llista de slots cronològics (dia, hora, billar)
	type Slot = { date: Date; hora: string; billar: number };
	const allSlots: Slot[] = [];
	const used = new Set<string>(); // key: 'YYYY-MM-DD|HH:MM|B'

	for (let d = new Date(options.dataInici); d <= options.dataFi; d = addDays(d, 1)) {
		const codi = diaCodi(d);
		if (!diesActius.includes(codi)) continue;
		const hores = [...options.horesEstandard];
		if (options.horarisExtra && options.horarisExtra.dies.includes(codi)) {
			hores.unshift(options.horarisExtra.franja);
		}
		for (const h of hores) {
			for (let b = 1; b <= billars; b++) {
				allSlots.push({ date: new Date(d), hora: h, billar: b });
			}
		}
	}

	if (allSlots.length === 0) {
		throw new Error('No hi ha cap dia / slot disponible al període configurat.');
	}

	const scheduled = new Map<string, ScheduledMatch>();

	function slotKey(s: Slot): string {
		return `${s.date.toISOString().slice(0, 10)}|${s.hora}|${s.billar}`;
	}

	const margeInici = options.diesMargeRondesInicials ?? 1;

	for (const m of sortedMatches) {
		const matchSlot = slotById.get(m.slot1_id);
		const bracket = matchSlot?.bracket_type ?? 'winners';

		// Data mínima: dia després del darrer predecessor (per evitar mateix dia
		// que el predecessor). Excepció: a la grand_final, el mateix dia que la
		// final del winners es permet.
		// A més, si el predecessor està a R1/R2 de Winners o L1/L2/L3 de Losers,
		// donem un dia addicional de marge per donar més joc als jugadors per
		// recuperar (configurable via diesMargeRondesInicials).
		let earliestDate = options.dataInici;
		for (const predId of predecessorsOf.get(m.id) ?? []) {
			const pred = scheduled.get(predId);
			if (!pred) continue;
			const predMatch = playablesById.get(predId);
			const predSlot = predMatch ? slotById.get(predMatch.slot1_id) : null;
			const predBracket = predSlot?.bracket_type;
			const predRonda = predSlot?.ronda ?? 0;
			const isPrimeraRondaWinners = predBracket === 'winners' && predRonda <= 2;
			const isPrimeraRondaLosers = predBracket === 'losers' && predRonda <= 3;
			const margeExtra = (isPrimeraRondaWinners || isPrimeraRondaLosers) ? margeInici : 0;

			let candidate: Date;
			if (bracket === 'grand_final') {
				candidate = pred.dataProgramada; // pot ser mateix dia
			} else {
				candidate = addDays(pred.dataProgramada, 1 + margeExtra);
			}
			if (candidate > earliestDate) earliestDate = candidate;
		}

		// Cerquem el primer slot disponible ≥ earliestDate.
		let chosen: Slot | null = null;
		for (const s of allSlots) {
			if (s.date < earliestDate) continue;
			const k = slotKey(s);
			if (used.has(k)) continue;
			chosen = s;
			break;
		}

		if (!chosen) {
			throw new Error(`No hi ha prou slots per encabir tot el bracket (match ${m.id}).`);
		}

		used.add(slotKey(chosen));
		// Inicialment, dataMaximaDisputa = data_fi (es recalcularà després).
		scheduled.set(m.id, {
			matchId: m.id,
			dataProgramada: chosen.date,
			horaInici: chosen.hora,
			taulaAssignada: chosen.billar,
			dataMaximaDisputa: options.dataFi
		});
	}

	// Calcular dataMaximaDisputa = min(dataProgramada dels successors) - 1 dia.
	// Si no té successors, la deadline és data_fi.
	for (const m of playables) {
		const succs = successorsOf.get(m.id) ?? [];
		const succDates = succs
			.map(sid => scheduled.get(sid)?.dataProgramada)
			.filter((d): d is Date => !!d);
		if (succDates.length === 0) continue; // ja és data_fi
		const minSuccDate = succDates.reduce((a, b) => (a < b ? a : b));
		const deadline = addDays(minSuccDate, -1);
		const entry = scheduled.get(m.id);
		if (entry) entry.dataMaximaDisputa = deadline;
	}

	return scheduled;
}
