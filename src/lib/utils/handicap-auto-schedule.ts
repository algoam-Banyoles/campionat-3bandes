/**
 * Calendarització automàtica de partides llestes del torneig hàndicap.
 *
 * S'executa després de cada propagació de resultat (o generació de bracket)
 * per programar immediatament les partides on ambdós jugadors ja estan assignats.
 *
 * Retorna null si no hi ha configuració de dates vàlida (config absent o dates buides).
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import { scheduleMatches, type MatchToSchedule, type ParticipantAvailability, type TournamentConfig } from './handicap-scheduler';
import { executeScheduling, type SchedulingExecutionResult } from './handicap-scheduler-db';

/**
 * Cerca totes les partides pendents amb ambdós jugadors assignats i les programa.
 *
 * @returns SchedulingExecutionResult si s'ha intentat programar alguna cosa, null si no hi ha config o partides.
 */
export async function autoScheduleReadyMatches(
	supabase: SupabaseClient,
	eventId: string
): Promise<SchedulingExecutionResult | null> {
	// ── 1. Obtenir config (dates + horaris_extra) ─────────────────────────────

	const [{ data: ev }, { data: cfg }] = await Promise.all([
		supabase
			.from('events')
			.select('data_inici, data_fi')
			.eq('id', eventId)
			.single(),
		supabase
			.from('handicap_config')
			.select('horaris_extra')
			.eq('event_id', eventId)
			.maybeSingle()
	]);

	if (!ev?.data_inici || !ev?.data_fi) return null;

	const config: TournamentConfig = {
		data_inici: ev.data_inici as string,
		data_fi: ev.data_fi as string,
		horaris_extra: (cfg as any)?.horaris_extra ?? undefined
	};

	// ── 2. Obtenir partides pendents (no bye) ─────────────────────────────────

	const { data: rawMatches } = await supabase
		.from('handicap_matches')
		.select('id, slot1_id, slot2_id')
		.eq('event_id', eventId)
		.eq('estat', 'pendent');

	if (!rawMatches || rawMatches.length === 0) return null;

	// ── 3. Obtenir slots ──────────────────────────────────────────────────────

	const slotIds = rawMatches.flatMap((m: any) => [m.slot1_id as string, m.slot2_id as string]);
	const { data: slots } = await supabase
		.from('handicap_bracket_slots')
		.select('id, bracket_type, ronda, posicio, is_bye, participant_id')
		.in('id', slotIds);

	if (!slots) return null;
	const slotMap = new Map((slots as any[]).map((s) => [s.id as string, s]));

	// ── 4. Filtrar partides on ambdós jugadors estan assignats ────────────────

	const ready = rawMatches.filter((m: any) => {
		const s1 = slotMap.get(m.slot1_id as string);
		const s2 = slotMap.get(m.slot2_id as string);
		return (
			s1 && s2 &&
			!s1.is_bye && !s2.is_bye &&
			s1.participant_id && s2.participant_id
		);
	});

	if (ready.length === 0) return null;

	// ── 5. Obtenir participants (disponibilitat + player_id) ──────────────────

	const participantIds = [
		...new Set(
			ready.flatMap((m: any) => {
				const s1 = slotMap.get(m.slot1_id as string);
				const s2 = slotMap.get(m.slot2_id as string);
				return [s1!.participant_id as string, s2!.participant_id as string];
			})
		)
	];

	const { data: parts } = await supabase
		.from('handicap_participants')
		.select('id, player_id, preferencies_dies, preferencies_hores')
		.in('id', participantIds);

	const partMap = new Map((parts ?? []).map((p: any) => [p.id as string, p]));

	// ── 6. Obtenir slots ocupats dins el període ──────────────────────────────

	const { data: allPartides } = await supabase
		.from('calendari_partides')
		.select('data_programada, hora_inici, taula_assignada')
		.gte('data_programada', `${config.data_inici}T00:00:00`)
		.lte('data_programada', `${config.data_fi}T23:59:59`)
		.not('data_programada', 'is', null)
		.not('taula_assignada', 'is', null);

	const occupiedSlots = (allPartides ?? []).map((p: any) => ({
		data: (p.data_programada as string).substring(0, 10),
		hora: (p.hora_inici as string).substring(0, 5),
		taula: p.taula_assignada as number
	}));

	// ── 7. Construir MatchToSchedule[] ───────────────────────────────────────

	const matchesInput: MatchToSchedule[] = ready
		.map((m: any) => {
			const s1 = slotMap.get(m.slot1_id as string)!;
			const s2 = slotMap.get(m.slot2_id as string)!;
			const pid1 = s1.participant_id as string;
			const pid2 = s2.participant_id as string;
			const p1 = partMap.get(pid1);
			const p2 = partMap.get(pid2);
			if (!p1 || !p2) return null;
			return {
				id: m.id as string,
				bracket_type: s1.bracket_type as 'winners' | 'losers' | 'grand_final',
				ronda: s1.ronda as number,
				matchPos: Math.ceil((s1.posicio as number) / 2),
				player1_participant_id: pid1,
				player2_participant_id: pid2,
				player1_player_id: p1.player_id as string,
				player2_player_id: p2.player_id as string
			} satisfies MatchToSchedule;
		})
		.filter(Boolean) as MatchToSchedule[];

	if (matchesInput.length === 0) return null;

	// ── 8. Disponibilitat dels participants ───────────────────────────────────

	const participants: ParticipantAvailability[] = participantIds.map((id) => {
		const p = partMap.get(id);
		return p
			? { participant_id: id, preferencies_dies: p.preferencies_dies ?? [], preferencies_hores: p.preferencies_hores ?? [] }
			: { participant_id: id, preferencies_dies: [], preferencies_hores: [] };
	});

	// ── 9. Executar l'algorisme i persistir ───────────────────────────────────

	const scheduleResults = scheduleMatches({ matches: matchesInput, config, participants, occupiedSlots });
	return executeScheduling(supabase, eventId, matchesInput, scheduleResults);
}
