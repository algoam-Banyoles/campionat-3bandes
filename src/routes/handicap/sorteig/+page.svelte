<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { adminChecked } from '$lib/stores/adminAuth';
	import { effectiveIsAdmin } from '$lib/stores/viewMode';
	$: if ($adminChecked && !$effectiveIsAdmin) goto('/handicap');
	import { supabase } from '$lib/supabaseClient';
	import {
		generateDoublEliminationBracket,
		calcByes
	} from '$lib/utils/handicap-bracket-generator';
	import { validateBracket } from '$lib/utils/handicap-bracket-validator';
	import { insertBracketToDb } from '$lib/utils/handicap-bracket-db';
	import { autoScheduleReadyMatches } from '$lib/utils/handicap-auto-schedule';
	import { formatarNomJugador } from '$lib/utils/playerUtils';

	let loading = true;
	let saving = false;
	let error: string | null = null;
	let validationWarnings: string[] = [];

	let event: any = null;
	let config: any = null;
	let participants: any[] = []; // handicap_participants amb socis (FK directe via soci_numero)

	// Assignació de POSICIONS a R1: participant.id → posicio (1..bracketSize).
	// Les posicions sense participant esdevenen byes a R1.
	let seedMap: Record<string, number> = {};

	$: nParticipants = participants.length;
	$: bracketSize = nParticipants > 0 ? nextPow2Local(nParticipants) : 0;
	$: byes = nParticipants > 0 ? calcByes(nParticipants) : 0;

	function nextPow2Local(n: number): number {
		let p = 1;
		while (p < n) p *= 2;
		return p;
	}

	// Errors de validació del sorteig
	$: seedValues = Object.values(seedMap).filter((v) => typeof v === 'number' && v > 0);
	$: allSeeded = participants.length > 0 && seedValues.length === participants.length;
	$: hasDuplicates = allSeeded && new Set(seedValues).size !== seedValues.length;
	$: outOfRange = seedValues.some((v) => v < 1 || v > bracketSize);
	$: validSeeds = allSeeded && !hasDuplicates && !outOfRange;

	// Participants com a ParticipantInput (per al generador) — el `seed` és la POSICIÓ a R1
	$: participantInputs = validSeeds
		? participants.map((p) => ({
				id: p.id as string,
				seed: seedMap[p.id] as number,
				distancia: p.distancia as number
			}))
		: [];

	// Vista prèvia R1 amb les posicions assignades (byes als slots sense participant)
	type R1Pair = {
		matchNum: number;
		slot1: { posicio: number; participant: any | null };
		slot2: { posicio: number; participant: any | null };
	};
	$: r1Preview = (() => {
		if (!validSeeds || bracketSize === 0) return [] as R1Pair[];
		const byPos = new Map<number, any>();
		for (const p of participants) {
			const pos = seedMap[p.id];
			if (pos) byPos.set(pos, p);
		}
		const pairs: R1Pair[] = [];
		for (let i = 1; i <= bracketSize / 2; i++) {
			const pos1 = 2 * i - 1;
			const pos2 = 2 * i;
			pairs.push({
				matchNum: i,
				slot1: { posicio: pos1, participant: byPos.get(pos1) ?? null },
				slot2: { posicio: pos2, participant: byPos.get(pos2) ?? null }
			});
		}
		return pairs;
	})();

	function playerName(p: any): string {
		const raw = p.socis;
		const s = Array.isArray(raw) ? raw[0] : raw;
		if (!s) return '—';
		const full = `${s.nom ?? ''} ${s.cognoms ?? ''}`.trim();
		return full ? formatarNomJugador(full) : '—';
	}

	// Ordenar participants per seed assignat (o per id si no té seed)
	$: sortedParticipants = [...participants].sort((a, b) => {
		const sa = seedMap[a.id] ?? 9999;
		const sb = seedMap[b.id] ?? 9999;
		return sa - sb;
	});

	// Inicialitzar seeds automàticament si els participants ja en tenen
	function initSeeds() {
		seedMap = {};
		for (const p of participants) {
			if (p.seed) seedMap[p.id] = p.seed;
		}
	}

	function assignSeedsAuto() {
		// Assignar posicions 1..N en l'ordre actual de la llista (byes a les posicions N+1..size).
		const order = [...participants].sort((a, b) => {
			const sa = seedMap[a.id] ?? 9999;
			const sb = seedMap[b.id] ?? 9999;
			return sa - sb;
		});
		const newMap: Record<string, number> = {};
		order.forEach((p, i) => {
			newMap[p.id] = i + 1;
		});
		seedMap = newMap;
	}

	function clearSeeds() {
		seedMap = {};
	}

	async function generateBracket() {
		if (!validSeeds || !event) return;
		saving = true;
		error = null;

		try {
			const result = generateDoublEliminationBracket(event.id, participantInputs, {
				useExplicitR1Positions: true
			});

			// Validar bracket generat
			const validation = validateBracket(
				result.slots as any,
				result.matches as any,
				participantInputs.length
			);
			if (!validation.valid) {
				throw new Error('Error de validació intern:\n' + validation.errors.join('\n'));
			}
			validationWarnings = validation.warnings;

			// Insertar bracket (3 passos per la FK circular slots↔matches)
			await insertBracketToDb(supabase, result);

			// Actualitzar seeds als participants
			for (const p of participantInputs) {
				await supabase
					.from('handicap_participants')
					.update({ seed: p.seed })
					.eq('id', p.id);
			}

			// Calendaritzar automàticament les partides de R1 que quedin llestes
			await autoScheduleReadyMatches(supabase, event.id);

			await goto('/handicap/quadre');
		} catch (e: any) {
			error = e.message ?? 'Error generant el bracket';
		} finally {
			saving = false;
		}
	}

	onMount(async () => {
		// Carregar event actiu
		const { data: ev } = await supabase
			.from('events')
			.select('id, nom')
			.eq('tipus_competicio', 'handicap')
			.eq('actiu', true)
			.limit(1)
			.single();

		if (!ev) {
			error = 'No hi ha cap event hàndicap actiu.';
			loading = false;
			return;
		}
		event = ev;

		// Verificar que no existeix ja un bracket generat
		const { count: existingSlots } = await supabase
			.from('handicap_bracket_slots')
			.select('*', { count: 'exact', head: true })
			.eq('event_id', ev.id);

		if ((existingSlots ?? 0) > 0) {
			await goto('/handicap/quadre');
			return;
		}

		// Carregar config
		const { data: cfg } = await supabase
			.from('handicap_config')
			.select('*')
			.eq('event_id', ev.id)
			.single();
		config = cfg;

		// Carregar participants (Fase 5c-S2b: FK directe via soci_numero)
		const { data: parts } = await supabase
			.from('handicap_participants')
			.select('id, distancia, seed, soci_numero, socis!handicap_participants_soci_numero_fkey(nom, cognoms)')
			.eq('event_id', ev.id)
			.order('seed', { ascending: true, nullsFirst: false });

		participants = parts ?? [];
		initSeeds();
		loading = false;
	});
</script>

<div class="hcap-page-root">
	<header class="page-mast">
		<div>
			<div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">
				<a href="/handicap" class="back-link">← Hàndicap</a>{#if event} · {event.nom}{/if}
			</div>
			<h1 class="page-title">Sorteig</h1>
		</div>
	</header>

	{#if loading}
		<p class="text-gray-500">Carregant...</p>
	{:else if error}
		<div class="rounded border border-red-300 bg-red-50 p-4 text-red-800">{error}</div>
	{:else if participants.length < 4}
		<div class="rounded border border-amber-300 bg-amber-50 p-4 text-amber-800">
			<p class="font-semibold">Cal mínim 4 participants.</p>
			<p class="mt-1 text-sm">
				Ara hi ha {participants.length} inscrit{participants.length !== 1 ? 's' : ''}.
				<a href="/handicap/inscripcions" class="underline">Afegir jugadors</a>
			</p>
		</div>
	{:else}
		<!-- Info resum -->
		<div class="mb-4 grid grid-cols-4 gap-3 text-sm">
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-2xl font-bold text-purple-700">{nParticipants}</div>
				<div class="text-gray-500">Participants</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-2xl font-bold text-gray-800">{bracketSize}</div>
				<div class="text-gray-500">Places R1</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-2xl font-bold text-blue-700">{byes}</div>
				<div class="text-gray-500">Byes (posicions buides)</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-2xl font-bold text-green-700">{2 * (participants.length + byes) - 1}</div>
				<div class="text-gray-500">Partides estimades</div>
			</div>
		</div>

		<!-- Assignació de posicions a R1 -->
		<div class="mb-6 rounded-lg border border-gray-200 bg-white shadow-sm">
			<div class="flex items-center justify-between border-b border-gray-100 px-4 py-3">
				<div>
					<h2 class="font-semibold text-gray-800">Assignació de posicions a R1 (sorteig manual)</h2>
					<p class="text-xs text-gray-500 mt-0.5">
						Posa a cada jugador la posició que tindrà a la 1a ronda (1..{bracketSize}).
						Les posicions s'emparellen 1-2, 3-4, 5-6, etc. Les que deixis buides seran <strong>byes</strong>.
					</p>
				</div>
				<div class="flex gap-2">
					<button
						type="button"
						on:click={assignSeedsAuto}
						class="rounded border border-gray-300 bg-white px-3 py-1 text-xs text-gray-700 hover:bg-gray-50"
					>
						Auto (1..{nParticipants})
					</button>
					<button
						type="button"
						on:click={clearSeeds}
						class="rounded border border-gray-300 bg-white px-3 py-1 text-xs text-gray-700 hover:bg-gray-50"
					>
						Esborrar
					</button>
				</div>
			</div>

			{#if hasDuplicates}
				<div class="mx-4 mt-3 rounded border border-red-200 bg-red-50 p-2 text-xs text-red-700">
					Hi ha posicions duplicades. Cada jugador ha de tenir una posició única (1–{bracketSize}).
				</div>
			{/if}
			{#if outOfRange}
				<div class="mx-4 mt-3 rounded border border-red-200 bg-red-50 p-2 text-xs text-red-700">
					Hi ha posicions fora de rang. Han d'estar entre 1 i {bracketSize}.
				</div>
			{/if}

			<div class="p-4">
				<table class="w-full text-sm">
					<thead>
						<tr class="border-b border-gray-100 text-left text-xs text-gray-500">
							<th class="pb-2 pr-4">Posició R1</th>
							<th class="pb-2 pr-4">Jugador</th>
							<th class="pb-2 text-right">Distància</th>
						</tr>
					</thead>
					<tbody>
						{#each sortedParticipants as p (p.id)}
							<tr class="border-b border-gray-50">
								<td class="py-2 pr-4 w-24">
									<input
										type="number"
										min="1"
										max={bracketSize}
										bind:value={seedMap[p.id]}
										on:blur={() => { seedMap = { ...seedMap }; }}
										class="w-20 rounded border px-2 py-1 text-center text-sm
											{seedMap[p.id]
												? 'border-purple-300 bg-purple-50'
												: 'border-gray-300 bg-white'}"
										placeholder="—"
									/>
								</td>
								<td class="py-2 pr-4 font-medium text-gray-900">{playerName(p)}</td>
								<td class="py-2 text-right text-gray-600">{p.distancia} car.</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>

		<!-- Vista prèvia R1 -->
		{#if r1Preview.length > 0}
			<div class="mb-6 rounded-lg border border-purple-200 bg-white shadow-sm">
				<div class="border-b border-purple-100 px-4 py-3">
					<h2 class="font-semibold text-gray-800">Vista prèvia — 1a ronda</h2>
					<p class="text-xs text-gray-500 mt-0.5">Winners bracket, Ronda 1 ({bracketSize} places, {byes} byes)</p>
				</div>
				<div class="p-4">
					<div class="space-y-2">
						{#each r1Preview as pair}
							<div class="flex items-center gap-3 rounded border border-gray-100 bg-gray-50 px-3 py-2 text-sm">
								<span class="w-12 text-center text-xs font-bold text-gray-400">M{pair.matchNum}</span>
								<span class="flex-1 font-medium text-gray-900">
									<span class="text-xs text-gray-400 mr-1">[pos {pair.slot1.posicio}]</span>
									{#if pair.slot1.participant}
										{playerName(pair.slot1.participant)}
										<span class="text-xs text-gray-500 ml-1">({pair.slot1.participant.distancia} car.)</span>
									{:else}
										<span class="text-amber-600 font-medium">BYE</span>
									{/if}
								</span>
								<span class="text-gray-400 font-bold">vs</span>
								<span class="flex-1 font-medium text-gray-900 text-right">
									{#if pair.slot2.participant}
										{playerName(pair.slot2.participant)}
										<span class="text-xs text-gray-500 ml-1">({pair.slot2.participant.distancia} car.)</span>
									{:else}
										<span class="text-amber-600 font-medium">BYE</span>
									{/if}
									<span class="text-xs text-gray-400 ml-1">[pos {pair.slot2.posicio}]</span>
								</span>
							</div>
						{/each}
					</div>
					{#if byes > 0}
						<p class="mt-3 text-xs text-amber-700">
							{byes} bye{byes !== 1 ? 's' : ''}: el jugador emparellat amb una posició buida passa automàticament a la 2a ronda.
						</p>
					{/if}
				</div>
			</div>
		{/if}

		<!-- Avisos de validació (si n'hi ha) -->
		{#if validationWarnings.length > 0}
			<div class="mb-4 rounded border border-amber-300 bg-amber-50 p-3 text-sm text-amber-800">
				<p class="font-semibold mb-1">Avisos de validació:</p>
				<ul class="list-disc pl-4 space-y-0.5">
					{#each validationWarnings as w}
						<li>{w}</li>
					{/each}
				</ul>
			</div>
		{/if}

		<!-- Botó generar -->
		<div class="flex items-center justify-between rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
			<div class="text-sm text-gray-600">
				{#if !allSeeded}
					<span class="text-amber-600">Assigna una posició a R1 a cada jugador per continuar.</span>
				{:else if hasDuplicates}
					<span class="text-red-600">Corregeix les posicions duplicades.</span>
				{:else if outOfRange}
					<span class="text-red-600">Hi ha posicions fora del rang 1..{bracketSize}.</span>
				{:else}
					<span class="text-green-700 font-medium">✓ Totes les posicions assignades. Llest per generar.</span>
				{/if}
			</div>
			<button
				type="button"
				on:click={generateBracket}
				disabled={!validSeeds || saving}
				class="rounded-lg px-6 py-2 font-semibold text-white transition-colors
					{validSeeds && !saving
						? 'bg-purple-600 hover:bg-purple-700'
						: 'cursor-not-allowed bg-gray-300'}"
			>
				{saving ? 'Generant...' : 'Generar bracket'}
			</button>
		</div>
	{/if}
</div>

<style>
	.hcap-page-root {
		max-width: 56rem; margin: 0 auto; padding: 1rem;
		display: flex; flex-direction: column; gap: 1.25rem;
		font-family: var(--font-sans); color: var(--ink);
	}
	.page-mast { padding-bottom: 1rem; border-bottom: 2px solid var(--ink); }
	.editorial-eyebrow {
		font-size: 0.75rem; font-weight: 600;
		letter-spacing: 0.16em; text-transform: uppercase;
		color: var(--sec-handicap);
	}
	.back-link { color: var(--sec-handicap); text-decoration: none; }
	.back-link:hover { color: var(--ink); }
	.page-title {
		font-weight: 800; font-size: 2rem;
		letter-spacing: -0.025em; margin: 0;
	}
	.hcap-page-root :global(.bg-white),
	.hcap-page-root :global(.bg-purple-50),
	.hcap-page-root :global(.bg-blue-50),
	.hcap-page-root :global(.bg-yellow-50),
	.hcap-page-root :global(.bg-green-50),
	.hcap-page-root :global(.bg-gray-50),
	.hcap-page-root :global(.bg-slate-50) {
		background: var(--paper-elevated) !important;
		border-radius: 0 !important;
	}
	.hcap-page-root :global(.bg-red-50) {
		background: var(--paper-elevated) !important;
		border: 1px solid var(--accent) !important;
		color: var(--accent) !important;
		border-radius: 0 !important;
	}
	.hcap-page-root :global(.text-purple-600),
	.hcap-page-root :global(.text-purple-700) { color: var(--sec-handicap) !important; }
	.hcap-page-root :global(.text-yellow-700),
	.hcap-page-root :global(.text-amber-700) { color: var(--amber) !important; }
	.hcap-page-root :global(.text-green-600),
	.hcap-page-root :global(.text-green-700) { color: var(--green) !important; }
	.hcap-page-root :global(.text-red-600),
	.hcap-page-root :global(.text-red-700) { color: var(--accent) !important; }
	.hcap-page-root :global(.text-gray-500),
	.hcap-page-root :global(.text-gray-600) { color: var(--ink-2) !important; }
	.hcap-page-root :global(.text-gray-900) { color: var(--ink) !important; }
	.hcap-page-root :global(button.bg-purple-600),
	.hcap-page-root :global(button[class*="bg-purple"]) {
		background: var(--sec-handicap) !important;
		color: white !important;
		border: 1px solid var(--sec-handicap) !important;
		border-radius: 0 !important;
		font-weight: 600 !important;
	}
	.hcap-page-root :global(button.bg-blue-600),
	.hcap-page-root :global(button[class*="bg-blue"]) {
		background: var(--ink) !important;
		color: var(--paper) !important;
		border: 1px solid var(--ink) !important;
		border-radius: 0 !important;
		font-weight: 600 !important;
	}
	.hcap-page-root :global(input),
	.hcap-page-root :global(select) {
		background: var(--paper-elevated) !important;
		border: 1px solid var(--rule-strong) !important;
		border-radius: 0 !important;
		color: var(--ink) !important;
	}
	.hcap-page-root :global(.rounded),
	.hcap-page-root :global(.rounded-lg),
	.hcap-page-root :global(.rounded-md),
	.hcap-page-root :global(.rounded-xl),
	.hcap-page-root :global(.rounded-full) { border-radius: 0 !important; }
	.hcap-page-root :global(.shadow),
	.hcap-page-root :global(.shadow-sm),
	.hcap-page-root :global(.shadow-md) { box-shadow: none !important; }
</style>
