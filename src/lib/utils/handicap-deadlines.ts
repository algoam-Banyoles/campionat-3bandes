/**
 * Càlcul de la **data màxima de disputa** per a cada match del bracket.
 *
 * Regla: per a un match m, la deadline és el dia anterior al primer
 * successor estructural (= el match que rep el winner o el loser de m).
 * Si m no té cap successor (final de bracket, final dels losers, GF),
 * la deadline és la data_fi del torneig.
 *
 * Aquest mòdul opera amb les dades carregades a la UI (handicap_matches +
 * calendari_partides). No fa cap consulta a Supabase.
 */

export interface DeadlineInput {
	id: string;
	slot1_id: string;
	slot2_id: string;
	winner_slot_dest_id: string | null;
	loser_slot_dest_id: string | null;
	/** 'YYYY-MM-DD' o ISO complet ('YYYY-MM-DDTHH:MM:SS+TZ'). Pot ser null
	 *  per a matches encara no programats (no els podem usar com a font de
	 *  deadline d'un predecessor). */
	data_programada?: string | null;
	/** Bracket i ronda del match. Necessari per calcular deadlines a nivell
	 *  de ronda (igual que el pre-scheduler): tots els matches d'una mateixa
	 *  ronda comparteixen la mateixa deadline = primer dia de la ronda que
	 *  els succeeix − 1. */
	bracket_type?: 'winners' | 'losers' | 'grand_final';
	ronda?: number;
}

export type DeadlineStatus = 'safe' | 'soon' | 'passed' | 'unknown';

function pad(n: number): string {
	return String(n).padStart(2, '0');
}

function toIsoDay(value: string | null | undefined): string | null {
	if (!value) return null;
	return value.substring(0, 10); // 'YYYY-MM-DD'
}

function addDays(iso: string, n: number): string {
	const d = new Date(iso + 'T12:00:00');
	d.setDate(d.getDate() + n);
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/**
 * Per cada match retorna la seva deadline ('YYYY-MM-DD'). Si no es pot
 * determinar (cap successor té data) i tampoc tenim `dataFi`, retorna null.
 *
 * Regla: la deadline es calcula a partir de la **data individual** de cada
 * successor (no el primer dia de la ronda). Per als matches de winners hi ha
 * dos successors (winner_slot_dest_id i loser_slot_dest_id); per als de
 * losers només n'hi ha un (el loser_slot_dest_id és null perquè el perdedor
 * queda eliminat). Es pren la data programada de la més primerenca de
 * les dues, menys 1 dia.
 */
export function computeDeadlines(
	matches: DeadlineInput[],
	dataFi?: string | null
): Map<string, string | null> {
	const matchBySlot = new Map<string, DeadlineInput>();
	for (const m of matches) {
		matchBySlot.set(m.slot1_id, m);
		matchBySlot.set(m.slot2_id, m);
	}

	const fallback = toIsoDay(dataFi);
	const result = new Map<string, string | null>();
	for (const m of matches) {
		// La Gran Final (i el seu reset GF2) tanquen el torneig: la seva data
		// màxima és la data_fi, NO la derivada del successor. El reset GF2 es
		// programa just després de GF1 (sovint el mateix dia o l'endemà), així
		// que usar la data de GF2 − 1 deixaria la màx de GF1 abans de la seva
		// pròpia data programada (incoherent).
		if (m.bracket_type === 'grand_final') {
			result.set(m.id, fallback);
			continue;
		}
		const succDates: string[] = [];
		for (const slotId of [m.winner_slot_dest_id, m.loser_slot_dest_id]) {
			if (!slotId) continue;
			const succ = matchBySlot.get(slotId);
			if (!succ) continue;
			const d = toIsoDay(succ.data_programada);
			if (d) succDates.push(d);
		}
		if (succDates.length === 0) {
			result.set(m.id, fallback);
			continue;
		}
		succDates.sort();
		result.set(m.id, addDays(succDates[0], -1));
	}
	return result;
}

/**
 * Classifica una deadline contra avui:
 *   - 'passed': la deadline ja ha passat (i el match no està jugat).
 *   - 'soon':   queden ≤ 3 dies (avís).
 *   - 'safe':   queden > 3 dies.
 *   - 'unknown': la deadline és null.
 */
export function deadlineStatus(
	deadlineIso: string | null | undefined,
	todayIso: string,
	estat?: string | null
): DeadlineStatus {
	if (!deadlineIso) return 'unknown';
	// Si el match ja està jugat, no hi ha urgència.
	if (estat === 'jugada' || estat === 'walkover' || estat === 'bye') return 'safe';
	if (deadlineIso < todayIso) return 'passed';
	const dl = new Date(deadlineIso + 'T12:00:00').getTime();
	const td = new Date(todayIso + 'T12:00:00').getTime();
	const days = Math.floor((dl - td) / (1000 * 60 * 60 * 24));
	if (days <= 3) return 'soon';
	return 'safe';
}

/** Format curt 'dd/mm' per a pills compactes. */
export function formatDeadlineShort(iso: string | null | undefined): string {
	if (!iso) return '—';
	const [y, m, d] = iso.split('-');
	if (!y || !m || !d) return iso;
	return `${d}/${m}`;
}

/** 'YYYY-MM-DD' d'avui en components LOCALS (consistent amb la resta del codi). */
export function todayLocalIso(): string {
	const d = new Date();
	return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
