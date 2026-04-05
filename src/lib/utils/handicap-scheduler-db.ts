/**
 * Capa de BD per a la calendarització automàtica del torneig hàndicap.
 *
 * Executa els resultats de `scheduleMatches` contra Supabase:
 *  1. INSERT a calendari_partides per a cada partida programada
 *  2. UPDATE handicap_matches: calendari_partida_id + estat='programada'
 *
 * Nota: Supabase PostgREST no suporta transaccions multi-sentència via JS.
 * Cada operació és independent. Si un UPDATE falla després d'un INSERT,
 * es pot produir un registre orfe a calendari_partides (recuperable manualment).
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import type { MatchToSchedule, ScheduleItemResult } from './handicap-scheduler';

export interface SchedulingExecutionResult {
	scheduled: number;
	conflicts: number;
	conflictDetails: Array<{ match_id: string; motiu: string }>;
	errors: string[];
	scheduledDetails: Array<{ match_id: string; data: string; hora: string; taula: number }>;
}

/**
 * Executa la calendarització: insereix a calendari_partides i actualitza handicap_matches.
 *
 * @param supabase      Client de Supabase
 * @param eventId       UUID de l'event hàndicap
 * @param matchesInput  Llista de partides amb player_ids (per a l'insert a calendari_partides)
 * @param results       Resultats de scheduleMatches()
 */
export async function executeScheduling(
	supabase: SupabaseClient,
	eventId: string,
	matchesInput: MatchToSchedule[],
	results: ScheduleItemResult[]
): Promise<SchedulingExecutionResult> {
	const matchById = new Map(matchesInput.map((m) => [m.id, m]));

	const conflictDetails: Array<{ match_id: string; motiu: string }> = [];
	const scheduledDetails: Array<{ match_id: string; data: string; hora: string; taula: number }> = [];
	const errors: string[] = [];
	let scheduledCount = 0;

	for (const result of results) {
		if (result.scheduled) {
			// ── Partida programada: INSERT calendari_partides + UPDATE handicap_matches ──
			const match = matchById.get(result.match_id);
			if (!match) {
				errors.push(`Match ${result.match_id} no trobat a la llista d'entrada`);
				continue;
			}

			// 1. INSERT a calendari_partides
			// categoria_id és NULL per a partides hàndicap (migració 20260318000000)
			const { data: newPartida, error: insertErr } = await supabase
				.from('calendari_partides')
				.insert({
					event_id: eventId,
					categoria_id: null,
					jugador1_id: match.player1_player_id,
					jugador2_id: match.player2_player_id,
					data_programada: `${result.data}T${result.hora}:00`,
					hora_inici: result.hora,
					taula_assignada: result.taula,
					estat: 'generat'
				})
				.select('id')
				.single();

			if (insertErr || !newPartida) {
				errors.push(
					`Error inserint calendari_partida per match ${result.match_id}: ${insertErr?.message ?? 'ID no retornat'}`
				);
				continue;
			}

			// 2. UPDATE handicap_matches
			const { error: updateErr } = await supabase
				.from('handicap_matches')
				.update({
					calendari_partida_id: newPartida.id,
					estat: 'programada'
				})
				.eq('id', result.match_id);

			if (updateErr) {
				errors.push(
					`Error actualitzant handicap_match ${result.match_id}: ${updateErr.message}`
				);
				// calendari_partida ja inserida però match no actualitzat → estat inconsistent
				// L'admin pot recuperar-ho reassignant manualment
				continue;
			}

			scheduledDetails.push({ match_id: result.match_id, data: result.data, hora: result.hora, taula: result.taula });
			scheduledCount++;
		} else {
			// ── Conflicte: registrar el motiu ──
			// Type assertion: en el bloc else, result és { scheduled: false; motiu: string }
			const conflict = result as Extract<ScheduleItemResult, { scheduled: false }>;
			conflictDetails.push({ match_id: conflict.match_id, motiu: conflict.motiu });
		}
	}

	return {
		scheduled: scheduledCount,
		conflicts: conflictDetails.length,
		conflictDetails,
		errors,
		scheduledDetails
	};
}
