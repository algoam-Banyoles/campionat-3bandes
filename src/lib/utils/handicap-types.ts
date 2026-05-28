/** Tipus compartits per al bracket hàndicap */

// ── Utilitats de numeració de partides ───────────────────────────────────────

/**
 * Construeix un Map<matchId, codi> per a tots els matches.
 * Format: W<ronda>.<n>, L<ronda>.<n>, GF<r>. Idèntic a la nomenclatura
 * que es genera als modals d'impressió de bracket i calendari.
 */
export function buildMatchCodeMap(
	matches: ReadonlyArray<{ id: string; bracket_type: string; ronda: number; matchPos: number }>
): Map<string, string> {
	const winnersByRonda = new Map<number, Array<{ id: string; matchPos: number }>>();
	const losersByRonda = new Map<number, Array<{ id: string; matchPos: number }>>();
	const gf: Array<{ id: string; ronda: number }> = [];

	for (const m of matches) {
		if (m.bracket_type === 'winners') {
			if (!winnersByRonda.has(m.ronda)) winnersByRonda.set(m.ronda, []);
			winnersByRonda.get(m.ronda)!.push({ id: m.id, matchPos: m.matchPos });
		} else if (m.bracket_type === 'losers') {
			if (!losersByRonda.has(m.ronda)) losersByRonda.set(m.ronda, []);
			losersByRonda.get(m.ronda)!.push({ id: m.id, matchPos: m.matchPos });
		} else if (m.bracket_type === 'grand_final') {
			gf.push({ id: m.id, ronda: m.ronda });
		}
	}

	const map = new Map<string, string>();
	for (const [ronda, ms] of winnersByRonda) {
		ms.sort((a, b) => a.matchPos - b.matchPos);
		ms.forEach((m, i) => map.set(m.id, `W${ronda}.${i + 1}`));
	}
	for (const [ronda, ms] of losersByRonda) {
		ms.sort((a, b) => a.matchPos - b.matchPos);
		ms.forEach((m, i) => map.set(m.id, `L${ronda}.${i + 1}`));
	}
	gf.sort((a, b) => a.ronda - b.ronda);
	gf.forEach((m) => map.set(m.id, `GF${m.ronda}`));
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
	/** 'YYYY-MM-DD' — opcional. Veure MatchView.dataMaximaDisputa. */
	dataMaximaDisputa?: string | null;
	/** Codi del match (W1.1, L2.3, GF1) — opcional. Usat per la vista graella. */
	matchCode?: string;
	/** Codi del match destí del guanyador — opcional. */
	winnerDest?: string;
	/** Codi del match destí del perdedor — opcional. */
	loserDest?: string;
	/** true si tots dos jugadors ja estan determinats. Si és false, la
	 *  data programada és orientativa i s'ha de confirmar quan els
	 *  jugadors es resolguin. */
	playersResolved?: boolean;
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
	/** 'YYYY-MM-DD' — data límit per disputar la partida (un dia abans del
	 *  primer successor). Es calcula a la pàgina amb `computeDeadlines()`. */
	dataMaximaDisputa?: string | null;
}
