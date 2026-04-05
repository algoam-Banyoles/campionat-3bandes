/**
 * Algorisme de calendarització automàtica per al torneig hàndicap.
 *
 * Purament funcional — sense dependències de BD ni efectes secundaris.
 * Dissenyat per ser fàcilment testable.
 *
 * Restriccions aplicades:
 *  - Màxim 1 partida per jugador per dia
 *  - No es repeteix un slot (data + hora + taula) per a dues partides
 *  - Ambdós jugadors han d'estar disponibles (intersecció de preferències)
 *  - Els slots ocupats per altres campionats queden exclosos
 *
 * Prioritat de programació:
 *  - Rondes baixes primer (R1 < R2 < R3...)
 *  - Dins la mateixa ronda: winners > losers > grand_final
 *  - Dins el mateix bracket i ronda: posició ascendent
 */

// ── Tipus públics ─────────────────────────────────────────────────────────────

/** Partida a programar (ambdós jugadors han d'estar assignats als slots). */
export interface MatchToSchedule {
	/** handicap_matches.id */
	id: string;
	bracket_type: 'winners' | 'losers' | 'grand_final';
	/** Ronda dins el bracket (1 = primera ronda) */
	ronda: number;
	/** Posició 1-based dins la ronda (Math.ceil(slot.posicio / 2)) */
	matchPos: number;
	/** handicap_participants.id del jugador 1 (per consultar disponibilitat) */
	player1_participant_id: string;
	/** handicap_participants.id del jugador 2 */
	player2_participant_id: string;
	/** players.id del jugador 1 (per a calendari_partides.jugador1_id) */
	player1_player_id: string;
	/** players.id del jugador 2 */
	player2_player_id: string;
}

/** Disponibilitat declarada d'un participant. */
export interface ParticipantAvailability {
	participant_id: string;
	/** Dies disponibles. Buit = disponible tots els dies laborables. */
	preferencies_dies: string[]; // 'dl' | 'dt' | 'dc' | 'dj' | 'dv'
	/** Hores disponibles. Buit = disponible a totes les hores. */
	preferencies_hores: string[]; // '17:00' | '18:00' | '19:00'
}

/** Configuració del torneig per a la calendarització. */
export interface TournamentConfig {
	/** Data d'inici del període de joc. Format 'YYYY-MM-DD'. */
	data_inici: string;
	/** Data de fi del període de joc. Format 'YYYY-MM-DD'. */
	data_fi: string;
	/** Franja horària extra (p.ex. 17:00) i els dies que s'habilita. */
	horaris_extra?: {
		franja: string; // p.ex. '17:00'
		dies: string[]; // dies laborables on s'habilita, p.ex. ['dl', 'dc']
	};
}

/** Slot (data + hora + taula) ja ocupat per un altre campionat o partida existent. */
export interface OccupiedSlot {
	data: string; // 'YYYY-MM-DD'
	hora: string; // 'HH:MM'
	taula: number; // 1, 2 o 3
}

/** Resultat de la programació d'una partida. */
export type ScheduleItemResult =
	| { scheduled: true; match_id: string; data: string; hora: string; taula: number }
	| { scheduled: false; match_id: string; motiu: string };

export interface ScheduleInput {
	matches: MatchToSchedule[];
	config: TournamentConfig;
	participants: ParticipantAvailability[];
	occupiedSlots: OccupiedSlot[];
}

// ── Constants ─────────────────────────────────────────────────────────────────

const STANDARD_HOURS = ['18:00', '19:00'] as const;
const NUM_TAULES = 3;

const WEEKDAY_CODES: Record<number, string> = {
	1: 'dl',
	2: 'dt',
	3: 'dc',
	4: 'dj',
	5: 'dv'
};

const BRACKET_ORDER: Record<string, number> = {
	winners: 0,
	losers: 1,
	grand_final: 2
};

// ── Helpers privats ───────────────────────────────────────────────────────────

/** Retorna el codi de dia setmanal ('dl'..'dv') o null si és cap de setmana. */
function getWeekdayCode(date: Date): string | null {
	return WEEKDAY_CODES[date.getDay()] ?? null;
}

/** Formata una Date com 'YYYY-MM-DD' en hora local. */
export function formatDate(date: Date): string {
	const y = date.getFullYear();
	const m = String(date.getMonth() + 1).padStart(2, '0');
	const d = String(date.getDate()).padStart(2, '0');
	return `${y}-${m}-${d}`;
}

/** Parseja 'YYYY-MM-DD' com a Data local (evita problemes de timezone UTC). */
export function parseLocalDate(str: string): Date {
	const [y, m, d] = str.split('-').map(Number);
	return new Date(y, m - 1, d);
}

function isPlayerAvailable(
	avail: ParticipantAvailability,
	dayCode: string,
	hora: string
): boolean {
	const diaOk =
		avail.preferencies_dies.length === 0 || avail.preferencies_dies.includes(dayCode);
	const horaOk =
		avail.preferencies_hores.length === 0 || avail.preferencies_hores.includes(hora);
	return diaOk && horaOk;
}

/** Ordena les partides per prioritat: ronda ascendent → bracket → posició. */
function sortByPriority(matches: MatchToSchedule[]): MatchToSchedule[] {
	return [...matches].sort((a, b) => {
		if (a.ronda !== b.ronda) return a.ronda - b.ronda;
		const ba = BRACKET_ORDER[a.bracket_type] ?? 3;
		const bb = BRACKET_ORDER[b.bracket_type] ?? 3;
		if (ba !== bb) return ba - bb;
		return a.matchPos - b.matchPos;
	});
}

// ── Funció principal ──────────────────────────────────────────────────────────

/**
 * Calendaritza les partides respectant disponibilitats i recursos disponibles.
 *
 * Les partides es processen en ordre de prioritat (rondes baixes primer).
 * Els resultats es retornen en el mateix ordre de prioritat.
 *
 * @param input  Partides a programar, config del torneig, disponibilitats i slots ocupats.
 * @returns  Array de resultats: scheduled=true (amb data/hora/taula) o scheduled=false (amb motiu).
 */
export function scheduleMatches(input: ScheduleInput): ScheduleItemResult[] {
	const { matches, config, participants, occupiedSlots } = input;

	if (matches.length === 0) return [];

	// ── Mapes auxiliars ─────────────────────────────────────────────────────
	const availMap = new Map<string, ParticipantAvailability>(
		participants.map((p) => [p.participant_id, p])
	);

	// Slots externs ja ocupats (immutables)
	const occupiedSet = new Set<string>(
		occupiedSlots.map((s) => `${s.data}|${s.hora}|${s.taula}`)
	);

	// Slots usats en aquesta sessió de programació (mutable)
	const usedSlots = new Set<string>();

	// Dies on cada participant ja té una partida programada (mutable)
	const playerDayBusy = new Map<string, Set<string>>();

	// ── Helpers d'estat mutable ─────────────────────────────────────────────
	function isSlotFree(data: string, hora: string, taula: number): boolean {
		const key = `${data}|${hora}|${taula}`;
		return !occupiedSet.has(key) && !usedSlots.has(key);
	}

	function isPlayerFreeOnDay(participantId: string, data: string): boolean {
		return !(playerDayBusy.get(participantId)?.has(data) ?? false);
	}

	function reserveSlot(data: string, hora: string, taula: number) {
		usedSlots.add(`${data}|${hora}|${taula}`);
	}

	function markPlayerBusy(participantId: string, data: string) {
		if (!playerDayBusy.has(participantId)) playerDayBusy.set(participantId, new Set());
		playerDayBusy.get(participantId)!.add(data);
	}

	// ── Generar seqüència de slots del torneig ──────────────────────────────
	interface DaySlot {
		data: string;
		hora: string;
		dayCode: string;
	}

	const allSlots: DaySlot[] = [];
	const start = parseLocalDate(config.data_inici);
	const end = parseLocalDate(config.data_fi);
	const cur = new Date(start);

	while (cur <= end) {
		const dayCode = getWeekdayCode(cur);
		if (dayCode) {
			const data = formatDate(cur);
			// Hores del dia: primer les hores anteriors (17:00 si escau), després estàndard
			const hours: string[] = [];
			if (config.horaris_extra?.franja && config.horaris_extra.dies.includes(dayCode)) {
				hours.push(config.horaris_extra.franja);
			}
			hours.push(...STANDARD_HOURS);

			for (const hora of hours) {
				allSlots.push({ data, hora, dayCode });
			}
		}
		cur.setDate(cur.getDate() + 1);
	}

	// ── Programació ─────────────────────────────────────────────────────────
	const sorted = sortByPriority(matches);
	const results: ScheduleItemResult[] = [];

	for (const match of sorted) {
		const avail1 = availMap.get(match.player1_participant_id);
		const avail2 = availMap.get(match.player2_participant_id);

		if (!avail1 || !avail2) {
			const missing = !avail1 ? match.player1_participant_id : match.player2_participant_id;
			results.push({
				scheduled: false,
				match_id: match.id,
				motiu: `Disponibilitat no trobada per al participant ${missing}`
			});
			continue;
		}

		let found: ScheduleItemResult | null = null;

		outer: for (const slot of allSlots) {
			// Ambdós jugadors han d'estar disponibles en aquest dia+hora
			if (!isPlayerAvailable(avail1, slot.dayCode, slot.hora)) continue;
			if (!isPlayerAvailable(avail2, slot.dayCode, slot.hora)) continue;

			// Cap dels dos pot tenir ja una partida programada aquest dia
			if (!isPlayerFreeOnDay(match.player1_participant_id, slot.data)) continue;
			if (!isPlayerFreeOnDay(match.player2_participant_id, slot.data)) continue;

			// Trobar una taula lliure en aquest slot
			for (let t = 1; t <= NUM_TAULES; t++) {
				if (isSlotFree(slot.data, slot.hora, t)) {
					reserveSlot(slot.data, slot.hora, t);
					markPlayerBusy(match.player1_participant_id, slot.data);
					markPlayerBusy(match.player2_participant_id, slot.data);
					found = { scheduled: true, match_id: match.id, data: slot.data, hora: slot.hora, taula: t };
					break outer;
				}
			}
		}

		if (found) {
			results.push(found);
		} else {
			results.push({
				scheduled: false,
				match_id: match.id,
				motiu: buildConflictReason(match, avail1, avail2, allSlots, playerDayBusy)
			});
		}
	}

	return results;
}

/** Genera un missatge de motiu de conflicte llegible. */
function buildConflictReason(
	match: MatchToSchedule,
	avail1: ParticipantAvailability,
	avail2: ParticipantAvailability,
	allSlots: Array<{ data: string; hora: string; dayCode: string }>,
	playerDayBusy: Map<string, Set<string>>
): string {
	const bothOverlap = allSlots.some(
		(s) =>
			isPlayerAvailable(avail1, s.dayCode, s.hora) &&
			isPlayerAvailable(avail2, s.dayCode, s.hora)
	);

	if (!bothOverlap) {
		return 'Els dos jugadors no coincideixen en cap horari disponible';
	}

	const p1Free = allSlots.some(
		(s) =>
			isPlayerAvailable(avail1, s.dayCode, s.hora) &&
			!(playerDayBusy.get(match.player1_participant_id)?.has(s.data) ?? false)
	);
	const p2Free = allSlots.some(
		(s) =>
			isPlayerAvailable(avail2, s.dayCode, s.hora) &&
			!(playerDayBusy.get(match.player2_participant_id)?.has(s.data) ?? false)
	);

	if (!p1Free) return 'Jugador 1 no té cap dia lliure compatible';
	if (!p2Free) return 'Jugador 2 no té cap dia lliure compatible';
	return 'No queden slots (taula+dia) compatibles per a ambdós jugadors';
}
