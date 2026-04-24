<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
	import { user } from '$lib/stores/auth';
	import HandicapBracketView from '$lib/components/handicap/HandicapBracketView.svelte';
	import HandicapBranchBalance from '$lib/components/handicap/HandicapBranchBalance.svelte';
	import HandicapMatchResult from '$lib/components/handicap/HandicapMatchResult.svelte';
	import type { MatchView, PlayerInfo, BranchMatchInput } from '$lib/utils/handicap-types';
	import { buildMatchCodeMap, buildLoserDestCodeMap, buildSlotSourceMap } from '$lib/utils/handicap-types';
	import { saveMatchResult, closeTournamentManual } from '$lib/utils/handicap-propagation';
	import type { SaveResultError } from '$lib/utils/handicap-propagation';
	import { shortName } from '$lib/utils/name-formatter';
	import { generateDoublEliminationBracket } from '$lib/utils/handicap-bracket-generator';
	import { validateBracket } from '$lib/utils/handicap-bracket-validator';
	import { insertBracketToDb } from '$lib/utils/handicap-bracket-db';

	// ── Estat ─────────────────────────────────────────────────────────────────

	let loading = true;
	let error: string | null = null;
	let event: any = null;
	let regenerating = false;

	let matchViews: MatchView[] = [];
	let participants: any[] = [];

	// Filtres
	let filter: 'all' | 'winners' | 'losers' | 'grand_final' = 'all';
	let searchTerm = '';

	// Modal detall partida
	let selectedMatchId: string | null = null;
	$: selectedMatch = selectedMatchId ? (matchViews.find((m) => m.id === selectedMatchId) ?? null) : null;

	// Sistema de puntuació
	let sistemaPuntuacio: string = 'distancia';
	let limitEntrades: number | null = null;

	// Participant actual (si l'usuari és participant del torneig)
	let myParticipantId: string | null = null;

	// Estat del torneig
	let estatCompeticio: string = 'en_curs';
	let championParticipantId: string | null = null;
	let championName: string | null = null;
	let subchampionName: string | null = null;
	$: isFinalitzat = estatCompeticio === 'finalitzat';
	let closingTournament = false;

	// Resultat modal
	let showResultForm = false;

	// ── Numeració de partides ────────────────────────────────────────────────

	$: matchCodeMap = buildMatchCodeMap(matchViews);
	$: loserDestCodeMap = buildLoserDestCodeMap(matchViews, matchCodeMap);
	$: selectedMatchCode = selectedMatch ? (matchCodeMap.get(selectedMatch.id) ?? '') : '';
	$: selectedLoserDest = selectedMatch ? (loserDestCodeMap.has(selectedMatch.id) ? loserDestCodeMap.get(selectedMatch.id) : undefined) : undefined;
	$: slotSourceMap = buildSlotSourceMap(matchViews, matchCodeMap);

	function pendingLabel(slotId: string): string {
		const src = slotSourceMap.get(slotId);
		return src ? `${src.role} ${src.code}` : 'Per determinar';
	}

	let resultSaving = false;
	let resultConfirmation: string | null = null;
	let quadreError: string | null = null;

	// ── Admin ─────────────────────────────────────────────────────────────────

	$: isLocked = matchViews.some((m) => m.estat === 'jugada' || m.estat === 'walkover');
	$: canRegenerate = !isLocked && matchViews.length > 0;
	$: branchMatches = matchViews as BranchMatchInput[];

	async function regenerateBracket() {
		if (!event || !canRegenerate) return;
		const confirmed = window.confirm(
			'Estàs segur que vols regenerar el bracket?\n\nS\'esborraran tots els slots i partides actuals i es tornaran a generar a partir dels seeds actuals.'
		);
		if (!confirmed) return;

		regenerating = true;
		error = null;
		try {
			// 1. Esborrar matches primer (FK: slot1_id, slot2_id → slots)
			const { error: delMatchErr } = await supabase
				.from('handicap_matches')
				.delete()
				.eq('event_id', event.id);
			if (delMatchErr) throw delMatchErr;

			// 2. Esborrar slots
			const { error: delSlotErr } = await supabase
				.from('handicap_bracket_slots')
				.delete()
				.eq('event_id', event.id);
			if (delSlotErr) throw delSlotErr;

			// 3. Carregar participants amb seeds actuals
			const { data: partsData, error: pErr } = await supabase
				.from('handicap_participants')
				.select('id, distancia, seed')
				.eq('event_id', event.id)
				.not('seed', 'is', null);
			if (pErr) throw pErr;

			const participantInputs = (partsData ?? []).map((p: any) => ({
				id: p.id as string,
				seed: p.seed as number,
				distancia: p.distancia as number
			}));

			if (participantInputs.length < 4) {
				throw new Error('Cal mínim 4 participants amb seed per regenerar el bracket.');
			}

			// 4. Generar bracket
			const result = generateDoublEliminationBracket(event.id, participantInputs);

			// 5. Validar
			const validation = validateBracket(result.slots as any, result.matches as any, participantInputs.length);
			if (!validation.valid) {
				throw new Error('Error de validació intern:\n' + validation.errors.join('\n'));
			}

			// 6. Insertar bracket (3 passos per la FK circular slots↔matches)
			await insertBracketToDb(supabase, result);

			// 7. Recarregar dades
			await loadBracketData(event.id);
		} catch (e: any) {
			error = e.message ?? 'Error regenerant el bracket';
		} finally {
			regenerating = false;
		}
	}

	// ── Estadístiques ─────────────────────────────────────────────────────────

	$: totalMatches = matchViews.filter((m) => m.estat !== 'bye').length;
	$: playedMatches = matchViews.filter((m) => m.estat === 'jugada' || m.estat === 'walkover').length;
	$: pendingMatches = matchViews.filter((m) => m.estat === 'pendent' || m.estat === 'programada').length;
	$: eliminatedCount = participants.filter((p) => p.eliminat).length;
	$: activeCount = participants.length - eliminatedCount;

	$: currentRound = (() => {
		const played = matchViews
			.filter((m) => (m.estat === 'jugada' || m.estat === 'walkover') && m.bracket_type === 'winners')
			.map((m) => m.ronda);
		if (played.length === 0) return 1;
		return Math.max(...played);
	})();

	// ── Càrrega de dades ──────────────────────────────────────────────────────

	let realtimeChannel: ReturnType<typeof supabase.channel> | null = null;
	let realtimeDebounceTimer: ReturnType<typeof setTimeout> | null = null;
	let cancelled = false;

	onMount(async () => {
		try {
			// 1. Event actiu, o si no n'hi ha, el més recent de tipus handicap
			let ev: any = null;
			const { data: activeEv } = await supabase
				.from('events')
				.select('id, nom, estat_competicio')
				.eq('tipus_competicio', 'handicap')
				.eq('actiu', true)
				.limit(1)
				.maybeSingle();
			if (cancelled) return;

			if (activeEv) {
				ev = activeEv;
			} else {
				const { data: recentEv } = await supabase
					.from('events')
					.select('id, nom, estat_competicio')
					.eq('tipus_competicio', 'handicap')
					.order('creat_el', { ascending: false })
					.limit(1)
					.maybeSingle();
				if (cancelled) return;
				ev = recentEv;
			}

			if (!ev) {
				error = 'No hi ha cap event hàndicap.';
				return;
			}
			event = ev;
			estatCompeticio = (ev as any).estat_competicio ?? 'en_curs';

			// 1b. Configuració del torneig
			const { data: cfg } = await supabase
				.from('handicap_config')
				.select('sistema_puntuacio, limit_entrades')
				.eq('event_id', ev.id)
				.single();
			if (cancelled) return;
			if (cfg) {
				sistemaPuntuacio = (cfg.sistema_puntuacio as string) ?? 'distancia';
				limitEntrades = (cfg.limit_entrades as number | null) ?? null;
			}

			// 2. Comprovar que hi ha bracket generat
			const { count: slotCount } = await supabase
				.from('handicap_bracket_slots')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', ev.id);
			if (cancelled) return;

			if ((slotCount ?? 0) === 0) {
				await goto('/handicap/sorteig');
				return;
			}

			await loadBracketData(ev.id);
			if (cancelled) return;

			// Subscripció realtime: recarregar quan canviïn partides o slots
			realtimeChannel = supabase
				.channel(`handicap-quadre-${ev.id}`)
				.on('postgres_changes', { event: '*', schema: 'public', table: 'handicap_matches', filter: `event_id=eq.${ev.id}` }, () => {
					if (cancelled) return;
					if (realtimeDebounceTimer) clearTimeout(realtimeDebounceTimer);
					realtimeDebounceTimer = setTimeout(() => {
						if (!cancelled) loadBracketData(ev.id);
					}, 300);
				})
				.on('postgres_changes', { event: '*', schema: 'public', table: 'handicap_bracket_slots', filter: `event_id=eq.${ev.id}` }, () => {
					if (cancelled) return;
					if (realtimeDebounceTimer) clearTimeout(realtimeDebounceTimer);
					realtimeDebounceTimer = setTimeout(() => {
						if (!cancelled) loadBracketData(ev.id);
					}, 300);
				})
				.subscribe();
		} catch (e: any) {
			if (!cancelled) error = e?.message ?? 'Error carregant el quadre hàndicap';
		} finally {
			if (!cancelled) loading = false;
		}
	});

	onDestroy(() => {
		cancelled = true;
		if (realtimeDebounceTimer) {
			clearTimeout(realtimeDebounceTimer);
			realtimeDebounceTimer = null;
		}
		realtimeChannel?.unsubscribe();
		realtimeChannel = null;
	});

	async function loadBracketData(eventId: string) {
		// 3. Participants amb noms (Fase 5c-S2b: FK directe via soci_numero)
		const { data: partsData, error: pErr } = await supabase
			.from('handicap_participants')
			.select(
				'id, distancia, seed, eliminat, socis!handicap_participants_soci_numero_fkey(nom, cognoms)'
			)
			.eq('event_id', eventId);

		if (pErr) { error = pErr.message; return; }
		participants = partsData ?? [];

		const participantMap = new Map<string, PlayerInfo>(
			participants.map((p: any) => {
				const raw = p.socis;
				const s = Array.isArray(raw) ? raw[0] : raw;
				const nom = s?.nom ?? '';
				const cognoms = s?.cognoms ?? '';
				return [
					p.id,
					{
						id: p.id,
						name: `${nom} ${cognoms}`.trim(),
						shortName: shortName(nom, cognoms),
						distancia: p.distancia,
						seed: p.seed
					}
				];
			})
		);

		// 4. Slots
		const { data: slotsData, error: sErr } = await supabase
			.from('handicap_bracket_slots')
			.select('id, bracket_type, ronda, posicio, participant_id, is_bye')
			.eq('event_id', eventId);

		if (sErr) { error = sErr.message; return; }
		const slotMap = new Map((slotsData ?? []).map((s: any) => [s.id, s]));

		// 5. Matches
		const { data: matchesData, error: mErr } = await supabase
			.from('handicap_matches')
			.select(
				'id, slot1_id, slot2_id, winner_slot_dest_id, loser_slot_dest_id, estat, distancia_jugador1, distancia_jugador2, guanyador_participant_id, calendari_partida_id, calendari_partides(caramboles_jugador1, caramboles_jugador2, entrades, data_programada, hora_inici, taula_assignada)'
			)
			.eq('event_id', eventId);

		if (mErr) { error = mErr.message; return; }

		// 6. Construir matchViews
		matchViews = (matchesData ?? []).map((m: any) => {
			const s1: any = slotMap.get(m.slot1_id);
			const s2: any = slotMap.get(m.slot2_id);
			if (!s1 || !s2) return null;

			return {
				id: m.id,
				bracket_type: s1.bracket_type as MatchView['bracket_type'],
				ronda: s1.ronda as number,
				matchPos: Math.ceil(s1.posicio / 2) as number,
				estat: m.estat as MatchView['estat'],
				slot1: { id: s1.id, participant_id: s1.participant_id, is_bye: s1.is_bye, posicio: s1.posicio },
				slot2: { id: s2.id, participant_id: s2.participant_id, is_bye: s2.is_bye, posicio: s2.posicio },
				player1: s1.participant_id ? (participantMap.get(s1.participant_id) ?? null) : null,
				player2: s2.participant_id ? (participantMap.get(s2.participant_id) ?? null) : null,
				distancia_jugador1: m.distancia_jugador1,
				distancia_jugador2: m.distancia_jugador2,
				caramboles1: (m.calendari_partides as any)?.caramboles_jugador1 ?? null,
				caramboles2: (m.calendari_partides as any)?.caramboles_jugador2 ?? null,
				entrades: (m.calendari_partides as any)?.entrades ?? null,
				guanyador_participant_id: m.guanyador_participant_id,
				winner_slot_dest_id: m.winner_slot_dest_id,
				loser_slot_dest_id: m.loser_slot_dest_id,
				calendari_partida_id: m.calendari_partida_id,
				data_hora: (() => {
					const cp = m.calendari_partides as any;
					const d = cp?.data_programada?.substring(0, 10);
					const h = cp?.hora_inici?.substring(0, 5);
					return d && h ? `${d} ${h}` : null;
				})(),
				taula: (m.calendari_partides as any)?.taula_assignada?.toString() ?? null
			} satisfies MatchView;
		}).filter(Boolean) as MatchView[];

		// Detectar si l'usuari autenticat és participant del torneig
		// Fase 5c-S2b: matching directe via soci_numero, sense passar per players
		const userEmail = $user?.email;
		if (userEmail && !myParticipantId) {
			const { data: soci } = await supabase.from('socis').select('numero_soci').eq('email', userEmail).maybeSingle();
			if (soci) {
				const { data: part } = await supabase
					.from('handicap_participants')
					.select('id')
					.eq('event_id', eventId)
					.eq('soci_numero', soci.numero_soci)
					.maybeSingle();
				myParticipantId = part?.id ?? null;
			}
		}
	}

	// ── Modal ─────────────────────────────────────────────────────────────────

	function openMatch(match: MatchView) {
		selectedMatchId = match.id;
		showResultForm = false;
	}

	function closeModal() {
		selectedMatchId = null;
		showResultForm = false;
	}

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
		const match = selectedMatch;
		if (!match || !event) return;
		resultSaving = true;
		quadreError = null;

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
		closeModal();

		if (!result.ok) {
			quadreError = (result as SaveResultError).error;
			return;
		}

		const winnerName = e.detail.winnerParticipantId === match.slot1.participant_id
			? match.player1?.name ?? 'Jugador 1'
			: match.player2?.name ?? 'Jugador 2';
		const loserName = e.detail.winnerParticipantId === match.slot1.participant_id
			? match.player2?.name ?? 'Jugador 2'
			: match.player1?.name ?? 'Jugador 1';

		if (result.isChampion) {
			championParticipantId = result.championParticipantId;
			estatCompeticio = 'finalitzat';
			championName = winnerName;
			subchampionName = loserName;
			resultConfirmation = `🏆 ${winnerName} és el CAMPIÓ del torneig! El torneig s'ha tancat.`;
		} else if (result.needsResetMatch) {
			resultConfirmation = `⚡ ${winnerName} guanya la Gran Final! Cal jugar el Reset Match (GF-R2) perquè queden igualats.`;
		} else {
			let msg = `✅ ${winnerName} guanya i avança a ${result.winnerDestDesc}.`;
			if (result.autoScheduled && result.autoScheduled.scheduled > 0) {
				msg += ` 📅 ${result.autoScheduled.scheduled} partida${result.autoScheduled.scheduled !== 1 ? 's' : ''} programada${result.autoScheduled.scheduled !== 1 ? 'des' : ''} automàticament.`;
			} else if (result.autoScheduled && result.autoScheduled.conflicts > 0) {
				msg += ` ⚠️ ${result.autoScheduled.conflicts} partida${result.autoScheduled.conflicts !== 1 ? 'des' : ''} amb conflicte de calendari — programa-les manualment.`;
			}
			resultConfirmation = msg;
		}

		await loadBracketData(event.id);
		setTimeout(() => (resultConfirmation = null), result.isChampion ? 30000 : 8000);
	}

	async function handleCloseTournament() {
		if (!event) return;
		const confirmed = window.confirm(
			'Tancar el torneig?\n\nAixò marcarà el torneig com a "finalitzat" i ja no es podran introduir més resultats.'
		);
		if (!confirmed) return;
		closingTournament = true;
		quadreError = null;
		const result = await closeTournamentManual(supabase, event.id);
		closingTournament = false;
		if (!result.ok) {
			if (result.pendingCount && result.pendingCount > 0) {
				quadreError = `No es pot tancar: queden ${result.pendingCount} partides sense jugar.`;
			} else {
				quadreError = result.error ?? 'Error tancant el torneig.';
			}
			return;
		}
		estatCompeticio = 'finalitzat';
		resultConfirmation = 'Torneig tancat correctament.';
		setTimeout(() => (resultConfirmation = null), 5000);
	}

	function matchBracketLabel(m: MatchView): string {
		const bt = m.bracket_type === 'winners' ? 'Guanyadors' :
		           m.bracket_type === 'losers' ? 'Perdedors' : 'Gran Final';
		const rLabel = m.bracket_type === 'grand_final'
			? (m.ronda === 1 ? 'Final' : 'Reset')
			: `Ronda ${m.ronda}`;
		return `${bt} · ${rLabel}`;
	}

	function formatEstat(estat: string): string {
		const map: Record<string, string> = {
			pendent: 'Pendent',
			programada: 'Programada',
			jugada: 'Jugada',
			bye: 'BYE (avanç automàtic)',
			walkover: 'Walkover'
		};
		return map[estat] ?? estat;
	}
</script>

<div class="mx-auto max-w-full p-4 lg:max-w-screen-2xl">
	<!-- Capçalera -->
	<div class="mb-4 flex flex-wrap items-center gap-3 print:hidden">
		<a href="/handicap" class="text-sm text-purple-600 hover:underline">← Hàndicap</a>
		<h1 class="text-xl font-bold text-gray-900">Quadre</h1>
		{#if event}
			<span class="text-sm text-gray-500">{event.nom}</span>
		{/if}

		{#if !loading && !error}
			{#if isFinalitzat}
				<span class="rounded-full bg-yellow-100 px-2 py-0.5 text-xs font-semibold text-yellow-800">
					🏆 Finalitzat
				</span>
			{:else if isLocked}
				<span class="rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-700">
					&#128274; Bloquejat (hi ha partides jugades)
				</span>
			{:else}
				<span class="rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">
					&#9998; Editable
				</span>
			{/if}
		{/if}

		<div class="ml-auto flex flex-wrap gap-2">
			{#if !loading && !error}
				{#if $isAdmin}
					{#if !isLocked && !isFinalitzat}
						<a
							href="/handicap/inscripcions"
							class="rounded border border-gray-300 px-3 py-1 text-xs text-gray-600 hover:bg-gray-50"
						>
							Afegir jugador
						</a>
						<button
							type="button"
							on:click={regenerateBracket}
							disabled={regenerating}
							class="rounded border border-amber-400 bg-amber-50 px-3 py-1 text-xs font-medium text-amber-800 hover:bg-amber-100 disabled:opacity-50"
						>
							{regenerating ? 'Regenerant...' : 'Regenerar bracket'}
						</button>
					{/if}
					{#if !isFinalitzat && isLocked}
						<button
							type="button"
							on:click={handleCloseTournament}
							disabled={closingTournament}
							class="rounded border border-red-400 bg-red-50 px-3 py-1 text-xs font-medium text-red-700 hover:bg-red-100 disabled:opacity-50"
						>
							{closingTournament ? 'Tancant...' : 'Tancar torneig'}
						</button>
					{/if}
				{/if}
				<button
					type="button"
					on:click={() => window.print()}
					class="rounded border border-gray-300 bg-white px-3 py-1 text-xs text-gray-600 hover:bg-gray-50"
				>
					&#128438; Imprimir
				</button>
			{/if}
		</div>
	</div>

	<!-- Capçalera visible només a impressió -->
	<div class="mb-4 hidden print:block">
		<h1 class="text-2xl font-bold text-gray-900">Quadre — {event?.nom ?? 'Hàndicap'}</h1>
		<p class="text-sm text-gray-500">{new Date().toLocaleDateString('ca-ES', { day: 'numeric', month: 'long', year: 'numeric' })}</p>
	</div>

	{#if loading}
		<p class="text-gray-500">Carregant bracket...</p>
	{:else if error}
		<div class="rounded border border-red-300 bg-red-50 p-4 text-red-800">{error}</div>
	{:else}
		<!-- ── Banner campió ──────────────────────────────────────────────────── -->
		{#if isFinalitzat && championName}
			<div class="mb-4 rounded-xl border-2 border-yellow-400 bg-gradient-to-r from-yellow-50 to-amber-50 p-6 text-center shadow-lg print:hidden">
				<div class="text-4xl">🏆</div>
				<h2 class="mt-2 text-2xl font-bold text-yellow-800">{championName}</h2>
				<p class="text-sm font-medium text-yellow-700">Campió del torneig {event?.nom}</p>
				{#if subchampionName}
					<p class="mt-1 text-xs text-yellow-600">Subcampió: {subchampionName}</p>
				{/if}
				<a
					href="/handicap/resum?event={event?.id}"
					class="mt-3 inline-block rounded-lg bg-yellow-500 px-4 py-1.5 text-sm font-semibold text-white hover:bg-yellow-600"
				>
					Veure resum del torneig
				</a>
			</div>
		{:else if isFinalitzat}
			<div class="mb-4 rounded-lg border border-yellow-300 bg-yellow-50 px-4 py-3 text-sm font-medium text-yellow-800 print:hidden">
				🏆 Torneig finalitzat — mode de sola lectura
			</div>
		{/if}

		<!-- ── Estadístiques ───────────────────────────────────────────────────── -->
		<div class="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-5 print:hidden">
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-gray-800">{playedMatches}/{totalMatches}</div>
				<div class="text-xs text-gray-500">Partides jugades</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-blue-700">{pendingMatches}</div>
				<div class="text-xs text-gray-500">Pendents</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-green-700">{activeCount}</div>
				<div class="text-xs text-gray-500">Jugadors actius</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-red-600">{eliminatedCount}</div>
				<div class="text-xs text-gray-500">Eliminats</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-xl font-bold text-purple-700">G-R{currentRound}</div>
				<div class="text-xs text-gray-500">Ronda actual</div>
			</div>
		</div>

		<!-- ── Equilibri de branques ──────────────────────────────────────────── -->
		<div class="mb-4 print:hidden">
			<HandicapBranchBalance matches={branchMatches} />
		</div>

		<!-- ── Controls ───────────────────────────────────────────────────────── -->
		<div class="mb-4 flex flex-wrap gap-3 print:hidden">
			<!-- Filtres de bracket -->
			<div class="flex rounded border border-gray-200 bg-white shadow-sm overflow-hidden text-sm">
				{#each [['all','Tot'],['winners','Guanyadors'],['losers','Perdedors'],['grand_final','Gran Final']] as [val, label]}
					<button
						type="button"
						on:click={() => filter = val as typeof filter}
						class="px-3 py-1.5 transition-colors
							{filter === val ? 'bg-purple-600 text-white font-medium' : 'text-gray-600 hover:bg-gray-50'}"
					>
						{label}
					</button>
				{/each}
			</div>

			<!-- Cerca per nom -->
			<div class="relative flex-1 min-w-[200px] max-w-xs">
				<input
					type="text"
					bind:value={searchTerm}
					placeholder="Cerca jugador..."
					class="w-full rounded border border-gray-300 bg-white px-3 py-1.5 text-sm shadow-sm focus:border-purple-400 focus:outline-none focus:ring-1 focus:ring-purple-400"
				/>
				{#if searchTerm}
					<button
						type="button"
						on:click={() => searchTerm = ''}
						class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
					>✕</button>
				{/if}
			</div>
		</div>

		<!-- ── Visualització bracket ──────────────────────────────────────────── -->
		<div class="overflow-x-auto -mx-4 px-4">
		<HandicapBracketView
			{matchViews}
			{filter}
			{searchTerm}
			{championParticipantId}
			{sistemaPuntuacio}
			on:matchclick={(e) => openMatch(e.detail)}
		/>
		</div>
	{/if}
</div>

<!-- ── Modal detall partida ───────────────────────────────────────────────── -->
{#if selectedMatch}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
		on:click|self={closeModal}
	>
		<div
			class="w-full max-w-md rounded-lg bg-white shadow-xl flex flex-col max-h-[90vh]"
			on:click|stopPropagation
			role="dialog"
			aria-modal="true"
			tabindex="-1"
		>
			<!-- Modal header -->
			<div class="flex items-center justify-between border-b border-gray-200 px-5 py-4">
				<div>
					<h2 class="font-semibold text-gray-900">Detall de la partida</h2>
					<p class="text-xs text-gray-500">{matchBracketLabel(selectedMatch)}</p>
				</div>
				<button
					type="button"
					on:click={closeModal}
					class="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600"
				>✕</button>
			</div>

			<!-- Modal body -->
			<div class="overflow-y-auto px-5 py-4 space-y-4">
				<!-- Jugadors -->
				<div class="rounded border border-gray-200 overflow-hidden">
					<!-- Jugador 1 -->
					<div class="flex items-center gap-3 px-4 py-3
						{selectedMatch.guanyador_participant_id === selectedMatch.slot1.participant_id && selectedMatch.guanyador_participant_id
							? 'bg-green-50' : ''}">
						<div class="flex-1">
							<div class="font-medium text-gray-900 {selectedMatch.slot1.is_bye ? 'text-gray-400 line-through' : ''}">
								{selectedMatch.slot1.is_bye ? 'BYE' : (selectedMatch.player1?.name ?? pendingLabel(selectedMatch.slot1.id))}
							</div>
							{#if selectedMatch.player1?.seed}
								<div class="text-xs text-gray-500">Seed {selectedMatch.player1.seed}</div>
							{/if}
						</div>
						{#if selectedMatch.distancia_jugador1 && !selectedMatch.slot1.is_bye}
							<div class="text-sm font-semibold text-gray-700">
								{selectedMatch.distancia_jugador1} car.
							</div>
						{/if}
						{#if selectedMatch.guanyador_participant_id === selectedMatch.slot1.participant_id && selectedMatch.guanyador_participant_id}
							<span class="text-xs font-semibold text-green-700 bg-green-100 rounded px-2 py-0.5">Guanyador</span>
						{/if}
					</div>

					<div class="border-t border-gray-200 text-center text-xs font-bold text-gray-400 py-0.5">vs</div>

					<!-- Jugador 2 -->
					<div class="flex items-center gap-3 px-4 py-3
						{selectedMatch.guanyador_participant_id === selectedMatch.slot2.participant_id && selectedMatch.guanyador_participant_id
							? 'bg-green-50' : ''}">
						<div class="flex-1">
							<div class="font-medium text-gray-900 {selectedMatch.slot2.is_bye ? 'text-gray-400 line-through' : ''}">
								{selectedMatch.slot2.is_bye ? 'BYE' : (selectedMatch.player2?.name ?? pendingLabel(selectedMatch.slot2.id))}
							</div>
							{#if selectedMatch.player2?.seed}
								<div class="text-xs text-gray-500">Seed {selectedMatch.player2.seed}</div>
							{/if}
						</div>
						{#if selectedMatch.distancia_jugador2 && !selectedMatch.slot2.is_bye}
							<div class="text-sm font-semibold text-gray-700">
								{selectedMatch.distancia_jugador2} car.
							</div>
						{/if}
						{#if selectedMatch.guanyador_participant_id === selectedMatch.slot2.participant_id && selectedMatch.guanyador_participant_id}
							<span class="text-xs font-semibold text-green-700 bg-green-100 rounded px-2 py-0.5">Guanyador</span>
						{/if}
					</div>
				</div>

				<!-- Estat -->
				<div class="flex items-center justify-between rounded bg-gray-50 px-4 py-2 text-sm">
					<span class="text-gray-600">Estat</span>
					<span class="font-medium text-gray-900">{formatEstat(selectedMatch.estat)}</span>
				</div>

				<!-- Numeració i destinació del perdedor -->
				{#if selectedMatchCode}
					<div class="flex items-center justify-between rounded bg-gray-50 px-4 py-2 text-sm">
						<span class="text-gray-600">Partida</span>
						<span class="font-mono font-medium text-gray-900">{selectedMatchCode}</span>
					</div>
				{/if}
				{#if selectedLoserDest !== undefined}
					<div class="flex items-center justify-between rounded bg-gray-50 px-4 py-2 text-sm">
						<span class="text-gray-600">En cas de derrota</span>
						{#if selectedLoserDest}
							<span class="font-mono font-medium text-orange-600">↓ Partida {selectedLoserDest}</span>
						{:else}
							<span class="font-medium text-red-500">Eliminat del torneig</span>
						{/if}
					</div>
				{/if}

				{#if selectedMatch.estat === 'programada' && selectedMatch.data_hora}
					<div class="flex items-center justify-between rounded bg-blue-50 px-4 py-2 text-sm">
						<span class="text-blue-700">Data i hora</span>
						<span class="font-medium text-blue-900">
							{new Date(selectedMatch.data_hora).toLocaleString('ca-ES', {
								weekday: 'short', day: 'numeric', month: 'short',
								hour: '2-digit', minute: '2-digit'
							})}
						</span>
					</div>
					{#if selectedMatch.taula}
						<div class="flex items-center justify-between rounded bg-blue-50 px-4 py-2 text-sm">
							<span class="text-blue-700">Taula</span>
							<span class="font-medium text-blue-900">{selectedMatch.taula}</span>
						</div>
					{/if}
				{/if}
			</div>

		<!-- Formulari de resultat (inline) -->
		{#if showResultForm && selectedMatch.estat === 'programada' && selectedMatch.slot1.participant_id && selectedMatch.slot2.participant_id}
			<div class="border-t border-gray-200 px-5 py-4">
				<HandicapMatchResult
					player1Name={selectedMatch.player1?.name ?? 'Jugador 1'}
					player2Name={selectedMatch.player2?.name ?? 'Jugador 2'}
					player1Distancia={selectedMatch.distancia_jugador1 ?? selectedMatch.player1?.distancia ?? null}
					player2Distancia={selectedMatch.distancia_jugador2 ?? selectedMatch.player2?.distancia ?? null}
					player1ParticipantId={selectedMatch.slot1.participant_id}
					player2ParticipantId={selectedMatch.slot2.participant_id}
					{sistemaPuntuacio}
					{limitEntrades}
					saving={resultSaving}
					on:confirm={handleResultConfirm}
					on:cancel={() => (showResultForm = false)}
				/>
			</div>
		{:else}
			<!-- Botons d'acció -->
			<div class="border-t border-gray-200 px-5 py-4 flex gap-2 justify-end">
				<a
					href="/handicap/partides"
					class="rounded border border-purple-300 bg-purple-50 px-4 py-2 text-sm font-medium text-purple-700 hover:bg-purple-100"
				>
					Programar
				</a>
				{#if selectedMatch.estat === 'programada' && selectedMatch.slot1.participant_id && selectedMatch.slot2.participant_id && !isFinalitzat}
					<button
						type="button"
						on:click={() => (showResultForm = true)}
						class="rounded border border-green-300 bg-green-50 px-4 py-2 text-sm font-medium text-green-700 hover:bg-green-100"
					>
						Introduir resultat
					</button>
				{/if}
				<button
					type="button"
					on:click={closeModal}
					class="rounded bg-gray-100 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200"
				>
					Tancar
				</button>
			</div>
		{/if}
	</div>
</div>
{/if}

<!-- ── Confirmació resultat ───────────────────────────────────────────── -->
{#if resultConfirmation}
	<div class="fixed bottom-4 right-4 z-40 max-w-sm rounded-lg border border-green-300 bg-green-50 px-4 py-3 shadow-lg">
		<p class="text-sm font-medium text-green-800">{resultConfirmation}</p>
	</div>
{/if}
{#if quadreError}
	<div class="fixed bottom-4 right-4 z-40 max-w-sm rounded-lg border border-red-300 bg-red-50 px-4 py-3 shadow-lg">
		<div class="flex items-start gap-2">
			<p class="flex-1 text-sm text-red-800">{quadreError}</p>
			<button type="button" on:click={() => (quadreError = null)} class="text-red-500">✕</button>
		</div>
	</div>
{/if}

<style>
	@media print {
		/* Orientació apaïsada */
		@page {
			size: landscape;
			margin: 0.5cm;
		}

		/* Amagar navegació i controls */
		:global(nav),
		:global(header),
		.print\:hidden {
			display: none !important;
		}

		/* Mostrar capçalera d'impressió */
		.print\:block {
			display: block !important;
		}

		/* Eliminar restriccions de mida i padding del contenidor de pàgina */
		.mx-auto {
			max-width: none !important;
			padding: 0 !important;
			margin: 0 !important;
		}

		/* Eliminar overflow/scroll del contenidor exterior del bracket */
		.overflow-x-auto {
			overflow: visible !important;
			max-width: none !important;
			width: auto !important;
			margin-left: 0 !important;
			margin-right: 0 !important;
			padding-left: 0 !important;
			padding-right: 0 !important;
		}
	}
</style>
