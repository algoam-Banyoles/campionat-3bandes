<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { effectiveIsAdmin } from '$lib/stores/viewMode';
	import { formatarNomJugadorParts } from '$lib/utils/playerUtils';

	const accions = [
		{ href: '/handicap/configuracio', label: 'Configuració', desc: 'Sistema, distàncies, horaris', icon: '⚙️' },
		{ href: '/handicap/inscripcions', label: 'Inscripcions', desc: 'Jugadors inscrits i disponibilitat', icon: '👥' },
		{ href: '/handicap/sorteig', label: 'Sorteig', desc: 'Assignar seeds i generar bracket', icon: '🎲' },
		{ href: '/handicap/partides', label: 'Partides', desc: 'Programar i gestionar partides', icon: '📅' },
		{ href: '/handicap/simulacio', label: 'Simulació', desc: 'Predir la data de finalització', icon: '🎯' }
	];

	const publicLinks = [
		{ href: '/handicap/calendari', label: 'Calendari de partides', desc: 'Vista setmanal de les partides programades', icon: '📅' },
		{ href: '/handicap/quadre', label: 'Brackets', desc: 'Quadre d\'eliminació doble', icon: '🏆' },
		{ href: '/handicap/jugadors', label: 'Jugadors inscrits', desc: 'Llista dels participants del torneig', icon: '👥' }
	];

	const BRACKET_LABEL_FULL: Record<string, string> = {
		winners: 'Bracket Principal',
		losers: 'Bracket Repesca',
		grand_final: 'Gran Final'
	};
	function bracketLabel(b: string): string {
		return BRACKET_LABEL_FULL[b] ?? b;
	}
	/** Format curt català: 'Dl 02 jul'. Replica el patró del MyUpcomingMatchesWidget. */
	function formatDateCa(d: string | null): string {
		if (!d) return '—';
		const dt = new Date(d);
		if (isNaN(dt.getTime())) return d;
		return dt.toLocaleDateString('ca-ES', {
			weekday: 'short',
			day: '2-digit',
			month: 'short'
		});
	}

	let participantsCount = 0;
	let bracketStats: { total: number; played: number; pending: number; scheduled: number } | null = null;

	interface RecentMatch {
		player1_name: string;
		player2_name: string;
		winner_name: string;
		bracket_type: string;
		ronda: number;
		data: string | null;
	}

	interface UpcomingMatch {
		player1_name: string;
		player2_name: string;
		bracket_type: string;
		ronda: number;
		data: string | null;
		hora: string | null;
	}

	let recentMatches: RecentMatch[] = [];
	let upcomingMatches: UpcomingMatch[] = [];
	let champion: string | null = null;

	interface HistoricalTournament {
		id: string;
		nom: string;
		championName: string | null;
		totalMatches: number;
	}
	let historicalTournaments: HistoricalTournament[] = [];

	onMount(async () => {
		const { data: ev } = await supabase
			.from('events')
			.select('id')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.limit(1)
			.single();

		if (!ev) return;

		const [{ count: pCount }, { data: matchStats }] = await Promise.all([
			supabase
				.from('handicap_participants')
				.select('*', { count: 'exact', head: true })
				.eq('event_id', ev.id),
			supabase
				.from('handicap_matches')
				.select('id, estat, slot1_id, slot2_id, guanyador_participant_id, calendari_partida_id')
				.eq('event_id', ev.id)
				.neq('estat', 'bye')
		]);

		participantsCount = pCount || 0;

		if (matchStats && matchStats.length > 0) {
			const played = matchStats.filter((m: any) => m.estat === 'jugada' || m.estat === 'walkover').length;
			const scheduled = matchStats.filter((m: any) => m.estat === 'programada').length;
			const pending = matchStats.filter((m: any) => m.estat === 'pendent').length;
			bracketStats = { total: matchStats.length, played, pending, scheduled };

			// Obtenir noms de participants per als últims 3 resultats i 3 propers
			const slotIds = matchStats.flatMap((m: any) => [m.slot1_id, m.slot2_id]);
			const calIds = (matchStats as any[]).filter((m) => m.calendari_partida_id).map((m: any) => m.calendari_partida_id as string);

			const [{ data: slots }, { data: calPartides }] = await Promise.all([
				supabase.from('handicap_bracket_slots').select('id, bracket_type, ronda, participant_id').in('id', slotIds),
				calIds.length > 0
					? supabase.from('calendari_partides').select('id, data_programada, hora_inici').in('id', calIds)
					: Promise.resolve({ data: [] })
			]);

			const slotMap = new Map((slots ?? []).map((s: any) => [s.id as string, s]));
			const calMap = new Map((calPartides ?? []).map((c: any) => [c.id as string, c]));

			const partIds = [...new Set((slots ?? []).filter((s: any) => s.participant_id).map((s: any) => s.participant_id as string))];
			// Fase 5c-S2b: lectura via FK directe `soci_numero → socis`
			const { data: parts } = await supabase
				.from('handicap_participants')
				.select('id, socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
				.in('id', partIds);
			const nameMap = new Map((parts ?? []).map((p: any) => {
				const s = Array.isArray(p.socis) ? p.socis[0] : p.socis;
				return [p.id as string, s ? formatarNomJugadorParts(s.nom, s.cognoms) || '?' : '?'];
			}));

			// Últimes 3 partides jugades
			const jugades = (matchStats as any[])
				.filter((m) => m.estat === 'jugada' || m.estat === 'walkover')
				.map((m) => {
					const s1 = slotMap.get(m.slot1_id);
					const s2 = slotMap.get(m.slot2_id);
					const cal = m.calendari_partida_id ? calMap.get(m.calendari_partida_id) : null;
					if (!s1 || !s2 || !m.guanyador_participant_id) return null;
					return {
						player1_name: nameMap.get(s1.participant_id) ?? '?',
						player2_name: nameMap.get(s2.participant_id) ?? '?',
						winner_name: nameMap.get(m.guanyador_participant_id) ?? '?',
						bracket_type: s1.bracket_type as string,
						ronda: s1.ronda as number,
						data: cal?.data_programada ? (cal.data_programada as string).substring(0, 10) : null
					} satisfies RecentMatch;
				})
				.filter(Boolean) as RecentMatch[];

			jugades.sort((a, b) => (b.data ?? '').localeCompare(a.data ?? ''));
			recentMatches = jugades.slice(0, 3);

			// Pròximes 3 programades
			const programades = (matchStats as any[])
				.filter((m) => m.estat === 'programada' && m.calendari_partida_id)
				.map((m) => {
					const s1 = slotMap.get(m.slot1_id);
					const s2 = slotMap.get(m.slot2_id);
					const cal = m.calendari_partida_id ? calMap.get(m.calendari_partida_id) : null;
					if (!s1 || !s2 || !cal) return null;
					return {
						player1_name: nameMap.get(s1.participant_id) ?? '?',
						player2_name: nameMap.get(s2.participant_id) ?? '?',
						bracket_type: s1.bracket_type as string,
						ronda: s1.ronda as number,
						data: (cal.data_programada as string)?.substring(0, 10) ?? null,
						hora: (cal.hora_inici as string)?.substring(0, 5) ?? null
					} satisfies UpcomingMatch;
				})
				.filter(Boolean) as UpcomingMatch[];

			programades.sort((a, b) => {
				const da = (a.data ?? '') + (a.hora ?? '');
				const db = (b.data ?? '') + (b.hora ?? '');
				return da.localeCompare(db);
			});
			// Pròximes partides: tots els partits dels 2 propers dies amb partides programades
			const distinctDays: string[] = [];
			for (const m of programades) {
				if (m.data && !distinctDays.includes(m.data)) {
					distinctDays.push(m.data);
					if (distinctDays.length === 2) break;
				}
			}
			upcomingMatches = programades.filter((m) => m.data && distinctDays.includes(m.data));

			// Campió: si totes les partides estan jugades i hi ha una GF jugada
			if (pending === 0 && scheduled === 0 && played > 0) {
				const gfMatch = (matchStats as any[]).find((m) => {
					const s1 = slotMap.get(m.slot1_id);
					return s1?.bracket_type === 'grand_final' && (m.estat === 'jugada' || m.estat === 'walkover') && m.guanyador_participant_id;
				});
				if (gfMatch) {
					champion = nameMap.get(gfMatch.guanyador_participant_id) ?? null;
				}
			}
		}

		// Torneigs anteriors finalitzats
		const { data: finishedEvents } = await supabase
			.from('events')
			.select('id, nom')
			.eq('tipus_competicio', 'handicap')
			.eq('estat_competicio', 'finalitzat')
			.order('creat_el', { ascending: false })
			.limit(10);

		if (finishedEvents && finishedEvents.length > 0) {
			const histItems: HistoricalTournament[] = [];
			for (const fe of finishedEvents) {
				// Comptar partides jugades
				const { count: mc } = await supabase
					.from('handicap_matches')
					.select('*', { count: 'exact', head: true })
					.eq('event_id', fe.id)
					.in('estat', ['jugada', 'walkover']);

				// Trobar campió (guanyador de la GF)
				const { data: gfSlots } = await supabase
					.from('handicap_bracket_slots')
					.select('id')
					.eq('event_id', fe.id)
					.eq('bracket_type', 'grand_final');

				let champName: string | null = null;
				if (gfSlots && gfSlots.length > 0) {
					const gfSlotIds = gfSlots.map((s: any) => s.id as string);
					const { data: gfMatch } = await supabase
						.from('handicap_matches')
						.select('guanyador_participant_id')
						.eq('event_id', fe.id)
						.in('slot1_id', gfSlotIds)
						.in('estat', ['jugada', 'walkover'])
						.order('id', { ascending: false })
						.limit(1)
						.maybeSingle();

					if (gfMatch?.guanyador_participant_id) {
						const { data: champ } = await supabase
							.from('handicap_participants')
							.select('socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
							.eq('id', gfMatch.guanyador_participant_id)
							.single();
						if (champ) {
							const s = (champ as any).socis;
							const sociObj = Array.isArray(s) ? s[0] : s;
							if (sociObj) champName = formatarNomJugadorParts(sociObj.nom, sociObj.cognoms);
						}
					}
				}

				histItems.push({ id: fe.id, nom: fe.nom, championName: champName, totalMatches: mc ?? 0 });
			}
			historicalTournaments = histItems;
		}
	});
</script>

<div class="hcap-root">
	<header class="page-mast">
		<div>
			<div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Hàndicap</div>
			<h1 class="page-title">Campionat Hàndicap · 3 Bandes</h1>
		</div>
	</header>

	{#if champion}
		<div class="mb-6 rounded-lg bg-yellow-100 border border-yellow-300 px-4 py-3 text-center">
			<div class="text-xs font-semibold uppercase text-yellow-600 mb-0.5">Campió del Torneig</div>
			<div class="text-lg font-bold text-yellow-900">🏆 {champion}</div>
		</div>
	{/if}

	<!-- Navegació pública -->
	<h2 class="mb-3 text-lg font-semibold text-gray-800">Consultar</h2>
	<div class="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
		{#each publicLinks as link}
			<a
				href={link.href}
				class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm transition-colors hover:border-purple-300 hover:bg-purple-50"
			>
				<div class="mb-1 text-2xl">{link.icon}</div>
				<div class="font-medium text-gray-900">{link.label}</div>
				<div class="text-xs text-gray-500">{link.desc}</div>
				{#if link.label === 'Jugadors inscrits' && participantsCount > 0}
					<div class="mt-1 text-xs font-semibold text-purple-700">{participantsCount} inscrits</div>
				{/if}
			</a>
		{/each}
	</div>

	{#if recentMatches.length > 0}
		<section class="ump-section">
			<header class="ump-head">
				<div class="editorial-eyebrow ump-eyebrow">Resultats</div>
				<h2 class="ump-title">Últims resultats</h2>
			</header>
			<ol class="ump-list">
				{#each recentMatches as m}
					<li class="ump-row">
						<div class="ump-date">
							<div class="ump-date-day tabular-nums">{formatDateCa(m.data)}</div>
						</div>
						<div class="ump-info">
							<div class="ump-opponent">
								<strong class="ump-winner">{m.winner_name}</strong> guanya
							</div>
							<div class="ump-meta">
								{m.player1_name} vs {m.player2_name} · {bracketLabel(m.bracket_type)} · Ronda {m.ronda}
							</div>
						</div>
					</li>
				{/each}
			</ol>
		</section>
	{/if}

	{#if upcomingMatches.length > 0}
		<section class="ump-section">
			<header class="ump-head">
				<div class="editorial-eyebrow ump-eyebrow">Pròximament</div>
				<h2 class="ump-title">Pròximes partides</h2>
			</header>
			<ol class="ump-list">
				{#each upcomingMatches as m}
					<li class="ump-row">
						<div class="ump-date">
							<div class="ump-date-day tabular-nums">{formatDateCa(m.data)}</div>
							{#if m.hora}
								<div class="ump-date-hour tabular-nums">{m.hora}</div>
							{/if}
						</div>
						<div class="ump-info">
							<div class="ump-opponent">
								<strong>{m.player1_name}</strong> vs <strong>{m.player2_name}</strong>
							</div>
							<div class="ump-meta">
								{bracketLabel(m.bracket_type)} · Ronda {m.ronda}
							</div>
						</div>
					</li>
				{/each}
			</ol>
		</section>
	{/if}

	{#if $effectiveIsAdmin}
		<!-- Quick actions -->
		<h2 class="mb-3 text-lg font-semibold text-gray-800">Accions</h2>
		<div class="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-3 lg:grid-cols-6">
			{#each accions as accio}
				<a
					href={accio.href}
					class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm transition-colors hover:border-purple-300 hover:bg-purple-50"
				>
					<div class="mb-1 text-2xl">{accio.icon}</div>
					<div class="font-medium text-gray-900">{accio.label}</div>
					<div class="text-xs text-gray-500">{accio.desc}</div>
					{#if accio.label === 'Inscripcions' && participantsCount > 0}
						<div class="mt-1 text-xs font-semibold text-purple-700">{participantsCount} inscrits</div>
					{/if}
				</a>
			{/each}
		</div>

		{/if}

	<!-- Torneigs anteriors -->
	{#if historicalTournaments.length > 0}
		<h2 class="mb-3 mt-8 text-lg font-semibold text-gray-800">Torneigs anteriors</h2>
		<div class="space-y-2">
			{#each historicalTournaments as ht}
				<div class="flex items-center gap-3 rounded-lg border border-gray-200 bg-white px-4 py-3 shadow-sm">
					<div class="text-xl">🏆</div>
					<div class="flex-1">
						<div class="font-medium text-gray-900">{ht.nom}</div>
						{#if ht.championName}
							<div class="text-xs text-yellow-700">Campió: {ht.championName}</div>
						{/if}
						<div class="text-xs text-gray-400">{ht.totalMatches} partides jugades</div>
					</div>
					<a
						href="/handicap/resum?event={ht.id}"
						class="rounded border border-purple-300 bg-purple-50 px-3 py-1 text-xs font-medium text-purple-700 hover:bg-purple-100"
					>
						Resum
					</a>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.hcap-root {
		max-width: 56rem;
		margin: 0 auto;
		padding: 1rem;
		display: flex; flex-direction: column; gap: 1.25rem;
		font-family: var(--font-sans); color: var(--ink);
	}
	.page-mast { padding-bottom: 1rem; border-bottom: 2px solid var(--ink); }
	.editorial-eyebrow {
		font-size: 0.75rem; font-weight: 600;
		letter-spacing: 0.16em; text-transform: uppercase;
		color: var(--sec-handicap);
	}
	.page-title {
		font-weight: 800; font-size: 2rem;
		letter-spacing: -0.025em; line-height: 1.05;
		margin: 0; color: var(--ink);
	}
	/* Tailwind overrides */
	.hcap-root :global(.bg-white),
	.hcap-root :global(.bg-purple-50),
	.hcap-root :global(.bg-blue-50),
	.hcap-root :global(.bg-yellow-50),
	.hcap-root :global(.bg-yellow-100),
	.hcap-root :global(.bg-green-50),
	.hcap-root :global(.bg-red-50),
	.hcap-root :global(.bg-gray-50),
	.hcap-root :global(.bg-slate-50) {
		background: var(--paper-elevated) !important;
		border: 1px solid var(--rule) !important;
		border-radius: 0 !important;
		box-shadow: none !important;
	}
	.hcap-root :global(.bg-yellow-100) {
		border-color: var(--amber) !important;
	}
	.hcap-root :global(.text-purple-700),
	.hcap-root :global(.text-purple-800),
	.hcap-root :global(.text-purple-900) {
		color: var(--sec-handicap) !important;
	}
	.hcap-root :global(.text-yellow-600),
	.hcap-root :global(.text-yellow-700),
	.hcap-root :global(.text-yellow-900),
	.hcap-root :global(.text-amber-700) {
		color: var(--amber) !important;
	}
	.hcap-root :global(.text-green-600),
	.hcap-root :global(.text-green-700),
	.hcap-root :global(.text-green-800) {
		color: var(--green) !important;
	}
	.hcap-root :global(.text-red-600),
	.hcap-root :global(.text-red-700),
	.hcap-root :global(.text-red-800) {
		color: var(--accent) !important;
	}
	.hcap-root :global(.text-gray-500),
	.hcap-root :global(.text-gray-600),
	.hcap-root :global(.text-slate-500),
	.hcap-root :global(.text-slate-600) {
		color: var(--ink-2) !important;
	}
	.hcap-root :global(.text-gray-900),
	.hcap-root :global(.text-slate-900) {
		color: var(--ink) !important;
	}
	.hcap-root :global(button.bg-purple-600),
	.hcap-root :global(button[class*="bg-purple"]) {
		background: var(--sec-handicap) !important;
		color: white !important;
		border: 1px solid var(--sec-handicap) !important;
		border-radius: 0 !important;
		font-weight: 600 !important;
	}
	.hcap-root :global(button.bg-blue-600),
	.hcap-root :global(button[class*="bg-blue-"]) {
		background: var(--ink) !important;
		color: var(--paper) !important;
		border: 1px solid var(--ink) !important;
		border-radius: 0 !important;
		font-weight: 600 !important;
	}
	.hcap-root :global(.rounded),
	.hcap-root :global(.rounded-lg),
	.hcap-root :global(.rounded-md),
	.hcap-root :global(.rounded-xl),
	.hcap-root :global(.rounded-full) { border-radius: 0 !important; }
	.hcap-root :global(.shadow),
	.hcap-root :global(.shadow-sm),
	.hcap-root :global(.shadow-md) { box-shadow: none !important; }
	.hcap-root :global(a) {
		color: var(--blue);
	}

	/* ── Properes partides: mateix format que MyUpcomingMatchesWidget ─── */
	.ump-section {
		margin-bottom: 2rem;
		padding: 1.25rem 1.4rem;
		background: var(--paper-elevated);
		border: 1px solid var(--rule);
		border-left: 3px solid var(--ink);
		font-family: var(--font-sans);
	}
	.ump-head { margin-bottom: 0.85rem; }
	.ump-eyebrow {
		font-size: 0.625rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.16em;
		color: var(--ink-3);
	}
	.ump-title {
		margin: 0.3rem 0 0;
		font-size: 1.125rem;
		font-weight: 800;
		letter-spacing: -0.012em;
		color: var(--ink);
	}
	.ump-list {
		list-style: none;
		margin: 0;
		padding: 0;
	}
	.ump-row {
		display: flex;
		align-items: flex-start;
		gap: 0.85rem;
		padding: 0.7rem 0;
		border-bottom: 1px solid var(--rule);
	}
	.ump-row:last-child { border-bottom: none; }
	.ump-date {
		min-width: 5.5rem;
		flex-shrink: 0;
	}
	.ump-date-day {
		font-size: 0.8125rem;
		font-weight: 700;
		color: var(--ink);
		text-transform: capitalize;
	}
	.ump-date-hour {
		font-size: 0.75rem;
		color: var(--ink-3);
	}
	.ump-info { flex: 1; min-width: 0; }
	.ump-opponent {
		font-size: 0.9375rem;
		color: var(--ink-2);
	}
	.ump-opponent strong { color: var(--ink); }
	.ump-opponent strong.ump-winner { color: var(--green); }
	.ump-meta {
		margin-top: 0.2rem;
		font-size: 0.8125rem;
		color: var(--ink-3);
	}
	.tabular-nums { font-variant-numeric: tabular-nums; }
</style>
