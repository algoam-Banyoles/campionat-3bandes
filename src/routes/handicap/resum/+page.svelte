<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { supabase } from '$lib/supabaseClient';

	export const ssr = false;

	// ── Estat ─────────────────────────────────────────────────────────────────

	let loading = true;
	let error: string | null = null;

	let event: any = null;
	let championName: string | null = null;
	let subchampionName: string | null = null;
	let championParticipantId: string | null = null;
	let subchampionParticipantId: string | null = null;

	interface MatchStat {
		id: string;
		bracket_type: string;
		ronda: number;
		player1_name: string;
		player2_name: string;
		winner_name: string;
		caramboles1: number | null;
		caramboles2: number | null;
		entrades: number | null;
		distancia1: number | null;
		distancia2: number | null;
		estat: string;
	}

	let matches: MatchStat[] = [];
	let totalPlayed = 0;
	let walkovers = 0;
	let bestAvgMatch: MatchStat | null = null;
	let tightestMatch: MatchStat | null = null;

	interface ChampionStep {
		bracket_type: string;
		ronda: number;
		opponent: string;
		result: string;
	}
	let championPath: ChampionStep[] = [];

	interface PlayerStat {
		name: string;
		wins: number;
		losses: number;
		totalCaramboles: number;
		totalEntrades: number;
	}
	let playerStats: PlayerStat[] = [];

	// ── Càrrega ───────────────────────────────────────────────────────────────

	onMount(async () => {
		const eventId = $page.url.searchParams.get('event');

		if (!eventId) {
			// Buscar l'event finalitzat més recent
			const { data: ev } = await supabase
				.from('events')
				.select('id, nom, estat_competicio')
				.eq('tipus_competicio', 'handicap')
				.eq('estat_competicio', 'finalitzat')
				.order('creat_el', { ascending: false })
				.limit(1)
				.maybeSingle();

			if (!ev) {
				error = 'No hi ha cap torneig finalitzat.';
				loading = false;
				return;
			}
			event = ev;
		} else {
			const { data: ev } = await supabase
				.from('events')
				.select('id, nom, estat_competicio')
				.eq('id', eventId)
				.single();
			if (!ev) {
				error = 'Event no trobat.';
				loading = false;
				return;
			}
			event = ev;
		}

		await loadData(event.id);
		loading = false;
	});

	async function loadData(eventId: string) {
		// 1. Participants
		const { data: parts } = await supabase
			.from('handicap_participants')
			.select('id, distancia, eliminat, players!inner(socis!inner(nom, cognoms))')
			.eq('event_id', eventId);

		const partMap = new Map(
			(parts ?? []).map((p: any) => [
				p.id as string,
				{
					name: `${p.players.socis.nom} ${p.players.socis.cognoms}`,
					distancia: p.distancia as number,
					eliminat: p.eliminat as boolean
				}
			])
		);

		// 2. Slots
		const { data: slots } = await supabase
			.from('handicap_bracket_slots')
			.select('id, bracket_type, ronda, participant_id')
			.eq('event_id', eventId);

		const slotMap = new Map((slots ?? []).map((s: any) => [s.id as string, s]));

		// 3. Matches jugades
		const { data: rawMatches } = await supabase
			.from('handicap_matches')
			.select('id, slot1_id, slot2_id, estat, guanyador_participant_id, calendari_partida_id')
			.eq('event_id', eventId)
			.in('estat', ['jugada', 'walkover']);

		if (!rawMatches) return;

		// 4. Calendari (per caramboles/entrades)
		const calIds = rawMatches.filter((m: any) => m.calendari_partida_id).map((m: any) => m.calendari_partida_id as string);
		let calMap = new Map<string, any>();
		if (calIds.length > 0) {
			const { data: cals } = await supabase
				.from('calendari_partides')
				.select('id, caramboles_jugador1, caramboles_jugador2, entrades')
				.in('id', calIds);
			calMap = new Map((cals ?? []).map((c: any) => [c.id as string, c]));
		}

		// 5. Construir estadístiques
		const statsMap = new Map<string, PlayerStat>();

		matches = rawMatches.map((m: any) => {
			const s1 = slotMap.get(m.slot1_id);
			const s2 = slotMap.get(m.slot2_id);
			const p1 = s1?.participant_id ? partMap.get(s1.participant_id) : null;
			const p2 = s2?.participant_id ? partMap.get(s2.participant_id) : null;
			const cal = m.calendari_partida_id ? calMap.get(m.calendari_partida_id) : null;
			const winner = m.guanyador_participant_id ? partMap.get(m.guanyador_participant_id) : null;

			const stat: MatchStat = {
				id: m.id,
				bracket_type: (s1?.bracket_type ?? 'winners') as string,
				ronda: (s1?.ronda ?? 1) as number,
				player1_name: p1?.name ?? '?',
				player2_name: p2?.name ?? '?',
				winner_name: winner?.name ?? '?',
				caramboles1: cal?.caramboles_jugador1 ?? null,
				caramboles2: cal?.caramboles_jugador2 ?? null,
				entrades: cal?.entrades ?? null,
				distancia1: p1?.distancia ?? null,
				distancia2: p2?.distancia ?? null,
				estat: m.estat as string
			};

			// Acumular estadístiques de jugadors
			if (s1?.participant_id && p1) {
				const ps = statsMap.get(s1.participant_id) ?? { name: p1.name, wins: 0, losses: 0, totalCaramboles: 0, totalEntrades: 0 };
				if (m.guanyador_participant_id === s1.participant_id) ps.wins++; else ps.losses++;
				if (cal?.caramboles_jugador1) ps.totalCaramboles += cal.caramboles_jugador1;
				if (cal?.entrades) ps.totalEntrades += cal.entrades;
				statsMap.set(s1.participant_id, ps);
			}
			if (s2?.participant_id && p2) {
				const ps = statsMap.get(s2.participant_id) ?? { name: p2.name, wins: 0, losses: 0, totalCaramboles: 0, totalEntrades: 0 };
				if (m.guanyador_participant_id === s2.participant_id) ps.wins++; else ps.losses++;
				if (cal?.caramboles_jugador2) ps.totalCaramboles += cal.caramboles_jugador2;
				if (cal?.entrades) ps.totalEntrades += cal.entrades;
				statsMap.set(s2.participant_id, ps);
			}

			return stat;
		});

		totalPlayed = matches.length;
		walkovers = matches.filter((m) => m.estat === 'walkover').length;

		// Millor % mig (caramboles/distancia)
		const withScores = matches.filter((m) => m.entrades && m.entrades > 0 && m.caramboles1 !== null && m.caramboles2 !== null);
		if (withScores.length > 0) {
			bestAvgMatch = withScores.reduce((best, m) => {
				const avg = ((m.caramboles1 ?? 0) + (m.caramboles2 ?? 0)) / (m.entrades ?? 1);
				const bestAvg = ((best.caramboles1 ?? 0) + (best.caramboles2 ?? 0)) / (best.entrades ?? 1);
				return avg > bestAvg ? m : best;
			});

			// Partida més ajustada (diferència de % mínima entre els dos jugadors)
			tightestMatch = withScores.reduce((tightest, m) => {
				const diff = Math.abs(
					((m.distancia1 ?? 0) > 0 ? (m.caramboles1 ?? 0) / m.distancia1! : 0) -
					((m.distancia2 ?? 0) > 0 ? (m.caramboles2 ?? 0) / m.distancia2! : 0)
				);
				const tDiff = Math.abs(
					((tightest.distancia1 ?? 0) > 0 ? (tightest.caramboles1 ?? 0) / tightest.distancia1! : 0) -
					((tightest.distancia2 ?? 0) > 0 ? (tightest.caramboles2 ?? 0) / tightest.distancia2! : 0)
				);
				return diff < tDiff ? m : tightest;
			});
		}

		playerStats = [...statsMap.values()].sort((a, b) => b.wins - a.wins);

		// 6. Determinar campió (jugador no eliminat o amb més victòries)
		const notElim = [...partMap.entries()].filter(([, v]) => !v.eliminat);
		if (notElim.length === 1) {
			championParticipantId = notElim[0][0];
			championName = notElim[0][1].name;
		} else if (notElim.length > 1) {
			// Trobar qui va guanyar la gran final
			const gfMatch = rawMatches.find((m: any) => {
				const s1 = slotMap.get(m.slot1_id);
				return s1?.bracket_type === 'grand_final';
			});
			if (gfMatch) {
				const winnerId = gfMatch.guanyador_participant_id as string | null;
				if (winnerId) {
					championParticipantId = winnerId;
					championName = partMap.get(winnerId)?.name ?? null;
					// Subcampió = l'altre participant de la última GF
					const s1 = slotMap.get(gfMatch.slot1_id);
					const s2 = slotMap.get(gfMatch.slot2_id);
					const loserId = s1?.participant_id === winnerId ? s2?.participant_id : s1?.participant_id;
					if (loserId) {
						subchampionParticipantId = loserId as string;
						subchampionName = partMap.get(loserId as string)?.name ?? null;
					}
				}
			}
		}

		// 7. Camí del campió
		if (championParticipantId) {
			const champMatches = matches.filter(
				(m) => m.winner_name === (championName ?? '') || (m.player1_name === (championName ?? '') && m.winner_name === (championName ?? '')) || (m.player2_name === (championName ?? '') && m.winner_name === (championName ?? ''))
			);
			// Use participant_id for more accuracy
			championPath = rawMatches
				.filter((m: any) => m.guanyador_participant_id === championParticipantId)
				.map((m: any) => {
					const s1 = slotMap.get(m.slot1_id);
					const s2 = slotMap.get(m.slot2_id);
					const p1 = s1?.participant_id ? partMap.get(s1.participant_id) : null;
					const p2 = s2?.participant_id ? partMap.get(s2.participant_id) : null;
					const opponent = s1?.participant_id === championParticipantId ? p2?.name : p1?.name;
					const cal = m.calendari_partida_id ? calMap.get(m.calendari_partida_id) : null;

					let result = m.estat === 'walkover' ? 'W.O.' : '';
					if (cal && cal.caramboles_jugador1 !== null && cal.caramboles_jugador2 !== null) {
						const champCar = s1?.participant_id === championParticipantId ? cal.caramboles_jugador1 : cal.caramboles_jugador2;
						const oppCar = s1?.participant_id === championParticipantId ? cal.caramboles_jugador2 : cal.caramboles_jugador1;
						result = `${champCar} - ${oppCar}`;
					}

					return {
						bracket_type: s1?.bracket_type ?? 'winners',
						ronda: s1?.ronda ?? 1,
						opponent: opponent ?? '?',
						result
					} as ChampionStep;
				})
				.sort((a: ChampionStep, b: ChampionStep) => {
					const btOrder: Record<string, number> = { winners: 0, losers: 1, grand_final: 2 };
					if (a.bracket_type !== b.bracket_type) return (btOrder[a.bracket_type] ?? 3) - (btOrder[b.bracket_type] ?? 3);
					return a.ronda - b.ronda;
				});
		}
	}

	function bracketLabel(bt: string): string {
		if (bt === 'winners') return 'Guanyadors';
		if (bt === 'losers') return 'Perdedors';
		return 'Gran Final';
	}

	function roundLabel(bt: string, r: number): string {
		if (bt === 'grand_final') return r === 1 ? 'Final' : 'Reset';
		return `R${r}`;
	}

	function pct(car: number | null, distancia: number | null): string {
		if (!car || !distancia || distancia === 0) return '—';
		return (car / distancia * 100).toFixed(1) + '%';
	}

	function avgPerEntrada(car: number | null, entrades: number | null): string {
		if (!car || !entrades || entrades === 0) return '—';
		return (car / entrades).toFixed(3);
	}
</script>

<div class="mx-auto max-w-4xl p-4">
	<!-- Capçalera -->
	<div class="mb-4 flex items-center gap-3">
		<a href="/handicap" class="text-sm text-purple-600 hover:underline">← Hàndicap</a>
		<h1 class="text-2xl font-bold text-gray-900">Resum del torneig</h1>
	</div>

	{#if loading}
		<p class="text-gray-500">Carregant...</p>
	{:else if error}
		<div class="rounded border border-red-300 bg-red-50 p-4 text-red-800">{error}</div>
	{:else}
		<!-- Nom del torneig -->
		{#if event}
			<p class="mb-4 text-lg font-semibold text-gray-700">{event.nom}</p>
		{/if}

		<!-- ── Banner campió ──────────────────────────────────────────── -->
		{#if championName}
			<div class="mb-6 rounded-xl border-2 border-yellow-400 bg-gradient-to-br from-yellow-50 to-amber-100 p-8 text-center shadow-xl">
				<div class="text-6xl">🏆</div>
				<h2 class="mt-3 text-3xl font-bold text-yellow-800">{championName}</h2>
				<p class="mt-1 text-base font-medium text-yellow-700">Campió del torneig</p>
				{#if subchampionName}
					<p class="mt-2 text-sm text-yellow-600">🥈 Subcampió: <span class="font-semibold">{subchampionName}</span></p>
				{/if}
			</div>
		{/if}

		<!-- ── Estadístiques globals ──────────────────────────────────── -->
		<div class="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
			<div class="rounded-lg border border-gray-200 bg-white p-4 text-center shadow-sm">
				<div class="text-2xl font-bold text-gray-800">{totalPlayed}</div>
				<div class="text-xs text-gray-500">Partides jugades</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4 text-center shadow-sm">
				<div class="text-2xl font-bold text-amber-600">{walkovers}</div>
				<div class="text-xs text-gray-500">Walkovers</div>
			</div>
			{#if bestAvgMatch}
				<div class="rounded-lg border border-blue-200 bg-blue-50 p-4 text-center shadow-sm col-span-2">
					<div class="text-xs font-semibold text-blue-700 mb-1">Millor promig (caramboles totals / entrades)</div>
					<div class="text-sm font-bold text-blue-800">
						{bestAvgMatch.player1_name} vs {bestAvgMatch.player2_name}
					</div>
					<div class="text-xs text-blue-600">
						{bestAvgMatch.caramboles1} + {bestAvgMatch.caramboles2} en {bestAvgMatch.entrades} entrades
						= {(((bestAvgMatch.caramboles1 ?? 0) + (bestAvgMatch.caramboles2 ?? 0)) / (bestAvgMatch.entrades ?? 1)).toFixed(3)} avg
					</div>
				</div>
			{/if}
		</div>

		<!-- ── Camí del campió ────────────────────────────────────────── -->
		{#if championPath.length > 0}
			<div class="mb-6 rounded-lg border border-yellow-200 bg-white shadow-sm">
				<div class="border-b border-yellow-100 bg-yellow-50 px-4 py-3">
					<h3 class="font-semibold text-yellow-800">👑 Camí del campió — {championName}</h3>
				</div>
				<div class="divide-y divide-gray-50">
					{#each championPath as step}
						<div class="flex items-center gap-3 px-4 py-3 text-sm">
							<span class="w-28 shrink-0 text-xs">
								<span class="rounded px-1.5 py-0.5 {step.bracket_type === 'winners' ? 'bg-blue-100 text-blue-700' : step.bracket_type === 'losers' ? 'bg-orange-100 text-orange-700' : 'bg-purple-100 text-purple-700'}">
									{bracketLabel(step.bracket_type)} {roundLabel(step.bracket_type, step.ronda)}
								</span>
							</span>
							<span class="flex-1 text-gray-700">vs <span class="font-medium">{step.opponent}</span></span>
							{#if step.result}
								<span class="shrink-0 font-mono text-sm font-semibold text-green-700">{step.result}</span>
							{/if}
						</div>
					{/each}
				</div>
			</div>
		{/if}

		<!-- ── Estadístiques per jugador ─────────────────────────────── -->
		{#if playerStats.length > 0}
			<div class="mb-6 rounded-lg border border-gray-200 bg-white shadow-sm">
				<div class="border-b border-gray-100 bg-gray-50 px-4 py-3">
					<h3 class="font-semibold text-gray-800">Estadístiques per jugador</h3>
				</div>
				<div class="overflow-x-auto">
					<table class="w-full text-sm">
						<thead>
							<tr class="border-b border-gray-100 text-xs text-gray-500">
								<th class="px-4 py-2 text-left">Jugador</th>
								<th class="px-4 py-2 text-center">V</th>
								<th class="px-4 py-2 text-center">D</th>
								<th class="px-4 py-2 text-center">Car. totals</th>
								<th class="px-4 py-2 text-center">Ent. totals</th>
								<th class="px-4 py-2 text-center">Avg</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-50">
							{#each playerStats as ps}
								<tr class="{ps.name === championName ? 'bg-yellow-50' : 'hover:bg-gray-50/50'}">
									<td class="px-4 py-2 font-medium text-gray-900">
										{#if ps.name === championName}
											<span class="mr-1">👑</span>
										{/if}
										{ps.name}
									</td>
									<td class="px-4 py-2 text-center font-semibold text-green-700">{ps.wins}</td>
									<td class="px-4 py-2 text-center text-red-600">{ps.losses}</td>
									<td class="px-4 py-2 text-center">{ps.totalCaramboles || '—'}</td>
									<td class="px-4 py-2 text-center">{ps.totalEntrades || '—'}</td>
									<td class="px-4 py-2 text-center font-mono">
										{avgPerEntrada(ps.totalCaramboles, ps.totalEntrades)}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}

		<!-- ── Totes les partides ─────────────────────────────────────── -->
		{#if matches.length > 0}
			<div class="rounded-lg border border-gray-200 bg-white shadow-sm">
				<div class="border-b border-gray-100 bg-gray-50 px-4 py-3">
					<h3 class="font-semibold text-gray-800">Totes les partides ({matches.length})</h3>
				</div>
				<div class="overflow-x-auto">
					<table class="w-full text-sm">
						<thead>
							<tr class="border-b border-gray-100 text-xs text-gray-500">
								<th class="px-3 py-2 text-left w-24">Bracket</th>
								<th class="px-3 py-2 text-left">Jugador 1</th>
								<th class="px-3 py-2 text-center w-8">vs</th>
								<th class="px-3 py-2 text-left">Jugador 2</th>
								<th class="px-3 py-2 text-center">Resultat</th>
								<th class="px-3 py-2 text-center">Guanyador</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-50">
							{#each matches as m}
								<tr class="hover:bg-gray-50/50">
									<td class="px-3 py-2">
										<span class="rounded px-1.5 py-0.5 text-xs font-bold {m.bracket_type === 'winners' ? 'bg-blue-100 text-blue-700' : m.bracket_type === 'losers' ? 'bg-orange-100 text-orange-700' : 'bg-purple-100 text-purple-700'}">
											{bracketLabel(m.bracket_type).charAt(0)}-{roundLabel(m.bracket_type, m.ronda)}
										</span>
									</td>
									<td class="px-3 py-2 {m.winner_name === m.player1_name ? 'font-semibold text-green-700' : 'text-gray-600'}">
										{m.player1_name}
										{#if m.distancia1}
											<span class="text-xs text-gray-400 ml-1">({m.distancia1}c)</span>
										{/if}
									</td>
									<td class="px-1 py-2 text-center text-xs text-gray-400">vs</td>
									<td class="px-3 py-2 {m.winner_name === m.player2_name ? 'font-semibold text-green-700' : 'text-gray-600'}">
										{m.player2_name}
										{#if m.distancia2}
											<span class="text-xs text-gray-400 ml-1">({m.distancia2}c)</span>
										{/if}
									</td>
									<td class="px-3 py-2 text-center font-mono text-xs">
										{#if m.estat === 'walkover'}
											<span class="text-amber-600">W.O.</span>
										{:else if m.caramboles1 !== null && m.caramboles2 !== null}
											{m.caramboles1} – {m.caramboles2}{#if m.entrades} ({m.entrades}e){/if}
										{:else}
											—
										{/if}
									</td>
									<td class="px-3 py-2 text-center text-xs font-semibold text-green-700">
										{m.winner_name}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}
	{/if}
</div>
