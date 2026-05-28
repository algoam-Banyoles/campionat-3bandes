<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import HandicapWeeklyCalendar from '$lib/components/handicap/HandicapWeeklyCalendar.svelte';
	import type { CalendarEntry } from '$lib/utils/handicap-types';
	import type { TournamentConfig } from '$lib/utils/handicap-scheduler';
	import { formatarNomJugadorParts } from '$lib/utils/playerUtils';

	let loading = true;
	let error: string | null = null;
	let eventNom = '';
	let eventTemporada = '';
	let config: TournamentConfig | null = null;
	let calendarEntries: CalendarEntry[] = [];

	$: temporadaPretty = (eventTemporada || '').replace('-', '/');

	onMount(async () => {
		try {
			const { data: ev, error: evErr } = await supabase
				.from('events')
				.select('id, nom, temporada, data_inici, data_fi')
				.eq('tipus_competicio', 'handicap')
				.eq('actiu', true)
				.limit(1)
				.maybeSingle();

			if (evErr || !ev) {
				error = 'No hi ha cap torneig hàndicap actiu.';
				loading = false;
				return;
			}

			eventNom = ev.nom ?? '';
			eventTemporada = ev.temporada ?? '';

			if (!ev.data_inici || !ev.data_fi) {
				error = "L'event hàndicap no té dates de competició configurades.";
				loading = false;
				return;
			}

			const { data: cfg } = await supabase
				.from('handicap_config')
				.select('horaris_extra')
				.eq('event_id', ev.id)
				.maybeSingle();

			config = {
				data_inici: ev.data_inici as string,
				data_fi: ev.data_fi as string,
				horaris_extra: (cfg?.horaris_extra as any) ?? undefined
			} as TournamentConfig;

			// Carregar matches amb calendari_partida_id
			const { data: rawMatches, error: mErr } = await supabase
				.from('handicap_matches')
				.select('id, estat, slot1_id, slot2_id, calendari_partida_id')
				.eq('event_id', ev.id)
				.neq('estat', 'bye');

			if (mErr || !rawMatches) {
				error = mErr?.message ?? 'Error carregant partides.';
				loading = false;
				return;
			}

			const calIds = rawMatches
				.filter((m: any) => m.calendari_partida_id)
				.map((m: any) => m.calendari_partida_id as string);
			const slotIds = rawMatches.flatMap((m: any) => [m.slot1_id, m.slot2_id]);

			const [{ data: slots }, { data: cals }] = await Promise.all([
				supabase
					.from('handicap_bracket_slots')
					.select('id, bracket_type, ronda, participant_id')
					.in('id', slotIds),
				calIds.length > 0
					? supabase
							.from('calendari_partides')
							.select('id, data_programada, hora_inici, taula_assignada')
							.in('id', calIds)
					: Promise.resolve({ data: [] as any[] })
			]);

			const slotMap = new Map((slots ?? []).map((s: any) => [s.id, s]));
			const calMap = new Map((cals ?? []).map((c: any) => [c.id, c]));

			// Noms de jugadors
			const partIds = [...new Set(
				(slots ?? [])
					.filter((s: any) => s.participant_id)
					.map((s: any) => s.participant_id as string)
			)];

			const nameMap = new Map<string, string>();
			if (partIds.length > 0) {
				const { data: parts } = await supabase
					.from('handicap_participants')
					.select('id, socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
					.in('id', partIds);
				for (const p of parts ?? []) {
					const s = Array.isArray((p as any).socis) ? (p as any).socis[0] : (p as any).socis;
					const nom = s ? (formatarNomJugadorParts(s.nom, s.cognoms) || '?') : '?';
					nameMap.set((p as any).id, nom);
				}
			}

			calendarEntries = rawMatches
				.map((m: any) => {
					const cal = m.calendari_partida_id ? calMap.get(m.calendari_partida_id) : null;
					const s1 = slotMap.get(m.slot1_id);
					const s2 = slotMap.get(m.slot2_id);
					if (!cal || !s1 || !s2) return null;
					if (!cal.data_programada || !cal.hora_inici || !cal.taula_assignada) return null;
					const data = (cal.data_programada as string).substring(0, 10);
					const hora = (cal.hora_inici as string).substring(0, 5);
					return {
						id: m.id,
						player1_name: nameMap.get(s1.participant_id) ?? '?',
						player2_name: nameMap.get(s2.participant_id) ?? '?',
						bracket_type: s1.bracket_type as 'winners' | 'losers' | 'grand_final',
						ronda: s1.ronda as number,
						estat: m.estat,
						data_programada: data,
						hora_inici: hora,
						taula_assignada: cal.taula_assignada as number
					} satisfies CalendarEntry;
				})
				.filter((x: CalendarEntry | null): x is CalendarEntry => x !== null);
		} catch (e: any) {
			error = e?.message ?? String(e);
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Calendari — Hàndicap</title>
</svelte:head>

<div class="hcap-root">
	<header class="page-mast">
		<div>
			<div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">
				<a href="/handicap" class="back-link">← Hàndicap</a>
			</div>
			<h1 class="page-title">Calendari de partides</h1>
			{#if eventNom}
				<p class="page-sub">{eventNom}{temporadaPretty ? ` · ${temporadaPretty}` : ''}</p>
			{/if}
		</div>
		<div class="stat-chip">
			<span class="stat-num">{calendarEntries.length}</span>
			<span class="stat-lbl">partid{calendarEntries.length === 1 ? 'a' : 'es'}</span>
		</div>
	</header>

	{#if loading}
		<p class="muted">Carregant...</p>
	{:else if error}
		<div class="alert-error">{error}</div>
	{:else if !config}
		<div class="alert-error">Configuració no disponible.</div>
	{:else if calendarEntries.length === 0}
		<div class="empty">Encara no hi ha cap partida programada.</div>
	{:else}
		<HandicapWeeklyCalendar
			entries={calendarEntries}
			{config}
			on:matchclick={() => goto('/handicap/quadre')}
		/>
	{/if}
</div>

<style>
	.hcap-root {
		max-width: 64rem;
		margin: 0 auto;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		font-family: var(--font-sans);
		color: var(--ink);
	}
	.page-mast {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		gap: 1rem;
		padding-bottom: 1rem;
		border-bottom: 2px solid var(--ink);
	}
	.editorial-eyebrow {
		font-size: 0.75rem;
		font-weight: 600;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		color: var(--sec-handicap);
	}
	.back-link { color: var(--sec-handicap); text-decoration: none; }
	.back-link:hover { text-decoration: underline; }
	.page-title {
		font-weight: 800;
		font-size: 2rem;
		letter-spacing: -0.025em;
		line-height: 1.05;
		margin: 0;
		color: var(--ink);
	}
	.page-sub { font-size: 0.9rem; color: var(--ink-2); margin: 0.25rem 0 0; }
	.stat-chip { display: flex; flex-direction: column; align-items: flex-end; gap: 0.1rem; }
	.stat-num { font-size: 2rem; font-weight: 800; line-height: 1; color: var(--sec-handicap); }
	.stat-lbl { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--ink-2); }
	.muted { color: var(--ink-2); }
	.alert-error {
		border: 1px solid var(--accent);
		background: var(--paper-elevated);
		padding: 0.75rem 1rem;
		color: var(--accent);
	}
	.empty {
		border: 1px dashed var(--rule);
		padding: 2rem;
		text-align: center;
		color: var(--ink-2);
		background: var(--paper-elevated);
	}
</style>
