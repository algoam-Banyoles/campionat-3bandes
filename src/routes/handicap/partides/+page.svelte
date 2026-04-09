<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { isAdmin } from '$lib/stores/adminAuth';
	import { user } from '$lib/stores/auth';
	import HandicapSlotPicker from '$lib/components/handicap/HandicapSlotPicker.svelte';
	import HandicapBranchBalance from '$lib/components/handicap/HandicapBranchBalance.svelte';
	import HandicapWeeklyCalendar from '$lib/components/handicap/HandicapWeeklyCalendar.svelte';
	import HandicapMatchResult from '$lib/components/handicap/HandicapMatchResult.svelte';
	import type { CalendarEntry, BranchMatchInput } from '$lib/utils/handicap-types';
	import { buildMatchCodeMap, buildSlotSourceMap } from '$lib/utils/handicap-types';
	import { saveMatchResult, type SaveResultError } from '$lib/utils/handicap-propagation';
	import {
		scheduleMatches,
		type MatchToSchedule,
		type ParticipantAvailability,
		type TournamentConfig,
		type OccupiedSlot,
		type ScheduleItemResult
	} from '$lib/utils/handicap-scheduler';
	import { executeScheduling } from '$lib/utils/handicap-scheduler-db';

	// ── Tipus locals ──────────────────────────────────────────────────────────

	interface MatchDisplay {
		id: string;
		bracket_type: 'winners' | 'losers' | 'grand_final';
		ronda: number;
		matchPos: number;
		matchCode: string;
		estat: string;
		player1_name: string;
		player2_name: string;
		player1_distancia: number | null;
		player2_distancia: number | null;
		player1_participant_id: string | null;
		player2_participant_id: string | null;
		player1_soci_numero: number | null;
		player2_soci_numero: number | null;
		calendari_partida_id: string | null;
		data_programada: string | null; // 'YYYY-MM-DD'
		hora_inici: string | null; // 'HH:MM'
		taula_assignada: number | null;
	}

	// ── Estat ─────────────────────────────────────────────────────────────────

	let loading = true;
	let saving = false;
	let error: string | null = null;

	let eventId: string | null = null;
	let config: TournamentConfig | null = null;
	let sistemaPuntuacio: string = 'distancia';
	let limitEntrades: number | null = null;
	let matches: MatchDisplay[] = [];
	let participantMap = new Map<string, ParticipantAvailability>();
	let allOccupiedSlots: OccupiedSlot[] = []; // tots els slots ocupats del torneig

	// ── Estat del torneig ─────────────────────────────────────────────────────

	let estatCompeticio: string = 'en_curs';
	$: isFinalitzat = estatCompeticio === 'finalitzat';

	// ── Modal de resultat ──────────────────────────────────────────────────────

	let resultMatchId: string | null = null;
	$: resultMatch = resultMatchId ? matches.find((m) => m.id === resultMatchId) ?? null : null;
	let resultSaving = false;
	let resultConfirmation: string | null = null;

	// ── Filtres ───────────────────────────────────────────────────────────────

	let filterEstat: 'all' | 'pendent' | 'programada' | 'jugada' = 'all';
	let filterBracket: 'all' | 'winners' | 'losers' | 'grand_final' = 'all';
	let filterRonda: 'all' | number = 'all';
	let searchTerm = '';

	$: availableRounds = [...new Set(matches.map((m) => m.ronda))].sort((a, b) => a - b);

	$: filteredMatches = matches.filter((m) => {
		if (filterEstat !== 'all' && m.estat !== filterEstat) return false;
		if (filterBracket !== 'all' && m.bracket_type !== filterBracket) return false;
		if (filterRonda !== 'all' && m.ronda !== filterRonda) return false;
		if (searchTerm.trim()) {
			const term = searchTerm.toLowerCase();
			if (
				!m.player1_name.toLowerCase().includes(term) &&
				!m.player2_name.toLowerCase().includes(term)
			)
				return false;
		}
		return true;
	});

	$: stats = {
		total: matches.length,
		pending: matches.filter((m) => m.estat === 'pendent').length,
		scheduled: matches.filter((m) => m.estat === 'programada').length,
		played: matches.filter((m) => m.estat === 'jugada' || m.estat === 'walkover').length
	};

	// ── Pestanya activa ───────────────────────────────────────────────────────

	let activeTab: 'list' | 'calendar' | 'mine' = 'list';

	// ── Participant actual ────────────────────────────────────────────────────

	let myParticipantId: string | null = null;

	$: myMatches = myParticipantId
		? matches.filter((m) => m.player1_participant_id === myParticipantId || m.player2_participant_id === myParticipantId)
		: [];

	// ── Partides llestes per programar ────────────────────────────────────────

	/** Pendents amb ambdós jugadors ja assignats → programables de seguida. */
	$: schedulableNow = matches.filter(
		(m) =>
			m.estat === 'pendent' &&
			m.player1_participant_id !== null &&
			m.player2_participant_id !== null
	);

	// ── Dades per a components fills ──────────────────────────────────────────

	$: branchMatches = matches.map((m) => ({
		bracket_type: m.bracket_type,
		ronda: m.ronda,
		matchPos: m.matchPos,
		estat: m.estat
	})) as BranchMatchInput[];

	$: calendarEntries = matches
		.filter((m) => m.data_programada && m.hora_inici && m.taula_assignada)
		.map((m) => ({
			id: m.id,
			player1_name: m.player1_name,
			player2_name: m.player2_name,
			bracket_type: m.bracket_type,
			ronda: m.ronda,
			estat: m.estat,
			data_programada: m.data_programada!,
			hora_inici: m.hora_inici!,
			taula_assignada: m.taula_assignada!
		})) as CalendarEntry[];

	// ── Programació manual ────────────────────────────────────────────────────

	/** ID del match que s'està programant manualment */
	let schedulingMatchId: string | null = null;
	$: schedulingMatch = schedulingMatchId ? matches.find((m) => m.id === schedulingMatchId) ?? null : null;
	$: slotPickerAvail1 = schedulingMatch?.player1_participant_id
		? (participantMap.get(schedulingMatch.player1_participant_id) as ParticipantAvailability)
		: null;
	$: slotPickerAvail2 = schedulingMatch?.player2_participant_id
		? (participantMap.get(schedulingMatch.player2_participant_id) as ParticipantAvailability)
		: null;
	$: currentSlot =
		schedulingMatch?.data_programada && schedulingMatch?.hora_inici && schedulingMatch?.taula_assignada
			? {
					data: schedulingMatch.data_programada,
					hora: schedulingMatch.hora_inici,
					taula: schedulingMatch.taula_assignada
				}
			: null;

	// ── Auto-programació ──────────────────────────────────────────────────────

	let showAutoSchedule = false;
	let autoSchedulePreview: ScheduleItemResult[] = [];
	let autoScheduleMatchesInput: MatchToSchedule[] = [];
	let autoScheduleRunning = false;
	let autoScheduleConfirming = false;

	// ── Helpers ───────────────────────────────────────────────────────────────

	const BRACKET_LABELS: Record<string, string> = {
		winners: 'W',
		losers: 'L',
		grand_final: 'GF'
	};
	const BRACKET_COLORS: Record<string, string> = {
		winners: 'bg-blue-100 text-blue-700',
		losers: 'bg-orange-100 text-orange-700',
		grand_final: 'bg-purple-100 text-purple-700'
	};
	const ESTAT_LABELS: Record<string, string> = {
		pendent: 'Pendent',
		programada: 'Programada',
		jugada: 'Jugada',
		walkover: 'W.O.',
		bye: 'Bye'
	};
	const ESTAT_COLORS: Record<string, string> = {
		pendent: 'bg-gray-100 text-gray-600',
		programada: 'bg-blue-100 text-blue-700',
		jugada: 'bg-green-100 text-green-700',
		walkover: 'bg-amber-100 text-amber-700'
	};

	function formatDataHora(data: string | null, hora: string | null, taula: number | null): string {
		if (!data || !hora) return '—';
		const d = new Date(data + 'T12:00:00');
		const day = d.getDate().toString().padStart(2, '0');
		const month = (d.getMonth() + 1).toString().padStart(2, '0');
		return `${day}/${month} ${hora}${taula ? ` T${taula}` : ''}`;
	}

	// ── Càrrega de dades ──────────────────────────────────────────────────────

	async function loadData() {
		if (!eventId) return;

		// 1. Partides (no bye) — bracket_type i ronda NO existeixen a handicap_matches,
		//    provenen de handicap_bracket_slots via slot1_id
		const { data: rawMatches, error: mErr } = await supabase
			.from('handicap_matches')
			.select(
				'id, estat, distancia_jugador1, distancia_jugador2, calendari_partida_id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id'
			)
			.eq('event_id', eventId)
			;

		if (mErr || !rawMatches) {
			error = mErr?.message ?? 'Error carregant partides';
			return;
		}

		// 2. Slots — inclou bracket_type i ronda (camp de handicap_bracket_slots)
		const slotIds = rawMatches.flatMap((m) => [m.slot1_id, m.slot2_id]);
		const { data: slots } = await supabase
			.from('handicap_bracket_slots')
			.select('id, bracket_type, ronda, posicio, is_bye, participant_id')
			.in('id', slotIds);

		const slotMap = new Map((slots ?? []).map((s: any) => [s.id, s]));

		// 3. Participants
		const participantIds = [
			...new Set(
				(slots ?? [])
					.filter((s: any) => s.participant_id)
					.map((s: any) => s.participant_id as string)
			)
		];

		let partMap = new Map<string, any>();
		if (participantIds.length > 0) {
			// Fase 5c-S3: nom via FK directe `soci_numero → socis`.
			// La columna `player_id` ja no existeix.
			const { data: parts } = await supabase
				.from('handicap_participants')
				.select(
					'id, distancia, seed, soci_numero, preferencies_dies, preferencies_hores, socis!handicap_participants_soci_numero_fkey(nom, cognoms)'
				)
				.in('id', participantIds);

			partMap = new Map((parts ?? []).map((p: any) => [p.id, p]));

			// Actualitzar participantMap (per SlotPicker i scheduler)
			participantMap = new Map(
				(parts ?? []).map((p: any) => [
					p.id,
					{
						participant_id: p.id,
						preferencies_dies: p.preferencies_dies ?? [],
						preferencies_hores: p.preferencies_hores ?? []
					}
				])
			);
		}

		// 4. Calendari_partides programades
		const scheduledIds = rawMatches
			.filter((m) => m.calendari_partida_id)
			.map((m) => m.calendari_partida_id as string);

		let partidaMap = new Map<string, any>();
		if (scheduledIds.length > 0) {
			const { data: partides } = await supabase
				.from('calendari_partides')
				.select('id, data_programada, hora_inici, taula_assignada')
				.in('id', scheduledIds);
			partidaMap = new Map((partides ?? []).map((p: any) => [p.id, p]));
		}

		// 5. Tots els slots ocupats (per SlotPicker i scheduler)
		if (config) {
			const { data: allPartides } = await supabase
				.from('calendari_partides')
				.select('data_programada, hora_inici, taula_assignada')
				.gte('data_programada', `${config.data_inici}T00:00:00`)
				.lte('data_programada', `${config.data_fi}T23:59:59`)
				.not('data_programada', 'is', null)
				.not('taula_assignada', 'is', null);

			allOccupiedSlots = (allPartides ?? []).map((p: any) => ({
				data: (p.data_programada as string).substring(0, 10),
				hora: (p.hora_inici as string).substring(0, 5),
				taula: p.taula_assignada as number
			}));
		}

		// 6. Construir MatchDisplay[] — bracket_type i ronda vénen de slot1
		const BRACKET_ORDER_MAP: Record<string, number> = { winners: 0, losers: 1, grand_final: 2 };
		// Calcular codis de partida (necessita totes les partides, incloent byes)
		const codeInputs = rawMatches.map((m) => {
			const s1 = slotMap.get(m.slot1_id);
			return { id: m.id, bracket_type: (s1?.bracket_type ?? 'winners') as string, ronda: (s1?.ronda ?? 1) as number, matchPos: s1 ? Math.ceil((s1.posicio as number) / 2) : 0 };
		});
		const codeMap = buildMatchCodeMap(codeInputs);
		const slotSourceMap = buildSlotSourceMap(rawMatches, codeMap);
		matches = rawMatches
			.map((m) => {
			const slot1 = slotMap.get(m.slot1_id);
			const slot2 = slotMap.get(m.slot2_id);
			const p1 = slot1?.participant_id ? partMap.get(slot1.participant_id) : null;
			const p2 = slot2?.participant_id ? partMap.get(slot2.participant_id) : null;
			const partida = m.calendari_partida_id ? partidaMap.get(m.calendari_partida_id) : null;
			const matchPos = slot1 ? Math.ceil((slot1.posicio as number) / 2) : 0;

			return {
				id: m.id,
				bracket_type: (slot1?.bracket_type ?? 'winners') as MatchDisplay['bracket_type'],
				ronda: (slot1?.ronda ?? 1) as number,
				matchPos,
				estat: m.estat,
				player1_name: p1
					? (() => { const r = p1.socis; const s = Array.isArray(r) ? r[0] : r; return s ? `${s.nom ?? ''} ${s.cognoms ?? ''}`.trim() : '?'; })()
					: (() => { const s = slotSourceMap.get(m.slot1_id); return s ? `${s.role} ${s.code}` : 'Per determinar'; })(),
				player2_name: p2
					? (() => { const r = p2.socis; const s = Array.isArray(r) ? r[0] : r; return s ? `${s.nom ?? ''} ${s.cognoms ?? ''}`.trim() : '?'; })()
					: (() => { const s = slotSourceMap.get(m.slot2_id); return s ? `${s.role} ${s.code}` : 'Per determinar'; })(),
				player1_distancia: p1?.distancia ?? m.distancia_jugador1 ?? null,
				player2_distancia: p2?.distancia ?? m.distancia_jugador2 ?? null,
				player1_participant_id: slot1?.participant_id ?? null,
				player2_participant_id: slot2?.participant_id ?? null,
				player1_soci_numero: p1?.soci_numero ?? null,
				player2_soci_numero: p2?.soci_numero ?? null,
				calendari_partida_id: m.calendari_partida_id ?? null,
				data_programada: partida
					? (partida.data_programada as string).substring(0, 10)
					: null,
				hora_inici: partida ? (partida.hora_inici as string).substring(0, 5) : null,
				taula_assignada: partida?.taula_assignada ?? null,
				matchCode: codeMap.get(m.id) ?? ''
			} satisfies MatchDisplay;
		})
		.filter((m) => m.estat !== 'bye')
		.sort((a, b) => {
			if (a.ronda !== b.ronda) return a.ronda - b.ronda;
			const ba = BRACKET_ORDER_MAP[a.bracket_type] ?? 3;
			const bb = BRACKET_ORDER_MAP[b.bracket_type] ?? 3;
			if (ba !== bb) return ba - bb;
			return a.matchPos - b.matchPos;
		});

		// Detectar si l'usuari es participant
		const userEmail = $user?.email;
		if (userEmail && !myParticipantId && eventId) {
			const { data: soci } = await supabase.from('socis').select('numero_soci').eq('email', userEmail).maybeSingle();
			if (soci) {
				const { data: part } = await supabase.from('handicap_participants').select('id').eq('event_id', eventId).eq('soci_numero', soci.numero_soci).maybeSingle();
				myParticipantId = part?.id ?? null;
			}
		}
	}

	// ── Programació manual ────────────────────────────────────────────────────

	async function manualSchedule(slot: { data: string; hora: string; taula: number }) {
		const match = schedulingMatch;
		if (!match || !config || saving) return;
		saving = true;
		error = null;

		try {
			// Si ja tenia una partida programada, esborrar-la primer
			if (match.calendari_partida_id) {
				const { error: delErr } = await supabase
					.from('calendari_partides')
					.delete()
					.eq('id', match.calendari_partida_id);
				if (delErr) throw new Error(`Error esborrant slot anterior: ${delErr.message}`);
			}

			// Inserir nova partida a calendari
			const { data: newPartida, error: insertErr } = await supabase
				.from('calendari_partides')
				.insert({
					event_id: eventId,
					categoria_id: null,
					jugador1_soci_numero: match.player1_soci_numero,
					jugador2_soci_numero: match.player2_soci_numero,
					data_programada: `${slot.data}T${slot.hora}:00`,
					hora_inici: slot.hora,
					taula_assignada: slot.taula,
					estat: 'generat'
				})
				.select('id')
				.single();

			if (insertErr || !newPartida) {
				throw new Error(insertErr?.message ?? 'Error creant la partida al calendari');
			}

			// Actualitzar handicap_match
			const { error: updateErr } = await supabase
				.from('handicap_matches')
				.update({ calendari_partida_id: newPartida.id, estat: 'programada' })
				.eq('id', match.id);

			if (updateErr) throw new Error(updateErr.message);

			schedulingMatchId = null;
			await loadData();
		} catch (e: any) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	async function unschedule(match: MatchDisplay) {
		if (!match.calendari_partida_id || saving) return;
		if (!confirm(`Desassignar la partida ${match.player1_name} vs ${match.player2_name}?`)) return;
		saving = true;
		error = null;

		try {
			const { error: delErr } = await supabase
				.from('calendari_partides')
				.delete()
				.eq('id', match.calendari_partida_id);
			if (delErr) throw new Error(delErr.message);

			const { error: updateErr } = await supabase
				.from('handicap_matches')
				.update({ calendari_partida_id: null, estat: 'pendent' })
				.eq('id', match.id);
			if (updateErr) throw new Error(updateErr.message);

			await loadData();
		} catch (e: any) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	// ── Auto-programació ──────────────────────────────────────────────────────

	function runAutoSchedule() {
		if (!config) return;

		const pending = schedulableNow.filter((m) => m.player1_soci_numero && m.player2_soci_numero);

		if (pending.length === 0) {
			error = 'No hi ha partides pendents amb tots dos jugadors assignats.';
			return;
		}

		autoScheduleMatchesInput = pending.map((m) => ({
			id: m.id,
			bracket_type: m.bracket_type,
			ronda: m.ronda,
			matchPos: m.matchPos,
			player1_participant_id: m.player1_participant_id!,
			player2_participant_id: m.player2_participant_id!,
			player1_soci_numero: m.player1_soci_numero!,
			player2_soci_numero: m.player2_soci_numero!
		}));

		const participants: ParticipantAvailability[] = pending
			.flatMap((m) => [m.player1_participant_id!, m.player2_participant_id!])
			.filter((id, i, arr) => arr.indexOf(id) === i)
			.map((id) => {
				const avail = participantMap.get(id);
				return avail ?? { participant_id: id, preferencies_dies: [], preferencies_hores: [] };
			});

		autoSchedulePreview = scheduleMatches({
			matches: autoScheduleMatchesInput,
			config,
			participants,
			occupiedSlots: allOccupiedSlots
		});

		showAutoSchedule = true;
	}

	async function confirmAutoSchedule() {
		if (!eventId || autoScheduleConfirming) return;
		autoScheduleConfirming = true;
		error = null;

		try {
			const result = await executeScheduling(
				supabase,
				eventId,
				autoScheduleMatchesInput,
				autoSchedulePreview
			);

			if (result.errors.length > 0) {
				error = `Errors durant la programació:\n${result.errors.join('\n')}`;
			}

			showAutoSchedule = false;
			autoSchedulePreview = [];
			autoScheduleMatchesInput = [];
			await loadData();
		} catch (e: any) {
			error = e.message;
		} finally {
			autoScheduleConfirming = false;
		}
	}

	function cancelAutoSchedule() {
		showAutoSchedule = false;
		autoSchedulePreview = [];
		autoScheduleMatchesInput = [];
	}

	function conflictMotiu(result: ScheduleItemResult): string {
		return (result as Extract<ScheduleItemResult, { scheduled: false }>).motiu;
	}

	// ── Introducció de resultats ────────────────────────────────────────────────

	async function handleResultConfirm(
		e: CustomEvent<{
			isWalkover: boolean;
			caramboles1: number | null;
			caramboles2: number | null;
			entrades: number | null;
			winnerParticipantId: string;
			loserParticipantId: string;
		}>
	) {
		const match = resultMatch;
		if (!match) return;
		resultSaving = true;
		error = null;

		const result = await saveMatchResult(supabase, {
			matchId: match.id,
			isWalkover: e.detail.isWalkover,
			caramboles1: e.detail.caramboles1,
			caramboles2: e.detail.caramboles2,
			entrades: e.detail.entrades,
			winnerParticipantId: e.detail.winnerParticipantId,
			loserParticipantId: e.detail.loserParticipantId,
			calendariPartidaId: match.calendari_partida_id
		});

		resultSaving = false;
		resultMatchId = null;

		if (!result.ok) {
			error = (result as SaveResultError).error;
			return;
		}

		const winnerName = e.detail.winnerParticipantId === match.player1_participant_id
			? match.player1_name
			: match.player2_name;

		if (result.isChampion) {
			estatCompeticio = 'finalitzat';
			resultConfirmation = `🏆 ${winnerName} és el CAMPIÓ del torneig! El torneig s'ha tancat.`;
		} else if (result.needsResetMatch) {
			resultConfirmation = `⚡ ${winnerName} guanya la Gran Final! Cal jugar el Reset Match (GF-R2) — ambdós jugadors estan assignats a la nova partida.`;
		} else {
			resultConfirmation = `Resultat registrat. ${winnerName} guanya i avança a ${result.winnerDestDesc}.${
				result.newSchedulableCount > 0
					? ` ${result.newSchedulableCount} nova${result.newSchedulableCount !== 1 ? 'es' : ''} partida${result.newSchedulableCount !== 1 ? 'des' : ''} llesta${result.newSchedulableCount !== 1 ? 'es' : ''} per programar.`
					: ''
			}`;
		}

		await loadData();
		setTimeout(() => (resultConfirmation = null), result.isChampion ? 30000 : 8000);
	}

	// ── onMount ───────────────────────────────────────────────────────────────

	onMount(async () => {
		// data_inici / data_fi estan a events, no a handicap_config
		const { data: ev, error: evErr } = await supabase
			.from('events')
			.select('id, data_inici, data_fi, estat_competicio')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.order('creat_el', { ascending: false })
			.limit(1)
			.single();

		if (evErr || !ev) {
			error = 'No hi ha cap event hàndicap actiu.';
			loading = false;
			return;
		}
		eventId = ev.id;
		estatCompeticio = (ev as any).estat_competicio ?? 'en_curs';

		if (!ev.data_inici || !ev.data_fi) {
			error = 'L\'event hàndicap no té dates de competició configurades. Configura\'l a /handicap/configuracio.';
			loading = false;
			return;
		}

		// horaris_extra és a handicap_config
		const { data: cfg, error: cfgErr } = await supabase
			.from('handicap_config')
			.select('horaris_extra, sistema_puntuacio, limit_entrades')
			.eq('event_id', ev.id)
			.single();

		if (cfgErr || !cfg) {
			error = 'No hi ha configuració per a l\'event hàndicap actiu.';
			loading = false;
			return;
		}

		sistemaPuntuacio = (cfg.sistema_puntuacio as string) ?? 'distancia';
		limitEntrades = (cfg.limit_entrades as number | null) ?? null;

		config = {
			data_inici: ev.data_inici as string,
			data_fi: ev.data_fi as string,
			horaris_extra: cfg.horaris_extra ?? undefined
		} as TournamentConfig;

		await loadData();
		loading = false;
	});
</script>

<div class="mx-auto max-w-5xl p-4">
	<!-- Capçalera -->
	<div class="mb-4 flex items-center gap-3">
		<a href="/handicap" class="text-sm text-purple-600 hover:underline">← Hàndicap</a>
		<h1 class="text-2xl font-bold text-gray-900">Partides</h1>
	</div>

	{#if loading}
		<p class="text-gray-500">Carregant...</p>
	{:else if error && matches.length === 0}
		<div class="rounded border border-red-300 bg-red-50 p-4 text-red-800">{error}</div>
	{:else}
		{#if isFinalitzat}
			<div class="mb-4 rounded-xl border-2 border-yellow-400 bg-yellow-50 px-5 py-4 flex items-center gap-3">
				<span class="text-2xl">🏆</span>
				<div class="flex-1">
					<p class="font-semibold text-yellow-800">Torneig finalitzat — mode de sola lectura</p>
					<p class="text-xs text-yellow-700">Ja no es poden introduir resultats ni programar partides.</p>
				</div>
				<a href="/handicap/resum?event={eventId}" class="rounded-lg bg-yellow-500 px-4 py-1.5 text-sm font-semibold text-white hover:bg-yellow-600">
					Veure resum
				</a>
			</div>
		{/if}
		<!-- Estadístiques -->
		<div class="mb-4 grid grid-cols-2 gap-3 text-sm sm:grid-cols-5">
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-gray-800">{stats.total}</div>
				<div class="text-xs text-gray-500">Total</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-gray-600">{stats.pending}</div>
				<div class="text-xs text-gray-500">Pendents</div>
			</div>
			<div
				class="rounded border p-3 text-center shadow-sm
				{schedulableNow.length > 0
					? 'border-amber-300 bg-amber-50'
					: 'border-gray-200 bg-white'}"
			>
				<div class="text-xl font-bold {schedulableNow.length > 0 ? 'text-amber-600' : 'text-gray-400'}">
					{schedulableNow.length}
				</div>
				<div class="text-xs text-gray-500">Llestes per prog.</div>
			</div>
			<div class="rounded border border-blue-200 bg-blue-50 p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-blue-700">{stats.scheduled}</div>
				<div class="text-xs text-gray-500">Programades</div>
			</div>
			<div class="rounded border border-green-200 bg-green-50 p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-green-700">{stats.played}</div>
				<div class="text-xs text-gray-500">Jugades</div>
			</div>
		</div>

		<!-- Badge: noves partides llestes per programar -->
		{#if schedulableNow.length > 0 && !showAutoSchedule}
			<div class="mb-4 flex items-center gap-3 rounded-lg border border-amber-300 bg-amber-50 px-4 py-3">
				<span class="text-lg">📋</span>
				<div class="flex-1">
					<span class="font-semibold text-amber-800">
						{schedulableNow.length} partida{schedulableNow.length !== 1 ? 's' : ''} nova{schedulableNow.length !== 1 ? 'es' : ''} llesta{schedulableNow.length !== 1 ? 's' : ''} per programar
					</span>
					<p class="text-xs text-amber-600">Ambdós jugadors estan assignats i la partida es pot calendaritzar.</p>
				</div>
				<button
					type="button"
					on:click={runAutoSchedule}
					class="rounded-lg bg-amber-500 px-4 py-1.5 text-sm font-semibold text-white hover:bg-amber-600"
				>
					Programar ara
				</button>
			</div>
		{/if}

		{#if error}
			<div class="mb-4 rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800 whitespace-pre-wrap">
				{error}
			</div>
		{/if}

		{#if resultConfirmation}
			<div class="mb-4 flex items-start gap-3 rounded-lg border border-green-300 bg-green-50 px-4 py-3">
				<span class="text-lg">✅</span>
				<p class="flex-1 text-sm font-medium text-green-800">{resultConfirmation}</p>
				<button
					type="button"
					on:click={() => (resultConfirmation = null)}
					class="text-green-600 hover:text-green-800"
				>✕</button>
			</div>
		{/if}

		<!-- Auto-programació -->
		{#if !showAutoSchedule && !isFinalitzat}
			<div class="mb-4 flex items-center justify-between rounded-lg border border-purple-200 bg-purple-50 p-4">
				<div>
					<p class="font-semibold text-purple-800">Programació automàtica</p>
					<p class="text-xs text-purple-600">
						Assigna dates, hores i taules a les partides llestes respectant disponibilitats i equilibrant branques.
					</p>
				</div>
				<button
					type="button"
					on:click={runAutoSchedule}
					disabled={schedulableNow.length === 0 || !config}
					class="rounded-lg px-5 py-2 text-sm font-semibold text-white transition-colors
						{schedulableNow.length > 0 && config
							? 'bg-purple-600 hover:bg-purple-700'
							: 'cursor-not-allowed bg-gray-300'}"
				>
					Programar {schedulableNow.length} llesta{schedulableNow.length !== 1 ? 'es' : ''}
				</button>
			</div>
		{:else}
			<!-- Previsualització auto-programació -->
			<div class="mb-4 rounded-lg border border-purple-300 bg-white shadow-sm">
				<div class="border-b border-purple-100 bg-purple-50 px-4 py-3">
					<h2 class="font-semibold text-purple-800">Previsualització de la programació automàtica</h2>
					<p class="text-xs text-purple-600 mt-0.5">
						{autoSchedulePreview.filter((r) => r.scheduled).length} programades·
						{autoSchedulePreview.filter((r) => !r.scheduled).length} conflictes
					</p>
				</div>
				<div class="max-h-80 overflow-y-auto divide-y divide-gray-50">
					{#each autoSchedulePreview as result}
						{@const m = matches.find((x) => x.id === result.match_id)}
						<div class="flex items-center gap-3 px-4 py-2 text-sm">
							{#if result.scheduled}
								<span class="text-green-600 font-bold w-4">✓</span>
							{:else}
								<span class="text-red-500 font-bold w-4">✗</span>
							{/if}
							<span class="flex-1 text-gray-800 text-xs">
								{m?.player1_name ?? '?'} vs {m?.player2_name ?? '?'}
								<span class="text-gray-400 ml-1">
									({m ? BRACKET_LABELS[m.bracket_type] : '?'} R{m?.ronda})
								</span>
							</span>
							{#if result.scheduled}
								<span class="text-green-700 font-medium text-xs">
									{result.data} {result.hora} T{result.taula}
								</span>
							{:else}
								<span class="text-red-600 text-xs">{conflictMotiu(result)}</span>
							{/if}
						</div>
					{/each}
				</div>
				<div class="flex justify-end gap-2 border-t border-gray-100 px-4 py-3">
					<button
						type="button"
						on:click={cancelAutoSchedule}
						class="rounded border border-gray-300 bg-white px-4 py-1.5 text-sm text-gray-700 hover:bg-gray-50"
					>
						Cancel·lar
					</button>
					<button
						type="button"
						on:click={confirmAutoSchedule}
						disabled={autoScheduleConfirming ||
							autoSchedulePreview.filter((r) => r.scheduled).length === 0}
						class="rounded-lg px-5 py-1.5 text-sm font-semibold text-white transition-colors
							{!autoScheduleConfirming && autoSchedulePreview.filter((r) => r.scheduled).length > 0
								? 'bg-purple-600 hover:bg-purple-700'
								: 'cursor-not-allowed bg-gray-300'}"
					>
						{autoScheduleConfirming ? 'Guardant...' : 'Confirmar programació'}
					</button>
				</div>
			</div>
		{/if}

		<!-- Indicador d'equilibri de branques -->
		{#if branchMatches.length > 0}
			<div class="mb-4">
				<HandicapBranchBalance matches={branchMatches} />
			</div>
		{/if}

		<!-- Pestanyes: Llista / Calendari -->
		<div class="mb-4 flex items-center gap-1 rounded-lg border border-gray-200 bg-gray-50 p-1 w-fit">
			<button
				type="button"
				on:click={() => (activeTab = 'list')}
				class="rounded px-4 py-1.5 text-sm font-medium transition-colors
					{activeTab === 'list' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
			>
				&#9776; Llista
			</button>
			<button
				type="button"
				on:click={() => (activeTab = 'calendar')}
				class="rounded px-4 py-1.5 text-sm font-medium transition-colors
					{activeTab === 'calendar' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
			>
				&#128197; Calendari
			</button>
			{#if myParticipantId}
			<button
				type="button"
				on:click={() => (activeTab = 'mine')}
				class="rounded px-4 py-1.5 text-sm font-medium transition-colors
					{activeTab === 'mine' ? 'bg-purple-100 text-purple-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}"
			>
				&#128100; Les meves ({myMatches.length})
			</button>
			{/if}
		</div>

		{#if activeTab === 'calendar' && config}
			<HandicapWeeklyCalendar
				entries={calendarEntries}
				{config}
				on:matchclick={(e) => {
					const m = matches.find((x) => x.id === e.detail);
					if (m) {
						activeTab = 'list';
						filterEstat = 'all';
						filterBracket = 'all';
						filterRonda = 'all';
						searchTerm = m.player1_name.split(' ')[0];
					}
				}}
			/>
		{:else}

		<!-- Filtres -->
		<div class="mb-3 flex gap-2 overflow-x-auto pb-1">
			<input
				type="text"
				placeholder="Cercar jugador..."
				bind:value={searchTerm}
				class="shrink-0 rounded border border-gray-300 px-3 py-1.5 text-sm focus:border-purple-400 focus:outline-none"
			/>
			<select
				bind:value={filterEstat}
				class="rounded border border-gray-300 px-3 py-1.5 text-sm focus:border-purple-400 focus:outline-none"
			>
				<option value="all">Tots els estats</option>
				<option value="pendent">Pendent</option>
				<option value="programada">Programada</option>
				<option value="jugada">Jugada</option>
			</select>
			<select
				bind:value={filterBracket}
				class="rounded border border-gray-300 px-3 py-1.5 text-sm focus:border-purple-400 focus:outline-none"
			>
				<option value="all">Tots els brackets</option>
				<option value="winners">Winners</option>
				<option value="losers">Losers</option>
				<option value="grand_final">Gran Final</option>
			</select>
			<select
				bind:value={filterRonda}
				class="rounded border border-gray-300 px-3 py-1.5 text-sm focus:border-purple-400 focus:outline-none"
			>
				<option value="all">Totes les rondes</option>
				{#each availableRounds as r}
					<option value={r}>Ronda {r}</option>
				{/each}
			</select>
			{#if filterEstat !== 'all' || filterBracket !== 'all' || filterRonda !== 'all' || searchTerm}
				<button
					type="button"
					on:click={() => {
						filterEstat = 'all';
						filterBracket = 'all';
						filterRonda = 'all';
						searchTerm = '';
					}}
					class="rounded border border-gray-200 px-3 py-1.5 text-xs text-gray-500 hover:bg-gray-50"
				>
					Netejar filtres
				</button>
			{/if}
		</div>

		<!-- Taula de partides -->
		<div class="rounded-lg border border-gray-200 bg-white shadow-sm">
			{#if filteredMatches.length === 0}
				<p class="p-6 text-center text-sm text-gray-500">
					Cap partida coincideix amb els filtres actuals.
				</p>
			{:else}
				<div class="overflow-x-auto -mx-4 px-4">
				<table class="w-full text-sm min-w-[600px]">
					<thead>
						<tr class="border-b border-gray-100 bg-gray-50 text-left text-xs text-gray-500">
							<th class="px-3 py-2 w-12 text-center font-mono">Núm.</th>
							<th class="px-3 py-2 w-16">Bracket</th>
							<th class="px-3 py-2">Jugador 1</th>
							<th class="px-3 py-2 text-center w-8">vs</th>
							<th class="px-3 py-2">Jugador 2</th>
							<th class="px-3 py-2 w-20 text-center">Estat</th>
							<th class="px-3 py-2 w-32 text-center">Data/Hora/Taula</th>
							<th class="px-3 py-2 w-36 text-right">Accions</th>
						</tr>
					</thead>
					<tbody class="divide-y divide-gray-50">
						{#each filteredMatches as match (match.id)}
							<tr class="hover:bg-gray-50/50">
								<td class="px-3 py-2 text-center font-mono text-xs text-gray-500">{match.matchCode}</td>
								<td class="px-3 py-2">
									<span
										class="rounded px-1.5 py-0.5 text-xs font-bold {BRACKET_COLORS[
											match.bracket_type
										]}"
									>
										{BRACKET_LABELS[match.bracket_type]} R{match.ronda}
									</span>
								</td>
								<td class="px-3 py-2">
									<div class="font-medium text-gray-900">{match.player1_name}</div>
									{#if match.player1_distancia}
										<div class="text-xs text-gray-400">{match.player1_distancia} car.</div>
									{/if}
								</td>
								<td class="px-1 py-2 text-center text-xs text-gray-400">vs</td>
								<td class="px-3 py-2">
									<div class="font-medium text-gray-900">{match.player2_name}</div>
									{#if match.player2_distancia}
										<div class="text-xs text-gray-400">{match.player2_distancia} car.</div>
									{/if}
								</td>
								<td class="px-3 py-2 text-center">
									<span
										class="rounded px-1.5 py-0.5 text-xs font-medium {ESTAT_COLORS[match.estat] ??
											'bg-gray-100 text-gray-600'}"
									>
										{ESTAT_LABELS[match.estat] ?? match.estat}
									</span>
								</td>
								<td class="px-3 py-2 text-center text-xs text-gray-600">
									{formatDataHora(match.data_programada, match.hora_inici, match.taula_assignada)}
								</td>
								<td class="px-3 py-2 text-right">
									{#if $isAdmin}
									{#if !isFinalitzat && (match.estat === 'pendent' || match.estat === 'programada')}
										{#if match.player1_participant_id && match.player2_participant_id && config}
											{#if schedulingMatchId === match.id}
												<button
													type="button"
													on:click={() => (schedulingMatchId = null)}
													class="rounded border border-gray-300 bg-white px-2 py-1 text-xs text-gray-600 hover:bg-gray-50"
												>
													Tancar
												</button>
											{:else}
												<button
													type="button"
													on:click={() => (schedulingMatchId = match.id)}
													disabled={saving}
													class="rounded border border-purple-300 bg-purple-50 px-2 py-1 text-xs text-purple-700 hover:bg-purple-100 disabled:opacity-50"
												>
													{match.estat === 'programada' ? 'Reprogramar' : 'Programar'}
												</button>
											{/if}
										{/if}
										{#if match.estat === 'programada' && match.calendari_partida_id}
											<button
												type="button"
												on:click={() => unschedule(match)}
												disabled={saving}
												class="ml-1 rounded border border-red-200 bg-red-50 px-2 py-1 text-xs text-red-600 hover:bg-red-100 disabled:opacity-50"
											>
												Desassignar
											</button>
										{/if}
									{/if}
									{#if !isFinalitzat && match.estat === 'programada' && match.player1_participant_id && match.player2_participant_id}
										<button
											type="button"
											on:click={() => (resultMatchId = match.id)}
											disabled={saving || resultSaving}
											class="ml-1 rounded border border-green-300 bg-green-50 px-2 py-1 text-xs font-medium text-green-700 hover:bg-green-100 disabled:opacity-50"
										>
											Resultat
										</button>
									{/if}
									{/if}<!-- end isAdmin -->
								</td>
							</tr>

							<!-- Slot Picker inline -->
							{#if schedulingMatchId === match.id && slotPickerAvail1 && slotPickerAvail2 && config}
								<tr>
									<td colspan="7" class="bg-gray-50 px-4 py-3">
										<div class="mb-2 text-xs font-semibold text-gray-600">
											Selecciona slot per a: {match.player1_name} vs {match.player2_name}
										</div>
										<HandicapSlotPicker
											avail1={slotPickerAvail1}
											avail2={slotPickerAvail2}
											{config}
											occupiedSlots={allOccupiedSlots}
											{currentSlot}
											on:select={(e) => manualSchedule(e.detail)}
											on:cancel={() => (schedulingMatchId = null)}
										/>
									</td>
								</tr>
							{/if}
						{/each}
					</tbody>
				</table>
				</div>
			{/if}
		</div>

		{/if}<!-- end tab list/calendar -->

		{#if activeTab === 'mine'}
		<div class="rounded-lg border border-gray-200 bg-white shadow-sm">
			{#if myMatches.length === 0}
				<p class="px-4 py-6 text-center text-sm text-gray-500">No tens partides assignades en aquest torneig.</p>
			{:else}
				<table class="w-full text-sm">
					<tbody>
						{#each myMatches as match}
							<tr class="border-b border-gray-100 {match.player1_participant_id === myParticipantId || match.player2_participant_id === myParticipantId ? 'bg-purple-50/30' : ''}">
								<td class="px-3 py-2">
									<span class="rounded px-1.5 py-0.5 text-xs font-mono font-bold {BRACKET_COLORS[match.bracket_type]}">{match.matchCode}</span>
								</td>
								<td class="px-3 py-2">
									<div class="font-medium {match.player1_participant_id === myParticipantId ? 'text-purple-700' : 'text-gray-900'}">{match.player1_name}</div>
									<div class="text-xs text-gray-400">vs</div>
									<div class="font-medium {match.player2_participant_id === myParticipantId ? 'text-purple-700' : 'text-gray-900'}">{match.player2_name}</div>
								</td>
								<td class="px-3 py-2 text-center">
									<span class="rounded px-1.5 py-0.5 text-xs font-medium {ESTAT_COLORS[match.estat] ?? 'bg-gray-100 text-gray-600'}">{ESTAT_LABELS[match.estat] ?? match.estat}</span>
								</td>
								<td class="px-3 py-2 text-center text-xs text-gray-600">
									{formatDataHora(match.data_programada, match.hora_inici, match.taula_assignada)}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			{/if}
		</div>
		{/if}<!-- end tab mine -->
	{/if}
</div>

<!-- ── Modal d'introducció de resultat ────────────────────────────────────── -->
{#if $isAdmin && resultMatch}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
		on:click|self={() => (resultMatchId = null)}
	>
		<div
			class="w-full max-w-md rounded-lg bg-white shadow-xl flex flex-col max-h-[90vh]"
			on:click|stopPropagation
			role="dialog"
			aria-modal="true"
		>
			<div class="flex items-center justify-between border-b border-gray-200 px-5 py-4">
				<div>
					<h2 class="font-semibold text-gray-900">Introduir resultat</h2>
					<p class="text-xs text-gray-500">
						{BRACKET_LABELS[resultMatch.bracket_type]} R{resultMatch.ronda} · Pos {resultMatch.matchPos}
					</p>
				</div>
				<button
					type="button"
					on:click={() => (resultMatchId = null)}
					class="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600"
				>✕</button>
			</div>
			<div class="px-5 py-4">
				<HandicapMatchResult
					player1Name={resultMatch.player1_name}
					player2Name={resultMatch.player2_name}
					player1Distancia={resultMatch.player1_distancia}
					player2Distancia={resultMatch.player2_distancia}
					player1ParticipantId={resultMatch.player1_participant_id!}
					player2ParticipantId={resultMatch.player2_participant_id!}
					{sistemaPuntuacio}
					{limitEntrades}
					saving={resultSaving}
					on:confirm={handleResultConfirm}
					on:cancel={() => (resultMatchId = null)}
				/>
			</div>
		</div>
	</div>
{/if}
