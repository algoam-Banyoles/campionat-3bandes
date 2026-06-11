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
	// Filtres clau per minimitzar canvis al calendari pre-definit:
	//   - estat = 'pendent' (no toquem partides ja 'programada' ni 'jugada')
	//   - calendari_partida_id IS NULL (no creem un segon slot per a una
	//     partida que ja en té; preserva el que va fer el pre-scheduler)

	const { data: rawMatches } = await supabase
		.from('handicap_matches')
		.select('id, slot1_id, slot2_id')
		.eq('event_id', eventId)
		.eq('estat', 'pendent')
		.is('calendari_partida_id', null);

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

	// ── 5. Obtenir participants (disponibilitat + soci_numero) ──────────────────

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
		.select('id, soci_numero, preferencies_dies, preferencies_hores')
		.in('id', participantIds);

	const partMap = new Map((parts ?? []).map((p: any) => [p.id as string, p]));

	// ── 6. Obtenir slots ocupats dins el període ──────────────────────────────
	// Incloem l'`id` de cada partida per poder mapar-la als participants
	// hàndicap corresponents (necessari per al seeding de playerDayBusy
	// inter-batch al scheduler).

	const { data: allPartides } = await supabase
		.from('calendari_partides')
		.select('id, data_programada, hora_inici, taula_assignada')
		.gte('data_programada', `${config.data_inici}T00:00:00`)
		.lte('data_programada', `${config.data_fi}T23:59:59`)
		.not('data_programada', 'is', null)
		.not('taula_assignada', 'is', null);

	// Construir mapa calendari_partida_id → [participant_id] per als matches
	// hàndicap ja programats (les partides socials no en tindran).
	const { data: existingMatches } = await supabase
		.from('handicap_matches')
		.select('calendari_partida_id, slot1_id, slot2_id')
		.eq('event_id', eventId)
		.not('calendari_partida_id', 'is', null);

	// Necessitem els participant_id de tots els slots ja programats.
	const existingSlotIds = (existingMatches ?? []).flatMap((m: any) => [
		m.slot1_id as string,
		m.slot2_id as string
	]);
	let existingSlotPidMap = new Map<string, string | null>();
	if (existingSlotIds.length > 0) {
		const { data: existingSlots } = await supabase
			.from('handicap_bracket_slots')
			.select('id, participant_id')
			.in('id', existingSlotIds);
		existingSlotPidMap = new Map(
			(existingSlots ?? []).map((s: any) => [s.id as string, s.participant_id as string | null])
		);
	}

	const participantsByPartidaId = new Map<string, string[]>();
	for (const m of existingMatches ?? []) {
		if (!m.calendari_partida_id) continue;
		const pid1 = existingSlotPidMap.get(m.slot1_id as string);
		const pid2 = existingSlotPidMap.get(m.slot2_id as string);
		const ids: string[] = [];
		if (pid1) ids.push(pid1);
		if (pid2) ids.push(pid2);
		if (ids.length > 0) participantsByPartidaId.set(m.calendari_partida_id as string, ids);
	}

	const occupiedSlots = (allPartides ?? []).map((p: any) => ({
		data: (p.data_programada as string).substring(0, 10),
		hora: (p.hora_inici as string).substring(0, 5),
		taula: p.taula_assignada as number,
		participantIds: participantsByPartidaId.get(p.id as string) ?? []
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
				player1_soci_numero: p1.soci_numero as number,
				player2_soci_numero: p2.soci_numero as number
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

/**
 * Promou les partides pendents que ja tenen un slot de calendari reservat
 * (pre-scheduler) i que acaben de quedar amb ambdós jugadors assignats.
 *
 * `autoScheduleReadyMatches` ignora deliberadament aquestes partides
 * (`calendari_partida_id IS NOT NULL`) per no duplicar slots. Però quan la
 * propagació d'un resultat omple el participant que faltava, ningú escrivia
 * els `soci_numero` a la partida reservada ni passava l'estat a 'programada',
 * de manera que es quedaven invisibles a "Pròximes partides" i al widget de
 * properes partides del soci (que filtra per `jugadorX_soci_numero`).
 *
 * Aquesta funció tanca aquest forat: omple els jugadors a la partida reservada
 * i marca el match com a 'programada'. Idempotent.
 *
 * @returns nombre de partides promogudes.
 */
export async function promoteReservedReadyMatches(
	supabase: SupabaseClient,
	eventId: string
): Promise<number> {
	const { data: rawMatches } = await supabase
		.from('handicap_matches')
		.select('id, slot1_id, slot2_id, calendari_partida_id')
		.eq('event_id', eventId)
		.eq('estat', 'pendent')
		.not('calendari_partida_id', 'is', null);

	if (!rawMatches || rawMatches.length === 0) return 0;

	const slotIds = rawMatches.flatMap((m: any) => [m.slot1_id as string, m.slot2_id as string]);
	const { data: slots } = await supabase
		.from('handicap_bracket_slots')
		.select('id, is_bye, participant_id')
		.in('id', slotIds);

	if (!slots) return 0;
	const slotMap = new Map((slots as any[]).map((s) => [s.id as string, s]));

	const ready = rawMatches.filter((m: any) => {
		const s1 = slotMap.get(m.slot1_id as string);
		const s2 = slotMap.get(m.slot2_id as string);
		return s1 && s2 && !s1.is_bye && !s2.is_bye && s1.participant_id && s2.participant_id;
	});

	if (ready.length === 0) return 0;

	const pids = [
		...new Set(
			ready.flatMap((m: any) => [
				slotMap.get(m.slot1_id as string)!.participant_id as string,
				slotMap.get(m.slot2_id as string)!.participant_id as string
			])
		)
	];

	const { data: partsRows } = await supabase
		.from('handicap_participants')
		.select('id, soci_numero')
		.in('id', pids);

	const sociById = new Map((partsRows ?? []).map((p: any) => [p.id as string, p.soci_numero as number]));

	let promoted = 0;
	for (const m of ready) {
		const s1 = slotMap.get(m.slot1_id as string)!;
		const s2 = slotMap.get(m.slot2_id as string)!;
		const soci1 = sociById.get(s1.participant_id as string);
		const soci2 = sociById.get(s2.participant_id as string);
		if (soci1 == null || soci2 == null) continue;

		// Omplir els jugadors a la partida reservada (slot1 → jugador1, slot2 → jugador2)
		const { error: cpErr } = await supabase
			.from('calendari_partides')
			.update({ jugador1_soci_numero: soci1, jugador2_soci_numero: soci2 })
			.eq('id', m.calendari_partida_id as string);
		if (cpErr) continue;

		const { error: hmErr } = await supabase
			.from('handicap_matches')
			.update({ estat: 'programada' })
			.eq('id', m.id as string);
		if (hmErr) continue;

		promoted++;
	}

	return promoted;
}
