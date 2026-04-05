<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { buildMatchCodeMap } from '$lib/utils/handicap-types';

	// ── Tipus ─────────────────────────────────────────────────────────────────

	interface HistorialEntry {
		match_id: string;
		matchCode: string;
		bracket_type: 'winners' | 'losers' | 'grand_final';
		ronda: number;
		data_jugada: string | null; // 'YYYY-MM-DD'
		player1_name: string;
		player2_name: string;
		player1_participant_id: string;
		player2_participant_id: string;
		distancia1: number | null;
		distancia2: number | null;
		caramboles1: number | null;
		caramboles2: number | null;
		entrades: number | null;
		guanyador_participant_id: string;
		estat: 'jugada' | 'walkover';
	}

	// ── Estat ─────────────────────────────────────────────────────────────────

	let loading = true;
	let error: string | null = null;
	let entries: HistorialEntry[] = [];
	let searchPlayer = '';

	// ── Filtres ───────────────────────────────────────────────────────────────

	$: filteredEntries = entries.filter((e) => {
		if (!searchPlayer.trim()) return true;
		const q = searchPlayer.toLowerCase();
		return e.player1_name.toLowerCase().includes(q) || e.player2_name.toLowerCase().includes(q);
	});

	// ── Estadístiques globals ──────────────────────────────────────────────────

	interface PlayerStat {
		participant_id: string;
		name: string;
		wins: number;
		matches: number;
		totalCaramboles: number;
		totalDist: number;
		totalEntrades: number;
	}

	$: playerStats = (() => {
		const map = new Map<string, PlayerStat>();

		for (const e of entries) {
			if (e.estat === 'walkover') continue; // no comptem walkover per estadístiques de %

			for (const side of [1, 2] as const) {
				const pid = side === 1 ? e.player1_participant_id : e.player2_participant_id;
				const name = side === 1 ? e.player1_name : e.player2_name;
				const car = side === 1 ? e.caramboles1 : e.caramboles2;
				const dist = side === 1 ? e.distancia1 : e.distancia2;

				if (!map.has(pid)) map.set(pid, { participant_id: pid, name, wins: 0, matches: 0, totalCaramboles: 0, totalDist: 0, totalEntrades: 0 });
				const s = map.get(pid)!;
				s.matches++;
				if (e.guanyador_participant_id === pid) s.wins++;
				if (car !== null) s.totalCaramboles += car;
				if (dist !== null) s.totalDist += dist;
				if (e.entrades !== null) s.totalEntrades += e.entrades;
			}
		}

		return [...map.values()].sort((a, b) => b.wins - a.wins || b.matches - a.matches);
	})();

	$: bestPct = (() => {
		const jugades = entries.filter((e) => e.estat === 'jugada' && e.caramboles1 !== null && e.caramboles2 !== null && e.entrades !== null && e.entrades > 0);
		if (jugades.length === 0) return null;
		let best: HistorialEntry | null = null;
		let bestVal = -1;
		for (const e of jugades) {
			const pct1 = e.caramboles1! / (e.distancia1 ?? e.caramboles1! + 1);
			const pct2 = e.caramboles2! / (e.distancia2 ?? e.caramboles2! + 1);
			if (pct1 > bestVal) { bestVal = pct1; best = e; }
			if (pct2 > bestVal) { bestVal = pct2; best = e; }
		}
		return best;
	})();

	$: bestMitjana = (() => {
		const jugades = entries.filter((e) => e.estat === 'jugada' && e.entrades && e.entrades > 0);
		if (jugades.length === 0) return null;
		let best: HistorialEntry | null = null;
		let bestVal = 0;
		for (const e of jugades) {
			// Guanyador: millor mitjana = guanyador
			const winCar = e.guanyador_participant_id === e.player1_participant_id ? e.caramboles1 : e.caramboles2;
			if (winCar && e.entrades) {
				const avg = winCar / e.entrades;
				if (avg > bestVal) { bestVal = avg; best = e; }
			}
		}
		return best;
	})();

	$: tigthestMatch = (() => {
		const jugades = entries.filter((e) => e.estat === 'jugada' && e.caramboles1 !== null && e.caramboles2 !== null && e.distancia1 && e.distancia2);
		if (jugades.length === 0) return null;
		let closest: HistorialEntry | null = null;
		let closestDiff = Infinity;
		for (const e of jugades) {
			const pct1 = e.caramboles1! / e.distancia1!;
			const pct2 = e.caramboles2! / e.distancia2!;
			const diff = Math.abs(pct1 - pct2);
			if (diff < closestDiff) { closestDiff = diff; closest = e; }
		}
		return closest;
	})();

	// ── Helpers ───────────────────────────────────────────────────────────────

	const BRACKET_LABELS: Record<string, string> = {
		winners: 'Guanyadors',
		losers: 'Perdedors',
		grand_final: 'Gran Final'
	};
	const BRACKET_COLORS: Record<string, string> = {
		winners: 'bg-blue-100 text-blue-700',
		losers: 'bg-orange-100 text-orange-700',
		grand_final: 'bg-purple-100 text-purple-700'
	};

	function pct(car: number | null, dist: number | null): string {
		if (!car || !dist) return '—';
		return `${Math.round((car / dist) * 100)}%`;
	}

	function formatData(d: string | null): string {
		if (!d) return '—';
		const [y, m, day] = d.split('-');
		return `${day}/${m}/${y}`;
	}

	function winnerName(e: HistorialEntry): string {
		return e.guanyador_participant_id === e.player1_participant_id ? e.player1_name : e.player2_name;
	}

	// ── Càrrega de dades ──────────────────────────────────────────────────────

	onMount(async () => {
		const { data: ev } = await supabase
			.from('events')
			.select('id')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.limit(1)
			.single();

		if (!ev) {
			error = 'No hi ha cap event hàndicap actiu.';
			loading = false;
			return;
		}

		// Carregar matches jugats (no bye, no pendent)
		const { data: matches, error: mErr } = await supabase
			.from('handicap_matches')
			.select('id, estat, slot1_id, slot2_id, guanyador_participant_id, distancia_jugador1, distancia_jugador2, calendari_partida_id')
			.eq('event_id', ev.id)
			.neq('estat', 'pendent'); // inclou byes i jugades per codi

		if (mErr || !matches) {
			error = mErr?.message ?? 'Error carregant historial';
			loading = false;
			return;
		}

		if (matches.length === 0) {
			loading = false;
			return;
		}

		// Slots (per bracket_type i ronda)
		const slotIds = matches.flatMap((m: any) => [m.slot1_id, m.slot2_id]);
		const { data: slots } = await supabase
			.from('handicap_bracket_slots')
			.select('id, bracket_type, ronda, posicio, participant_id')
			.in('id', slotIds);
		const slotMap = new Map((slots ?? []).map((s: any) => [s.id as string, s]));
		// Calcular codis de partida des de tots els matches
		const codeInputs = (matches as any[]).map((m) => {
			const s = slotMap.get(m.slot1_id);
			return { id: m.id as string, bracket_type: (s?.bracket_type ?? 'winners') as string, ronda: (s?.ronda ?? 1) as number, matchPos: s ? Math.ceil((s.posicio as number) / 2) : 0 };
		});
		const codeMap = buildMatchCodeMap(codeInputs);

		// Participants
		const participantIds = [
			...new Set(
				(slots ?? [])
					.filter((s: any) => s.participant_id)
					.map((s: any) => s.participant_id as string)
			)
		];
		const { data: parts } = await supabase
			.from('handicap_participants')
			.select('id, players!inner(socis!inner(nom, cognoms))')
			.in('id', participantIds);
		const nameMap = new Map(
			(parts ?? []).map((p: any) => [
				p.id as string,
				`${p.players.socis.nom} ${p.players.socis.cognoms}`
			])
		);

		// Calendari_partides (per data i caramboles)
		const calIds = matches.filter((m: any) => m.calendari_partida_id).map((m: any) => m.calendari_partida_id as string);
		const { data: calPartides } = await supabase
			.from('calendari_partides')
			.select('id, data_programada, caramboles_jugador1, caramboles_jugador2, entrades')
			.in('id', calIds);
		const calMap = new Map((calPartides ?? []).map((c: any) => [c.id as string, c]));

		// Construir historial
		entries = (matches as any[])
			.map((m) => {
				const s1 = slotMap.get(m.slot1_id);
				const s2 = slotMap.get(m.slot2_id);
				if (!s1 || !s2) return null;
				const cal = m.calendari_partida_id ? calMap.get(m.calendari_partida_id) : null;

				const dataProgramada = cal?.data_programada
					? (cal.data_programada as string).substring(0, 10)
					: null;

				return {
					match_id: m.id as string,
					bracket_type: s1.bracket_type as HistorialEntry['bracket_type'],
					ronda: s1.ronda as number,
					data_jugada: dataProgramada,
					player1_participant_id: s1.participant_id as string,
					player2_participant_id: s2.participant_id as string,
					player1_name: nameMap.get(s1.participant_id) ?? 'Desconegut',
					player2_name: nameMap.get(s2.participant_id) ?? 'Desconegut',
					distancia1: m.distancia_jugador1 as number | null,
					distancia2: m.distancia_jugador2 as number | null,
					caramboles1: cal?.caramboles_jugador1 as number | null ?? null,
					caramboles2: cal?.caramboles_jugador2 as number | null ?? null,
					entrades: cal?.entrades as number | null ?? null,
					guanyador_participant_id: m.guanyador_participant_id as string,
					estat: m.estat as HistorialEntry['estat'],
					matchCode: codeMap.get(m.id as string) ?? ''
				} satisfies HistorialEntry;
			})
			.filter((e): e is HistorialEntry => e !== null && (e.estat === 'jugada' || e.estat === 'walkover'));

		// Ordenar per data (descendent) i bracket
		entries.sort((a, b) => {
			if (a.data_jugada && b.data_jugada) {
				return b.data_jugada.localeCompare(a.data_jugada);
			}
			if (a.data_jugada) return -1;
			if (b.data_jugada) return 1;
			return 0;
		});

		loading = false;
	});
</script>

<div class="mx-auto max-w-4xl p-4">
	<div class="mb-4 flex items-center gap-3">
		<a href="/handicap" class="text-sm text-purple-600 hover:underline">← Hàndicap</a>
		<h1 class="text-2xl font-bold text-gray-900">Historial de Resultats</h1>
	</div>

	{#if loading}
		<p class="text-gray-500">Carregant...</p>
	{:else if error}
		<div class="rounded border border-red-300 bg-red-50 p-4 text-red-800">{error}</div>
	{:else if entries.length === 0}
		<div class="rounded border border-gray-200 bg-white p-8 text-center text-sm text-gray-500">
			Encara no hi ha partides jugades.
		</div>
	{:else}
		<!-- ── Estadístiques globals ─────────────────────────────────────────── -->
		<div class="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
			{#if bestMitjana}
				<div class="rounded border border-amber-200 bg-amber-50 p-4 shadow-sm">
					<div class="text-xs font-semibold uppercase text-amber-600 mb-1">Millor Mitjana</div>
					<div class="text-sm font-bold text-amber-900">
						{winnerName(bestMitjana)}
					</div>
					<div class="text-xs text-amber-700">
						{bestMitjana.guanyador_participant_id === bestMitjana.player1_participant_id
							? bestMitjana.caramboles1
							: bestMitjana.caramboles2} car. / {bestMitjana.entrades} ent.
					</div>
				</div>
			{/if}

			{#if tigthestMatch}
				<div class="rounded border border-blue-200 bg-blue-50 p-4 shadow-sm">
					<div class="text-xs font-semibold uppercase text-blue-600 mb-1">Partida Més Ajustada</div>
					<div class="text-sm font-bold text-blue-900">
						{tigthestMatch.player1_name.split(' ')[0]} vs {tigthestMatch.player2_name.split(' ')[0]}
					</div>
					<div class="text-xs text-blue-700">
						{pct(tigthestMatch.caramboles1, tigthestMatch.distancia1)} vs {pct(tigthestMatch.caramboles2, tigthestMatch.distancia2)}
					</div>
				</div>
			{/if}

			<div class="rounded border border-green-200 bg-green-50 p-4 shadow-sm">
				<div class="text-xs font-semibold uppercase text-green-600 mb-1">Total Partides</div>
				<div class="text-2xl font-bold text-green-900">{entries.length}</div>
				<div class="text-xs text-green-700">
					{entries.filter((e) => e.estat === 'jugada').length} jugades · {entries.filter((e) => e.estat === 'walkover').length} w.o.
				</div>
			</div>
		</div>

		<!-- ── Classificació de jugadors ────────────────────────────────────── -->
		{#if playerStats.length > 0}
			<div class="mb-6 rounded-lg border border-gray-200 bg-white shadow-sm">
				<div class="border-b border-gray-100 px-4 py-3">
					<h2 class="font-semibold text-gray-800">Classificació per victòries</h2>
				</div>
				<div class="overflow-x-auto">
					<table class="w-full text-sm">
						<thead>
							<tr class="border-b border-gray-100 bg-gray-50 text-left text-xs text-gray-500">
								<th class="px-4 py-2">#</th>
								<th class="px-4 py-2">Jugador</th>
								<th class="px-3 py-2 text-center">V</th>
								<th class="px-3 py-2 text-center">P</th>
								<th class="px-3 py-2 text-center">% Car.</th>
								<th class="px-3 py-2 text-center">Mitjana</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-50">
							{#each playerStats as s, i}
								<tr class="hover:bg-gray-50/50">
									<td class="px-4 py-2 text-xs font-semibold text-gray-400">{i + 1}</td>
									<td class="px-4 py-2 font-medium text-gray-900">{s.name}</td>
									<td class="px-3 py-2 text-center">
										<span class="rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">{s.wins}</span>
									</td>
									<td class="px-3 py-2 text-center text-xs text-gray-500">{s.matches - s.wins}</td>
									<td class="px-3 py-2 text-center text-xs text-gray-600">
										{s.totalDist > 0 ? `${Math.round((s.totalCaramboles / s.totalDist) * 100)}%` : '—'}
									</td>
									<td class="px-3 py-2 text-center text-xs text-gray-600">
										{s.totalEntrades > 0 ? (s.totalCaramboles / s.totalEntrades).toFixed(2) : '—'}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}

		<!-- ── Filtre per jugador ────────────────────────────────────────────── -->
		<div class="mb-4 flex items-center gap-3">
			<input
				type="text"
				placeholder="Filtrar per jugador..."
				bind:value={searchPlayer}
				class="rounded border border-gray-300 px-3 py-1.5 text-sm focus:border-purple-400 focus:outline-none"
			/>
			{#if searchPlayer}
				<button
					type="button"
					on:click={() => (searchPlayer = '')}
					class="text-xs text-gray-500 hover:text-gray-700"
				>✕ Netejar</button>
			{/if}
			<span class="ml-auto text-xs text-gray-500">{filteredEntries.length} partida{filteredEntries.length !== 1 ? 'des' : ''}</span>
		</div>

		<!-- ── Llista de resultats ───────────────────────────────────────────── -->
		<div class="rounded-lg border border-gray-200 bg-white shadow-sm">
			<table class="w-full text-sm">
				<thead>
					<tr class="border-b border-gray-100 bg-gray-50 text-left text-xs text-gray-500">
						<th class="px-3 py-2 w-12 text-center font-mono">Núm.</th>
						<th class="px-3 py-2 w-24">Data</th>
						<th class="px-3 py-2 w-20">Bracket</th>
						<th class="px-3 py-2">Jugador 1</th>
						<th class="px-2 py-2 text-center w-8">vs</th>
						<th class="px-3 py-2">Jugador 2</th>
						<th class="px-3 py-2 text-center w-28">Resultat</th>
						<th class="px-3 py-2 text-center w-20">Ent.</th>
						<th class="px-3 py-2 w-28">Guanyador</th>
					</tr>
				</thead>
				<tbody class="divide-y divide-gray-50">
					{#each filteredEntries as e}
						{@const isP1Winner = e.guanyador_participant_id === e.player1_participant_id}
						<tr class="hover:bg-gray-50/50">
							<td class="px-3 py-2 text-center font-mono text-xs text-gray-500">{e.matchCode}</td>
							<td class="px-3 py-2 text-xs text-gray-500">{formatData(e.data_jugada)}</td>
							<td class="px-3 py-2">
								<span class="rounded px-1.5 py-0.5 text-[10px] font-semibold {BRACKET_COLORS[e.bracket_type]}">
									{BRACKET_LABELS[e.bracket_type].substring(0, 3)} R{e.ronda}
								</span>
							</td>
							<td class="px-3 py-2">
								<div class="font-medium {isP1Winner ? 'text-green-700' : 'text-gray-700'}">{e.player1_name}</div>
								{#if e.distancia1}<div class="text-xs text-gray-400">{e.distancia1} car.</div>{/if}
							</td>
							<td class="px-1 py-2 text-center text-xs text-gray-400">vs</td>
							<td class="px-3 py-2">
								<div class="font-medium {!isP1Winner ? 'text-green-700' : 'text-gray-700'}">{e.player2_name}</div>
								{#if e.distancia2}<div class="text-xs text-gray-400">{e.distancia2} car.</div>{/if}
							</td>
							<td class="px-3 py-2 text-center">
								{#if e.estat === 'walkover'}
									<span class="rounded bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">W.O.</span>
								{:else if e.caramboles1 !== null && e.caramboles2 !== null}
									<span class="{isP1Winner ? 'font-bold text-green-700' : 'text-gray-600'}">{e.caramboles1}</span>
									<span class="text-gray-400 mx-0.5">/</span>
									<span class="{!isP1Winner ? 'font-bold text-green-700' : 'text-gray-600'}">{e.caramboles2}</span>
									{#if e.distancia1 && e.distancia2}
										<div class="text-[10px] text-gray-400">
											{pct(e.caramboles1, e.distancia1)} / {pct(e.caramboles2, e.distancia2)}
										</div>
									{/if}
								{:else}
									—
								{/if}
							</td>
							<td class="px-3 py-2 text-center text-xs text-gray-500">
								{#if e.entrades !== null}{e.entrades}{/if}
							</td>
							<td class="px-3 py-2">
								<span class="font-medium text-green-700">{winnerName(e)}</span>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>
