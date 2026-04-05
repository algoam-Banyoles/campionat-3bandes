/** Tipus compartits per al bracket hàndicap */

// ── Utilitats de numeració de partides ───────────────────────────────────────

/**
 * Construeix un Map<matchId, codi> per a tots els matches.
 * Ordre: ronda ASC, matchPos ASC dins cada bracket.
 * Codis: W1…Wn, L1…Ln, F1 (Gran Final), F2 (Reset).
 */
export function buildMatchCodeMap(
	matches: ReadonlyArray<{ id: string; bracket_type: string; ronda: number; matchPos: number }>
): Map<string, string> {
	const sortFn = (a: { ronda: number; matchPos: number }, b: { ronda: number; matchPos: number }) =>
		a.ronda !== b.ronda ? a.ronda - b.ronda : a.matchPos - b.matchPos;

	const winners = matches.filter((m) => m.bracket_type === 'winners').slice().sort(sortFn);
	const losers  = matches.filter((m) => m.bracket_type === 'losers').slice().sort(sortFn);
	const gf      = matches.filter((m) => m.bracket_type === 'grand_final').slice().sort((a, b) => a.ronda - b.ronda);

	const map = new Map<string, string>();
	winners.forEach((m, i) => map.set(m.id, `W${i + 1}`));
	losers.forEach((m, i)  => map.set(m.id, `L${i + 1}`));
	gf.forEach((m, i)      => map.set(m.id, `F${i + 1}`));
	return map;
}

/**
 * Construeix un Map<matchId, loserDestCode | null> per als matches del bracket guanyadors.
 * - Winners: codi de la partida del bracket perdedors on va el perdedor (null si no en té)
 * - Losers: null (el perdedor és eliminat)
 * - Gran Final: no s'inclou al mapa
 */
export function buildLoserDestCodeMap(
	matches: ReadonlyArray<{
		id: string;
		bracket_type: string;
		slot1: { id: string };
		slot2: { id: string };
		loser_slot_dest_id: string | null;
	}>,
	codeMap: Map<string, string>
): Map<string, string | null> {
	const slotToMatch = new Map<string, string>();
	for (const m of matches) {
		slotToMatch.set(m.slot1.id, m.id);
		slotToMatch.set(m.slot2.id, m.id);
	}

	const result = new Map<string, string | null>();
	for (const m of matches) {
		if (m.bracket_type === 'winners') {
			const destId = m.loser_slot_dest_id ? slotToMatch.get(m.loser_slot_dest_id) : undefined;
			result.set(m.id, destId ? (codeMap.get(destId) ?? null) : null);
		} else if (m.bracket_type === 'losers') {
			result.set(m.id, null); // null = eliminat
		}
		// grand_final: no entry → check with has()
	}
	return result;
}

/**
 * Rol d'un slot pendent: rep el guanyador o perdedor d'un match anterior.
 */
export interface SlotSource {
	role: 'Guanyador' | 'Perdedor';
	code: string;
}

/**
 * Construeix un Map<slotId, SlotSource> per saber d'on ve cada slot pendent.
 * Per cada match, el winner_slot_dest_id rep "Guanyador <codi>"
 * i el loser_slot_dest_id rep "Perdedor <codi>".
 */
export function buildSlotSourceMap(
	matches: ReadonlyArray<{
		id: string;
		winner_slot_dest_id: string | null;
		loser_slot_dest_id: string | null;
	}>,
	codeMap: Map<string, string>
): Map<string, SlotSource> {
	const map = new Map<string, SlotSource>();
	for (const m of matches) {
		const code = codeMap.get(m.id);
		if (!code) continue;
		if (m.winner_slot_dest_id) map.set(m.winner_slot_dest_id, { role: 'Guanyador', code });
		if (m.loser_slot_dest_id)  map.set(m.loser_slot_dest_id,  { role: 'Perdedor',  code });
	}
	return map;
}

/** Entrada mínima per al càlcul d'equilibri de branques. */
export interface BranchMatchInput {
	bracket_type: string;
	ronda: number;
	matchPos: number;
	estat: string;
}

/** Partida programada per al calendari setmanal. */
export interface CalendarEntry {
	id: string;
	player1_name: string;
	player2_name: string;
	bracket_type: 'winners' | 'losers' | 'grand_final';
	ronda: number;
	estat: string;
	data_programada: string; // 'YYYY-MM-DD'
	hora_inici: string; // 'HH:MM'
	taula_assignada: number; // 1-3
}

export interface PlayerInfo {
	id: string;
	name: string;
	shortName?: string;
	distancia: number;
	seed: number | null;
}

export interface MatchView {
	id: string;
	bracket_type: 'winners' | 'losers' | 'grand_final';
	ronda: number;
	/** Posició 1-based dins la ronda */
	matchPos: number;
	estat: 'pendent' | 'programada' | 'jugada' | 'bye' | 'walkover';
	slot1: { id: string; participant_id: string | null; is_bye: boolean; posicio: number };
	slot2: { id: string; participant_id: string | null; is_bye: boolean; posicio: number };
	player1: PlayerInfo | null;
	player2: PlayerInfo | null;
	distancia_jugador1: number | null;
	distancia_jugador2: number | null;
	caramboles1: number | null;
	caramboles2: number | null;
	entrades: number | null;
	guanyador_participant_id: string | null;
	winner_slot_dest_id: string | null;
	loser_slot_dest_id: string | null;
	calendari_partida_id: string | null;
	data_hora?: string | null;
	taula?: string | null;
}
