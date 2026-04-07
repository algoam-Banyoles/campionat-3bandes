<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
	$: if ($adminChecked && !$isAdmin) goto('/handicap');
	import { supabase } from '$lib/supabaseClient';
	import {
		generateDoublEliminationBracket,
		calcByes,
		getR1Pairings,
		type ParticipantInput
	} from '$lib/utils/handicap-bracket-generator';
	import { validateBracket } from '$lib/utils/handicap-bracket-validator';
	import { insertBracketToDb } from '$lib/utils/handicap-bracket-db';
	import { autoScheduleReadyMatches } from '$lib/utils/handicap-auto-schedule';

	let loading = true;
	let saving = false;
	let error: string | null = null;
	let validationWarnings: string[] = [];

	let event: any = null;
	let config: any = null;
	let participants: any[] = []; // handicap_participants amb socis (FK directe via soci_numero)

	// Assignació de seeds: participant.id → seed (1-based)
	let seedMap: Record<string, number> = {};

	// Errors de validació del sorteig
	$: seedValues = Object.values(seedMap).filter(Boolean);
	$: allSeeded = participants.length > 0 && seedValues.length === participants.length;
	$: hasDuplicates = allSeeded && new Set(seedValues).size !== seedValues.length;
	$: validSeeds = allSeeded && !hasDuplicates;

	// Participants com a ParticipantInput (per al generador)
	$: participantInputs = validSeeds
		? participants.map((p) => ({
				id: p.id as string,
				seed: seedMap[p.id] as number,
				distancia: p.distancia as number
			}))
		: [];

	$: byes = participants.length > 0 ? calcByes(participants.length) : 0;

	// Vista prèvia R1 (si tots els seeds estan assignats)
	$: r1Preview = validSeeds ? getR1Pairings(participantInputs) : [];

	function playerName(p: any): string {
		const raw = p.socis;
		const s = Array.isArray(raw) ? raw[0] : raw;
		return s ? `${s.nom ?? ''} ${s.cognoms ?? ''}`.trim() || '—' : '—';
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
		// Assignar seeds 1..N en l'ordre actual de la llista
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
			const result = generateDoublEliminationBracket(event.id, participantInputs);

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

<div class="mx-auto max-w-4xl p-4">
	<div class="mb-4 flex items-center gap-3">
		<a href="/handicap" class="text-sm text-purple-600 hover:underline">← Hàndicap</a>
		<h1 class="text-2xl font-bold text-gray-900">Sorteig</h1>
		{#if event}
			<span class="text-sm text-gray-500">{event.nom}</span>
		{/if}
	</div>

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
		<div class="mb-4 grid grid-cols-3 gap-3 text-sm">
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-2xl font-bold text-purple-700">{participants.length}</div>
				<div class="text-gray-500">Participants</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-2xl font-bold text-blue-700">{byes}</div>
				<div class="text-gray-500">Byes</div>
			</div>
			<div class="rounded border border-gray-200 bg-white p-3 text-center shadow-sm">
				<div class="text-2xl font-bold text-green-700">{2 * (participants.length + byes) - 1}</div>
				<div class="text-gray-500">Partides estimades</div>
			</div>
		</div>

		<!-- Assignació de seeds -->
		<div class="mb-6 rounded-lg border border-gray-200 bg-white shadow-sm">
			<div class="flex items-center justify-between border-b border-gray-100 px-4 py-3">
				<h2 class="font-semibold text-gray-800">Assignació de seeds</h2>
				<div class="flex gap-2">
					<button
						type="button"
						on:click={assignSeedsAuto}
						class="rounded border border-gray-300 bg-white px-3 py-1 text-xs text-gray-700 hover:bg-gray-50"
					>
						Auto (1..{participants.length})
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
					Hi ha seeds duplicats. Cada jugador ha de tenir un seed únic (1–{participants.length}).
				</div>
			{/if}

			<div class="p-4">
				<table class="w-full text-sm">
					<thead>
						<tr class="border-b border-gray-100 text-left text-xs text-gray-500">
							<th class="pb-2 pr-4">Seed</th>
							<th class="pb-2 pr-4">Jugador</th>
							<th class="pb-2 text-right">Distància</th>
						</tr>
					</thead>
					<tbody>
						{#each sortedParticipants as p (p.id)}
							<tr class="border-b border-gray-50">
								<td class="py-2 pr-4 w-20">
									<input
										type="number"
										min="1"
										max={participants.length}
										bind:value={seedMap[p.id]}
										on:blur={() => { seedMap = { ...seedMap }; }}
										class="w-16 rounded border px-2 py-1 text-center text-sm
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
					<p class="text-xs text-gray-500 mt-0.5">Winners bracket, Ronda 1</p>
				</div>
				<div class="p-4">
					<div class="space-y-2">
						{#each r1Preview as pair, i}
							<div class="flex items-center gap-3 rounded border border-gray-100 bg-gray-50 px-3 py-2 text-sm">
								<span class="w-6 text-center text-xs font-bold text-gray-400">{i + 1}</span>
								<span class="flex-1 font-medium text-gray-900">
									[{pair.seed1.seed}] {participants.find(p => p.id === pair.seed1.id) ? playerName(participants.find(p => p.id === pair.seed1.id)!) : '?'}
									<span class="text-xs text-gray-500 ml-1">({pair.seed1.distancia} car.)</span>
								</span>
								<span class="text-gray-400 font-bold">vs</span>
								{#if pair.seed2}
									<span class="flex-1 font-medium text-gray-900 text-right">
										[{pair.seed2.seed}] {participants.find(p => p.id === pair.seed2!.id) ? playerName(participants.find(p => p.id === pair.seed2!.id)!) : '?'}
										<span class="text-xs text-gray-500 ml-1">({pair.seed2.distancia} car.)</span>
									</span>
								{:else}
									<span class="flex-1 text-right text-amber-600 font-medium">BYE ✓</span>
								{/if}
							</div>
						{/each}
					</div>
					{#if byes > 0}
						<p class="mt-3 text-xs text-amber-700">
							{byes} bye{byes !== 1 ? 's' : ''}: el{byes !== 1 ? 's' : ''} seed{byes !== 1 ? 's' : ''} 1..{byes} passe{byes !== 1 ? 'n' : ''} automàticament a la 2a ronda.
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
					<span class="text-amber-600">Assigna un seed a cada jugador per continuar.</span>
				{:else if hasDuplicates}
					<span class="text-red-600">Corregeix els seeds duplicats.</span>
				{:else}
					<span class="text-green-700 font-medium">✓ Tots els seeds assignats. Llest per generar.</span>
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
