<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { isAdmin } from '$lib/stores/adminAuth';

	const accions = [
		{ href: '/handicap/configuracio', label: 'Configuració', desc: 'Sistema, distàncies, horaris', icon: '⚙️' },
		{ href: '/handicap/inscripcions', label: 'Inscripcions', desc: 'Jugadors inscrits i disponibilitat', icon: '👥' },
		{ href: '/handicap/sorteig', label: 'Sorteig', desc: 'Assignar seeds i generar bracket', icon: '🎲' },
		{ href: '/handicap/partides', label: 'Partides', desc: 'Programar i gestionar partides', icon: '📅' }
	];

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
			const { data: parts } = await supabase
				.from('handicap_participants')
				.select('id, players!inner(socis!inner(nom, cognoms))')
				.in('id', partIds);
			const nameMap = new Map((parts ?? []).map((p: any) => [p.id as string, `${p.players.socis.nom} ${p.players.socis.cognoms}`]));

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
			upcomingMatches = programades.slice(0, 3);

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
							.select('players!inner(socis!inner(nom, cognoms))')
							.eq('id', gfMatch.guanyador_participant_id)
							.single();
						if (champ) {
							const s = (champ as any).players.socis;
							champName = `${s.nom} ${s.cognoms}`;
						}
					}
				}

				histItems.push({ id: fe.id, nom: fe.nom, championName: champName, totalMatches: mc ?? 0 });
			}
			historicalTournaments = histItems;
		}
	});
</script>

<div class="mx-auto max-w-3xl p-4">
	<h1 class="mb-6 text-2xl font-bold text-gray-900">Campionat Handicap 3 Bandes</h1>

	<div class="mb-6 rounded-lg border border-purple-200 bg-white p-4 shadow-sm">
		<h2 class="mb-1 text-lg font-semibold text-purple-800">Eliminacio doble</h2>
		<p class="text-sm text-gray-600">
			Bracket de guanyadors + bracket de perdedors + gran final amb possible reset match.
		</p>
		{#if participantsCount > 0}
			<p class="mt-2 text-sm font-semibold text-purple-700">{participantsCount} jugador{participantsCount !== 1 ? 's' : ''} inscrit{participantsCount !== 1 ? 's' : ''}</p>
		{/if}
		{#if champion}
			<div class="mt-3 rounded-lg bg-yellow-100 border border-yellow-300 px-4 py-3 text-center">
				<div class="text-xs font-semibold uppercase text-yellow-600 mb-0.5">Campió del Torneig</div>
				<div class="text-lg font-bold text-yellow-900">🏆 {champion}</div>
			</div>
		{/if}

		{#if bracketStats}
			<div class="mt-3 flex flex-wrap gap-4 text-sm">
				<span class="text-gray-600"><span class="font-semibold text-green-700">{bracketStats.played}</span>/{bracketStats.total} jugades</span>
				<span class="text-gray-600"><span class="font-semibold text-blue-700">{bracketStats.scheduled}</span> programades</span>
				<span class="text-gray-600"><span class="font-semibold text-gray-500">{bracketStats.pending}</span> pendents</span>
			</div>
			<div class="mt-2 flex gap-3">
				<a href="/handicap/quadre" class="text-xs font-medium text-purple-600 hover:underline">Veure quadre →</a>
				{#if bracketStats.pending > 0 || bracketStats.scheduled > 0}
					<a href="/handicap/partides" class="text-xs font-medium text-blue-600 hover:underline">Gestionar partides →</a>
				{/if}
				<a href="/handicap/historial" class="text-xs font-medium text-green-600 hover:underline">Historial →</a>
			</div>
		{/if}

		{#if recentMatches.length > 0}
			<div class="mt-4 border-t border-purple-100 pt-3">
				<div class="text-xs font-semibold uppercase text-purple-600 mb-2">Últims resultats</div>
				<div class="space-y-1.5">
					{#each recentMatches as m}
						<div class="flex items-center gap-2 text-xs">
							<span class="font-medium text-green-700">{m.winner_name}</span>
							<span class="text-gray-400">guanya ·</span>
							<span class="text-gray-500">{m.player1_name.split(' ')[0]} vs {m.player2_name.split(' ')[0]}</span>
						</div>
					{/each}
				</div>
			</div>
		{/if}

		{#if upcomingMatches.length > 0}
			<div class="mt-4 border-t border-purple-100 pt-3">
				<div class="text-xs font-semibold uppercase text-purple-600 mb-2">Pròximes partides</div>
				<div class="space-y-1.5">
					{#each upcomingMatches as m}
						<div class="flex items-center gap-2 text-xs">
							<span class="text-gray-500">{m.data ? m.data.substring(8) + '/' + m.data.substring(5, 7) : '—'}{m.hora ? ' ' + m.hora : ''}</span>
							<span class="text-gray-700">{m.player1_name.split(' ')[0]} vs {m.player2_name.split(' ')[0]}</span>
						</div>
					{/each}
				</div>
			</div>
		{/if}
	</div>

	{#if $isAdmin}
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
