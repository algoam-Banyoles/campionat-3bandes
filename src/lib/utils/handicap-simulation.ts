/**
 * Motor pur de simulació Monte Carlo del torneig hàndicap.
 *
 * Per cada partida pendent:
 *  - Sorteja guanyador 50/50 (l'hàndicap iguala distàncies).
 *  - Si les disponibilitats dels dos jugadors no s'intersecten, tira moneda
 *    50/50 per decidir quina disponibilitat preval en aquesta partida concreta
 *    (l'altre jugador hi cedeix puntualment).
 *  - Programació amb scheduleMatches() (funció existent, pura).
 *  - Propaga el guanyador i el perdedor pels slots destí (in-memory).
 *  - Resol byes en cascada.
 *
 * Retorna la data de finalització del torneig (data del darrer match de la
 * Grand Final que s'ha jugat realment — GF-R1 sense reset o GF-R2 amb reset).
 */

import {
	scheduleMatches,
	parseLocalDate,
	formatDate,
	type ParticipantAvailability,
	type OccupiedSlot,
	type MatchToSchedule,
	type ScheduleItemResult,
	type TournamentConfig
} from './handicap-scheduler';
import type {
	SimulationState,
	MatchSnapshot,
	SlotSnapshot,
	MatchEstat
} from './handicap-simulation-state';

export interface SimulationResult {
	endDate: string | null;
	matchesPlayed: number;
	usedResetMatch: boolean;
	/** Mètriques de depuració. */
	failedMatches: number;
	resolvedByCoinFlip: number;
}

interface MutableMatch {
	id: string;
	slot1_id: string;
	slot2_id: string;
	winner_slot_dest_id: string | null;
	loser_slot_dest_id: string | null;
	estat: MatchEstat;
	guanyador_participant_id: string | null;
	data_programada: string | null;
}

interface MutableSlot {
	id: string;
	bracket_type: 'winners' | 'losers' | 'grand_final';
	ronda: number;
	posicio: number;
	is_bye: boolean;
	participant_id: string | null;
}

const MAX_ITERATIONS = 200;
const NO_OVERLAP_PATTERN = /no coincideixen/i;

/**
 * Executa una simulació completa del torneig.
 * Si el torneig està finalitzat o no té matches, retorna endDate=null.
 */
export function simulateTournamentEnd(
	state: SimulationState,
	rng: () => number = Math.random
): SimulationResult {
	if (state.matches.length === 0) {
		return {
			endDate: null,
			matchesPlayed: 0,
			usedResetMatch: false,
			failedMatches: 0,
			resolvedByCoinFlip: 0
		};
	}

	// ── Clonar estat en estructures mutables ────────────────────────────────
	const slots: Map<string, MutableSlot> = new Map(
		state.slots.map((s) => [
			s.id,
			{
				id: s.id,
				bracket_type: s.bracket_type,
				ronda: s.ronda,
				posicio: s.posicio,
				is_bye: s.is_bye,
				participant_id: s.participant_id
			}
		])
	);
	const matches: Map<string, MutableMatch> = new Map(
		state.matches.map((m) => [
			m.id,
			{
				id: m.id,
				slot1_id: m.slot1_id,
				slot2_id: m.slot2_id,
				winner_slot_dest_id: m.winner_slot_dest_id,
				loser_slot_dest_id: m.loser_slot_dest_id,
				estat: m.estat,
				guanyador_participant_id: m.guanyador_participant_id,
				data_programada: m.data_programada
			}
		])
	);

	const availMap: Map<string, ParticipantAvailability> = new Map(
		state.participants.map((p) => [
			p.id,
			{
				participant_id: p.id,
				preferencies_dies: [...p.preferencies_dies],
				preferencies_hores: [...p.preferencies_hores]
			}
		])
	);

	// Slots ocupats: externs (immutables) + matches del propi torneig ja programats/jugats
	const occupied: OccupiedSlot[] = [...state.occupiedSlotsExternal];
	for (const m of state.matches) {
		if (
			(m.estat === 'programada' || m.estat === 'jugada' || m.estat === 'walkover') &&
			m.data_programada &&
			m.hora_inici &&
			m.taula_assignada
		) {
			occupied.push({ data: m.data_programada, hora: m.hora_inici, taula: m.taula_assignada });
		}
	}

	// Dies on cada participant ja té una partida programada/jugada
	const playerBusyDays: Map<string, Set<string>> = new Map();
	for (const m of state.matches) {
		if (
			(m.estat === 'programada' || m.estat === 'jugada' || m.estat === 'walkover') &&
			m.data_programada
		) {
			const slot1 = slots.get(m.slot1_id);
			const slot2 = slots.get(m.slot2_id);
			if (slot1?.participant_id) addBusy(playerBusyDays, slot1.participant_id, m.data_programada);
			if (slot2?.participant_id) addBusy(playerBusyDays, slot2.participant_id, m.data_programada);
		}
	}

	// Config "expandida" — pot créixer si els matches no caben
	let effectiveConfig: TournamentConfig = {
		data_inici: state.dataMinima > state.config.data_inici ? state.dataMinima : state.config.data_inici,
		data_fi: state.config.data_fi,
		horaris_extra: state.config.horaris_extra
	};

	// ── Resoldre byes cascade inicialment ───────────────────────────────────
	resolveCascadeByes(matches, slots);

	let finalDate: string | null = null;
	let usedResetMatch = false;
	let matchesPlayed = 0;
	let failedMatches = 0;
	let resolvedByCoinFlip = 0;

	for (let iter = 0; iter < MAX_ITERATIONS; iter++) {
		const ready = findReadyMatches(matches, slots);
		if (ready.length === 0) break;

		let progressed = false;

		for (const m of ready) {
			const slot1 = slots.get(m.slot1_id)!;
			const slot2 = slots.get(m.slot2_id)!;

			// Si l'estat ja és terminal, ignora (defensa)
			if (m.estat === 'jugada' || m.estat === 'walkover' || m.estat === 'bye') continue;

			const p1Id = slot1.participant_id;
			const p2Id = slot2.participant_id;
			if (!p1Id || !p2Id) continue;

			// Decidir data: si ja és 'programada', usa la data real
			let matchDate: string | null = m.data_programada;
			let matchHora: string | null = null;
			let matchTaula: number | null = null;

			if (m.estat === 'pendent') {
				const result = tryScheduleOne(
					m,
					p1Id,
					p2Id,
					availMap,
					effectiveConfig,
					occupied,
					playerBusyDays,
					rng
				);

				if (result.scheduled) {
					matchDate = result.data;
					matchHora = result.hora;
					matchTaula = result.taula;
					if (result.coinFlipUsed) resolvedByCoinFlip++;
				} else if (result.extended) {
					// Expandim el període 4 setmanes i tornem a intentar al següent cicle
					effectiveConfig = {
						...effectiveConfig,
						data_fi: addWeeks(effectiveConfig.data_fi, 4)
					};
					continue; // re-intentarem al següent iter
				} else {
					failedMatches++;
					continue;
				}
			}

			if (!matchDate) {
				// estat='programada' però sense data: defensa
				failedMatches++;
				continue;
			}

			// Marca occupied (només si era pendent acabat de programar)
			if (matchHora && matchTaula) {
				occupied.push({ data: matchDate, hora: matchHora, taula: matchTaula });
				addBusy(playerBusyDays, p1Id, matchDate);
				addBusy(playerBusyDays, p2Id, matchDate);
			}

			// Sorteja guanyador 50/50
			const winnerId = rng() < 0.5 ? p1Id : p2Id;
			const loserId = winnerId === p1Id ? p2Id : p1Id;

			m.estat = 'jugada';
			m.guanyador_participant_id = winnerId;
			m.data_programada = matchDate;
			matchesPlayed++;
			progressed = true;

			// Gran Final lògica especial
			const isGF1 = slot1.bracket_type === 'grand_final' && slot1.ronda === 1;
			const isGF2 = slot1.bracket_type === 'grand_final' && slot1.ronda === 2;
			const winnersSideWinsGF1 = isGF1 && winnerId === p1Id; // slot1 = winners side

			if (winnersSideWinsGF1) {
				// Campió directe; marquem GF-R2 com a bye si existeix
				finalDate = matchDate;
				markGFR2AsSkipped(matches, slots);
			} else if (isGF1) {
				// Cal reset → propagar tots dos a GF-R2
				usedResetMatch = true;
				if (m.winner_slot_dest_id) {
					const dest = slots.get(m.winner_slot_dest_id);
					if (dest) dest.participant_id = winnerId;
				}
				if (m.loser_slot_dest_id) {
					const dest = slots.get(m.loser_slot_dest_id);
					if (dest) dest.participant_id = loserId;
				}
			} else if (isGF2) {
				finalDate = matchDate;
			} else {
				// Propagació estàndard
				if (m.winner_slot_dest_id) {
					const dest = slots.get(m.winner_slot_dest_id);
					if (dest) dest.participant_id = winnerId;
				}
				if (m.loser_slot_dest_id) {
					const dest = slots.get(m.loser_slot_dest_id);
					if (dest) dest.participant_id = loserId;
				}
			}

			resolveCascadeByes(matches, slots);
		}

		if (!progressed) break;
	}

	return {
		endDate: finalDate,
		matchesPlayed,
		usedResetMatch,
		failedMatches,
		resolvedByCoinFlip
	};
}

// ── Helpers ──────────────────────────────────────────────────────────────────

interface TryScheduleResult {
	scheduled: boolean;
	data?: string;
	hora?: string;
	taula?: number;
	coinFlipUsed?: boolean;
	extended?: boolean;
}

function tryScheduleOne(
	m: MutableMatch,
	p1Id: string,
	p2Id: string,
	availMap: Map<string, ParticipantAvailability>,
	config: TournamentConfig,
	occupied: OccupiedSlot[],
	playerBusyDays: Map<string, Set<string>>,
	rng: () => number
): TryScheduleResult {
	const a1 = availMap.get(p1Id) ?? { participant_id: p1Id, preferencies_dies: [], preferencies_hores: [] };
	const a2 = availMap.get(p2Id) ?? { participant_id: p2Id, preferencies_dies: [], preferencies_hores: [] };

	const toSchedule: MatchToSchedule = {
		id: m.id,
		bracket_type: 'winners', // valor dummy; scheduler només l'usa per priorització
		ronda: 1,
		matchPos: 1,
		player1_participant_id: p1Id,
		player2_participant_id: p2Id,
		player1_soci_numero: 0,
		player2_soci_numero: 0
	};

	// Injectem busy dies a través d'occupiedSlots additionals: el scheduler ja gestiona
	// la restricció "1 partida/jugador/dia" via la seva pròpia map interna que parteix
	// de zero per cada crida; per tant, aquí l'hem de simular afegint occupied per a
	// CADA combinació (data, hora, taula) on un dels dos jugadors està ocupat.
	// Però això és costós. Alternativa: filtrem els dies on un dels dos està busy
	// afegint occupied[1..3 taules][totes les hores] per a aquell dia.
	const augmented = augmentOccupied(occupied, playerBusyDays, p1Id, p2Id, config);

	const results = scheduleMatches({
		matches: [toSchedule],
		config,
		participants: [a1, a2],
		occupiedSlots: augmented
	});

	const r = results[0];
	if (r && r.scheduled) {
		return { scheduled: true, data: r.data, hora: r.hora, taula: r.taula };
	}

	// Incompatibilitat de disponibilitats → coin flip
	if (r && !r.scheduled && NO_OVERLAP_PATTERN.test(r.motiu)) {
		const winner = rng() < 0.5 ? a1 : a2;
		const a1Forced: ParticipantAvailability = {
			participant_id: p1Id,
			preferencies_dies: [...winner.preferencies_dies],
			preferencies_hores: [...winner.preferencies_hores]
		};
		const a2Forced: ParticipantAvailability = {
			participant_id: p2Id,
			preferencies_dies: [...winner.preferencies_dies],
			preferencies_hores: [...winner.preferencies_hores]
		};
		const retry = scheduleMatches({
			matches: [toSchedule],
			config,
			participants: [a1Forced, a2Forced],
			occupiedSlots: augmented
		});
		const r2 = retry[0];
		if (r2 && r2.scheduled) {
			return { scheduled: true, data: r2.data, hora: r2.hora, taula: r2.taula, coinFlipUsed: true };
		}
		// Pot ser que no hi hagi slots dins el període
		return { scheduled: false, extended: true };
	}

	// Sense slots disponibles → ampliem el període
	return { scheduled: false, extended: true };
}

/**
 * Construeix una llista occupiedSlots augmentada que "bloqueja" els dies on
 * un dels dos jugadors ja juga (afegim totes les taules i hores per aquell dia).
 *
 * Això s'ha de fer perquè scheduleMatches() parteix la seva map "playerDayBusy"
 * de zero a cada crida, però nosaltres simulem matches d'1 en 1 i necessitem
 * persistir aquesta restricció entre crides.
 */
function augmentOccupied(
	base: OccupiedSlot[],
	playerBusyDays: Map<string, Set<string>>,
	p1Id: string,
	p2Id: string,
	config: TournamentConfig
): OccupiedSlot[] {
	const busyDays = new Set<string>();
	for (const d of playerBusyDays.get(p1Id) ?? []) busyDays.add(d);
	for (const d of playerBusyDays.get(p2Id) ?? []) busyDays.add(d);

	if (busyDays.size === 0) return base;

	const hours: string[] = [];
	if (config.horaris_extra?.franja) hours.push(config.horaris_extra.franja);
	hours.push('18:00', '19:00');

	const extra: OccupiedSlot[] = [];
	for (const data of busyDays) {
		for (const hora of hours) {
			for (let t = 1; t <= 3; t++) {
				extra.push({ data, hora, taula: t });
			}
		}
	}
	return [...base, ...extra];
}

function addBusy(map: Map<string, Set<string>>, pid: string, date: string) {
	if (!map.has(pid)) map.set(pid, new Set());
	map.get(pid)!.add(date);
}

function findReadyMatches(
	matches: Map<string, MutableMatch>,
	slots: Map<string, MutableSlot>
): MutableMatch[] {
	const ready: MutableMatch[] = [];
	for (const m of matches.values()) {
		if (m.estat === 'jugada' || m.estat === 'walkover' || m.estat === 'bye') continue;
		const s1 = slots.get(m.slot1_id);
		const s2 = slots.get(m.slot2_id);
		if (!s1 || !s2) continue;
		if (s1.is_bye || s2.is_bye) continue;
		if (!s1.participant_id || !s2.participant_id) continue;
		ready.push(m);
	}
	// Ordena per ronda + bracket per donar prioritat a les rondes baixes
	const bracketOrder: Record<string, number> = { winners: 0, losers: 1, grand_final: 2 };
	ready.sort((a, b) => {
		const sa = slots.get(a.slot1_id)!;
		const sb = slots.get(b.slot1_id)!;
		if (sa.ronda !== sb.ronda) return sa.ronda - sb.ronda;
		const ba = bracketOrder[sa.bracket_type] ?? 3;
		const bb = bracketOrder[sb.bracket_type] ?? 3;
		if (ba !== bb) return ba - bb;
		return sa.posicio - sb.posicio;
	});
	return ready;
}

/**
 * Resol byes en cascada: matches pendents on un slot és bye i l'altre té participant.
 * El participant avança automàticament al winner_slot_dest_id.
 */
function resolveCascadeByes(
	matches: Map<string, MutableMatch>,
	slots: Map<string, MutableSlot>
) {
	for (let iter = 0; iter < 50; iter++) {
		let resolved = 0;
		for (const m of matches.values()) {
			if (m.estat !== 'pendent') continue;
			const s1 = slots.get(m.slot1_id);
			const s2 = slots.get(m.slot2_id);
			if (!s1 || !s2) continue;

			const s1bye = s1.is_bye;
			const s2bye = s2.is_bye;
			const p1 = s1.participant_id;
			const p2 = s2.participant_id;

			if (s1bye && p2) {
				m.estat = 'bye';
				m.guanyador_participant_id = p2;
				if (m.winner_slot_dest_id) {
					const dest = slots.get(m.winner_slot_dest_id);
					if (dest) dest.participant_id = p2;
				}
				resolved++;
			} else if (s2bye && p1) {
				m.estat = 'bye';
				m.guanyador_participant_id = p1;
				if (m.winner_slot_dest_id) {
					const dest = slots.get(m.winner_slot_dest_id);
					if (dest) dest.participant_id = p1;
				}
				resolved++;
			} else if (s1bye && s2bye) {
				m.estat = 'bye';
				resolved++;
			}
		}
		if (resolved === 0) break;
	}
}

function markGFR2AsSkipped(
	matches: Map<string, MutableMatch>,
	slots: Map<string, MutableSlot>
) {
	for (const m of matches.values()) {
		const s1 = slots.get(m.slot1_id);
		if (s1?.bracket_type === 'grand_final' && s1.ronda === 2 && m.estat === 'pendent') {
			m.estat = 'bye';
		}
	}
}

function addWeeks(dateStr: string, weeks: number): string {
	const d = parseLocalDate(dateStr);
	d.setDate(d.getDate() + weeks * 7);
	return formatDate(d);
}

// ── Agregats per a N simulacions ─────────────────────────────────────────────

export interface SimulationAggregate {
	dates: string[]; // dates de finalització de cada sim
	failedSims: number; // sims sense endDate
	resetMatchRate: number; // 0..1
	p10: string | null;
	p50: string | null;
	p90: string | null;
	mean: string | null;
	stdDevDays: number | null;
	minDate: string | null;
	maxDate: string | null;
	withinDataFiPct: number | null; // % sims que acaben <= state.config.data_fi
}

export function aggregateSimulations(
	results: SimulationResult[],
	dataFi: string
): SimulationAggregate {
	const dates = results.map((r) => r.endDate).filter((d): d is string => d !== null);
	const failedSims = results.length - dates.length;
	const resetMatchRate =
		results.length === 0 ? 0 : results.filter((r) => r.usedResetMatch).length / results.length;

	if (dates.length === 0) {
		return {
			dates,
			failedSims,
			resetMatchRate,
			p10: null,
			p50: null,
			p90: null,
			mean: null,
			stdDevDays: null,
			minDate: null,
			maxDate: null,
			withinDataFiPct: null
		};
	}

	const sorted = [...dates].sort();
	const p10 = sorted[Math.floor(sorted.length * 0.1)] ?? sorted[0];
	const p50 = sorted[Math.floor(sorted.length * 0.5)] ?? sorted[0];
	const p90 = sorted[Math.floor(sorted.length * 0.9)] ?? sorted[sorted.length - 1];
	const minDate = sorted[0];
	const maxDate = sorted[sorted.length - 1];

	const epoch = parseLocalDate(sorted[0]).getTime();
	const offsets = dates.map((d) => (parseLocalDate(d).getTime() - epoch) / 86400000);
	const meanOffset = offsets.reduce((a, b) => a + b, 0) / offsets.length;
	const variance =
		offsets.reduce((a, b) => a + (b - meanOffset) ** 2, 0) / offsets.length;
	const stdDevDays = Math.sqrt(variance);
	const meanDate = new Date(epoch + meanOffset * 86400000);

	const withinDataFiPct = dates.filter((d) => d <= dataFi).length / dates.length;

	return {
		dates,
		failedSims,
		resetMatchRate,
		p10,
		p50,
		p90,
		mean: formatDate(meanDate),
		stdDevDays,
		minDate,
		maxDate,
		withinDataFiPct
	};
}
