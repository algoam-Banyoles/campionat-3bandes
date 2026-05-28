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

	// Ordenament topològic estable. Usem un "nivell d'acompassament" per
	// forçar l'ordre: W1 → L1 → W2 → L2 → L3 → W3 → L4 → L5 → W4 → ... → GF.
	// Així L(2r-3) sempre es processa ABANS de W(r), que permet posar barrera
	// cross-bracket: W(r) no comença fins que L(2r-3) hagi acabat.
	const matchInfo = (m: PreSchedulerMatch) => {
		const s = slotById.get(m.slot1_id);
		return {
			bracket: (s?.bracket_type ?? 'winners') as Bracket,
			ronda: s?.ronda ?? 0,
			posicio: s?.posicio ?? 0
		};
	};
	const getNivell = (bracket: Bracket, ronda: number): number => {
		if (bracket === 'grand_final') return 999 + ronda;
		if (bracket === 'winners') {
			if (ronda === 1) return 1;
			return (ronda - 1) * 3;
		}
		// losers: L1→2, L2→4, L3→5, L4→7, L5→8, L6→10, L7→11, L8→13...
		if (ronda % 2 === 1) {
			const k = (ronda + 1) / 2;
			return 3 * k - 1;
		}
		const k = ronda / 2;
		return 3 * k + 1;
	};
	const matchKey = (m: PreSchedulerMatch) => {
		const i = matchInfo(m);
		return [getNivell(i.bracket, i.ronda), i.posicio] as const;
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

	// Rondes "estrictes": cada dia només es poden jugar matches del mateix
	// nivell. Aplica als nivells primerencs (W1, L1, W2, L2, L3, W3, és a dir
	// nivells 1..6 segons getNivell). A partir del nivell 7 (L4 endavant)
	// els dies poden barrejar-se per estalviar dies.
	const STRICT_LEVEL_MAX = 6;
	const levelsByDate = new Map<string, Set<number>>();
	function dayKeyOf(d: Date): string {
		return d.toISOString().slice(0, 10);
	}

	const margeInici = options.diesMargeRondesInicials ?? 1;

	// Tracking de la data més tardana de cada (bracket, ronda) ja processada.
	// Serveix per aplicar una "barrera de ronda": cap match d'una ronda r es
	// programa fins almenys 1 dia després que acabi l'últim de la ronda r-1
	// (mateix bracket). Així es respecta el "dia al mig" entre rondes.
	const lastDateInRound = new Map<string, Date>();

	for (const m of sortedMatches) {
		const matchSlot = slotById.get(m.slot1_id);
		const bracket = matchSlot?.bracket_type ?? 'winners';
		const ronda = matchSlot?.ronda ?? 0;

		// Data mínima: dia després del darrer predecessor (per evitar mateix dia
		// que el predecessor). Excepció: a la grand_final, el mateix dia que la
		// final del winners es permet.
		let earliestDate = options.dataInici;
		for (const predId of predecessorsOf.get(m.id) ?? []) {
			const pred = scheduled.get(predId);
			if (!pred) continue;

			let candidate: Date;
			if (bracket === 'grand_final') {
				candidate = pred.dataProgramada; // pot ser mateix dia
			} else {
				candidate = addDays(pred.dataProgramada, 1);
			}
			if (candidate > earliestDate) earliestDate = candidate;
		}

		// Barrera de ronda: tots els matches d'una ronda han d'haver acabat
		// abans de començar la següent al mateix bracket, amb 1 dia al mig.
		// A més, a R1/R2 Winners i L1/L2/L3 Losers afegim el marge addicional
		// (diesMargeRondesInicials) perquè els jugadors tinguin més temps per
		// recuperar.
		if (ronda > 1 && bracket !== 'grand_final') {
			const prevKey = `${bracket}-${ronda - 1}`;
			const prevEnd = lastDateInRound.get(prevKey);
			if (prevEnd) {
				const isPrimeraRondaWinners = bracket === 'winners' && (ronda - 1) <= 2;
				const isPrimeraRondaLosers = bracket === 'losers' && (ronda - 1) <= 3;
				const margeExtra = (isPrimeraRondaWinners || isPrimeraRondaLosers) ? margeInici : 0;
				const barrier = addDays(prevEnd, 1 + margeExtra);
				if (barrier > earliestDate) earliestDate = barrier;
			}
		}

		// Barrera CROSS-BRACKET per acompassar Winners i Losers:
		// W(r) per r>1 no comença fins que la ronda L(2r-3) hagi acabat.
		// Així el guanyador W no espera molts dies a la final del bracket
		// perquè el Losers ja s'ha anat acompassant darrere.
		// També aplica el marge addicional (1 dia al mig) si la barrera cau
		// dins de les primeres rondes (W2/W3 esperant L1/L3).
		if (bracket === 'winners' && ronda > 1) {
			const losersRondaPrev = 2 * ronda - 3;
			if (losersRondaPrev >= 1) {
				const losersEnd = lastDateInRound.get(`losers-${losersRondaPrev}`);
				if (losersEnd) {
					// Amb marge: 1 dia al mig entre l'última partida de L(2r-3)
					// i la primera de W(r). Aquell dia al mig serveix com a
					// deadline per recuperar partides L ajornades.
					const isPrimeraRondaCross = losersRondaPrev <= 3;
					const margeExtraCross = isPrimeraRondaCross ? margeInici : 0;
					const barrier = addDays(losersEnd, 1 + margeExtraCross);
					if (barrier > earliestDate) earliestDate = barrier;
				}
			}
		}

		// Barrera CROSS-BRACKET Winners→Losers: els matches del Losers que reben
		// perdedors d'una ronda Winners no comencen fins que aquella ronda hagi
		// acabat. Al ronda L1 i L2 amb marge primer (1 dia al mig).
		// Mapping: L1 → W1; L(2k) → W(k+1) per k=1..4 (L2→W2, L4→W3, L6→W4, L8→W5).
		if (bracket === 'losers') {
			let winnersRondaPrev: number | null = null;
			if (ronda === 1) {
				winnersRondaPrev = 1;
			} else if (ronda % 2 === 0) {
				winnersRondaPrev = ronda / 2 + 1;
			}
			if (winnersRondaPrev !== null) {
				const winnersEnd = lastDateInRound.get(`winners-${winnersRondaPrev}`);
				if (winnersEnd) {
					// Amb marge: 1 dia al mig entre l'última partida de W(k) i
					// la primera de L. Aquell dia al mig és deadline per recuperar
					// partides W ajornades.
					const isPrimera = winnersRondaPrev <= 2;
					const margeExtra = isPrimera ? margeInici : 0;
					const barrier = addDays(winnersEnd, 1 + margeExtra);
					if (barrier > earliestDate) earliestDate = barrier;
				}
			}
		}

		const nivellMatch = getNivell(bracket, ronda);

		// Cerquem el primer slot disponible ≥ earliestDate. Si el match és d'un
		// nivell estricte (≤ 6), evitem dies on ja hi hagi matches d'un altre
		// nivell estricte.
		let chosen: Slot | null = null;
		for (const s of allSlots) {
			if (s.date < earliestDate) continue;
			const k = slotKey(s);
			if (used.has(k)) continue;
			if (nivellMatch <= STRICT_LEVEL_MAX) {
				const dKey = dayKeyOf(s.date);
				const existing = levelsByDate.get(dKey);
				if (existing) {
					let conflict = false;
					for (const lvl of existing) {
						if (lvl !== nivellMatch && lvl <= STRICT_LEVEL_MAX) {
							conflict = true;
							break;
						}
					}
					if (conflict) continue;
				}
			}
			chosen = s;
			break;
		}

		if (!chosen) {
			throw new Error(`No hi ha prou slots per encabir tot el bracket (match ${m.id}).`);
		}

		used.add(slotKey(chosen));
		const cKey = dayKeyOf(chosen.date);
		if (!levelsByDate.has(cKey)) levelsByDate.set(cKey, new Set());
		levelsByDate.get(cKey)!.add(nivellMatch);

		// Actualitzar lastDateInRound perquè la barrera de ronda en els
		// successors funcioni (era el bug: el map quedava sempre buit).
		const lastKey = `${bracket}-${ronda}`;
		const prevLast = lastDateInRound.get(lastKey);
		if (!prevLast || chosen.date > prevLast) {
			lastDateInRound.set(lastKey, chosen.date);
		}

		// Inicialment, dataMaximaDisputa = data_fi (es recalcularà després).
		scheduled.set(m.id, {
			matchId: m.id,
			dataProgramada: chosen.date,
			horaInici: chosen.hora,
			taulaAssignada: chosen.billar,
			dataMaximaDisputa: options.dataFi
		});
	}

	// Calcular dataMaximaDisputa = primer dia de la ronda següent (la que rep
	// matches d'aquest) - 1 dia. Així tots els matches d'una mateixa ronda
	// tenen la mateixa deadline: el dia anterior a l'inici de la ronda que
	// els segueix. Si no té successors, la deadline és data_fi.
	const firstDateInRound = new Map<string, Date>();
	for (const m of playables) {
		const sched = scheduled.get(m.id);
		if (!sched) continue;
		const s = slotById.get(m.slot1_id);
		const key = `${s?.bracket_type}-${s?.ronda}`;
		const existing = firstDateInRound.get(key);
		if (!existing || sched.dataProgramada < existing) {
			firstDateInRound.set(key, sched.dataProgramada);
		}
	}

	for (const m of playables) {
		const succs = successorsOf.get(m.id) ?? [];
		if (succs.length === 0) continue;
		const succFirstDates: Date[] = [];
		for (const sid of succs) {
			const succMatch = playablesById.get(sid);
			if (!succMatch) continue;
			const s = slotById.get(succMatch.slot1_id);
			const key = `${s?.bracket_type}-${s?.ronda}`;
			const d = firstDateInRound.get(key);
			if (d) succFirstDates.push(d);
		}
		if (succFirstDates.length === 0) continue;
		const minFirst = succFirstDates.reduce((a, b) => (a < b ? a : b));
		const deadline = addDays(minFirst, -1);
		const entry = scheduled.get(m.id);
		if (entry) entry.dataMaximaDisputa = deadline;
	}

	return scheduled;
}
