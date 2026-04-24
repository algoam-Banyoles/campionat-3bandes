<script lang="ts">
	import { createEventDispatcher } from 'svelte';

	// ── Props ─────────────────────────────────────────────────────────────────

	export let player1Name: string;
	export let player2Name: string;
	export let player1Distancia: number | null;
	export let player2Distancia: number | null;
	export let player1ParticipantId: string;
	export let player2ParticipantId: string;
	/** 'distancia' o 'percentatge' */
	export let sistemaPuntuacio: string = 'distancia';
	export let limitEntrades: number | null = null;
	export let saving: boolean = false;

	// ── Estat del formulari ────────────────────────────────────────────────────

	let isWalkover = false;
	let caramboles1: number | null = null;
	let caramboles2: number | null = null;
	let entrades: number | null = null;
	let manualWinner: string | null = null; // participant_id si l'admin tria manualment

	const dispatch = createEventDispatcher<{
		confirm: {
			isWalkover: boolean;
			caramboles1: number | null;
			caramboles2: number | null;
			entrades: number | null;
			winnerParticipantId: string;
			loserParticipantId: string;
		};
		cancel: void;
	}>();

	// ── Guanyador derivat ─────────────────────────────────────────────────────

	$: suggestedWinner = (() => {
		if (isWalkover) return null;
		if (caramboles1 === null || caramboles2 === null) return null;

		if (sistemaPuntuacio === 'distancia') {
			// Guanya qui primer arriba a la seva distància
			const p1done = player1Distancia !== null && caramboles1 >= player1Distancia;
			const p2done = player2Distancia !== null && caramboles2 >= player2Distancia;
			if (p1done && !p2done) return player1ParticipantId;
			if (p2done && !p1done) return player2ParticipantId;
			// Si ambdós o cap arriben: el que té més caramboles
		}

		// Percentatge o empat: el que té més % relativa a la seva distancia
		if (player1Distancia && player2Distancia) {
			const pct1 = caramboles1 / player1Distancia;
			const pct2 = caramboles2 / player2Distancia;
			if (pct1 > pct2) return player1ParticipantId;
			if (pct2 > pct1) return player2ParticipantId;
		}

		// Empat exacte: requereix selecció manual
		return null;
	})();

	$: derivedWinner = manualWinner ?? suggestedWinner;

	$: entradesRequired = sistemaPuntuacio === 'percentatge';

	$: over1 = player1Distancia !== null && caramboles1 !== null && caramboles1 > player1Distancia;
	$: over2 = player2Distancia !== null && caramboles2 !== null && caramboles2 > player2Distancia;

	$: isValid = (() => {
		if (isWalkover) return manualWinner !== null;
		if (caramboles1 === null || caramboles2 === null) return false;
		if (caramboles1 < 0 || caramboles2 < 0) return false;
		if (over1 || over2) return false;
		if (entradesRequired && (entrades === null || entrades <= 0)) return false;
		return derivedWinner !== null;
	})();

	$: winnerName = derivedWinner === player1ParticipantId
		? player1Name
		: derivedWinner === player2ParticipantId
		? player2Name
		: null;

	function confirm() {
		if (!isValid || !derivedWinner) return;
		const loser = derivedWinner === player1ParticipantId ? player2ParticipantId : player1ParticipantId;
		dispatch('confirm', {
			isWalkover,
			caramboles1: isWalkover ? null : caramboles1,
			caramboles2: isWalkover ? null : caramboles2,
			entrades: isWalkover ? null : entrades,
			winnerParticipantId: derivedWinner,
			loserParticipantId: loser
		});
	}

	function cancel() {
		dispatch('cancel');
	}

	// Reset manual winner si canvia walkover
	$: if (isWalkover) {
		caramboles1 = null;
		caramboles2 = null;
		entrades = null;
	}

	// Percentatge per mostrar
	function pct(car: number | null, dist: number | null): string {
		if (!car || !dist) return '';
		return `${Math.round((car / dist) * 100)}%`;
	}
</script>

<div class="space-y-4">
	<!-- Jugadors -->
	<div class="rounded border border-gray-200 overflow-hidden text-sm">
		<!-- Jugador 1 -->
		<div class="flex items-center gap-3 px-4 py-3 {derivedWinner === player1ParticipantId ? 'bg-green-50' : ''}">
			<div class="flex-1 font-medium text-gray-900">{player1Name}</div>
			{#if player1Distancia}
				<div class="text-xs text-gray-500">{player1Distancia} car.</div>
			{/if}
		</div>
		<div class="border-t border-gray-100 text-center text-xs font-bold text-gray-400 py-0.5">vs</div>
		<!-- Jugador 2 -->
		<div class="flex items-center gap-3 px-4 py-3 {derivedWinner === player2ParticipantId ? 'bg-green-50' : ''}">
			<div class="flex-1 font-medium text-gray-900">{player2Name}</div>
			{#if player2Distancia}
				<div class="text-xs text-gray-500">{player2Distancia} car.</div>
			{/if}
		</div>
	</div>

	<!-- Walkover -->
	<label class="flex items-center gap-2 cursor-pointer select-none">
		<input type="checkbox" bind:checked={isWalkover} class="h-4 w-4 rounded border-gray-300 text-purple-600" />
		<span class="text-sm text-gray-700">Walkover (no presentació)</span>
	</label>

	{#if !isWalkover}
		<!-- Caramboles (i entrades si sistema percentatge) -->
		<div class="grid gap-3 text-sm" class:grid-cols-2={!entradesRequired} class:grid-cols-3={entradesRequired}>
			<div>
				<label for="hcp-car-p1" class="block text-xs font-medium text-gray-600 mb-1">
					Car. {player1Name.split(' ')[0]}
					{#if player1Distancia}
						<span class="font-normal text-gray-400">/ {player1Distancia}</span>
					{/if}
				</label>
				<div class="flex items-center gap-1">
					<input
						id="hcp-car-p1"
						type="number"
						min="0"
						max={player1Distancia ?? undefined}
						bind:value={caramboles1}
						class="w-full rounded border px-2 py-1.5 text-sm focus:outline-none {over1 ? 'border-red-400 focus:border-red-500' : 'border-gray-300 focus:border-purple-400'}"
					/>
					{#if caramboles1 !== null && player1Distancia}
						<span class="shrink-0 text-xs text-gray-400">{pct(caramboles1, player1Distancia)}</span>
					{/if}
				</div>
				{#if over1}
					<p class="mt-0.5 text-xs text-red-600">Màxim {player1Distancia} car.</p>
				{/if}
			</div>
			<div>
				<label for="hcp-car-p2" class="block text-xs font-medium text-gray-600 mb-1">
					Car. {player2Name.split(' ')[0]}
					{#if player2Distancia}
						<span class="font-normal text-gray-400">/ {player2Distancia}</span>
					{/if}
				</label>
				<div class="flex items-center gap-1">
					<input
						id="hcp-car-p2"
						type="number"
						min="0"
						max={player2Distancia ?? undefined}
						bind:value={caramboles2}
						class="w-full rounded border px-2 py-1.5 text-sm focus:outline-none {over2 ? 'border-red-400 focus:border-red-500' : 'border-gray-300 focus:border-purple-400'}"
					/>
					{#if caramboles2 !== null && player2Distancia}
						<span class="shrink-0 text-xs text-gray-400">{pct(caramboles2, player2Distancia)}</span>
					{/if}
				</div>
				{#if over2}
					<p class="mt-0.5 text-xs text-red-600">Màxim {player2Distancia} car.</p>
				{/if}
			</div>
			{#if entradesRequired}
				<div>
					<label for="hcp-entrades" class="block text-xs font-medium text-gray-600 mb-1">
						Entrades
						{#if limitEntrades}
							<span class="font-normal text-gray-400">/ {limitEntrades}</span>
						{/if}
					</label>
					<input
						id="hcp-entrades"
						type="number"
						min="1"
						bind:value={entrades}
						class="w-full rounded border border-gray-300 px-2 py-1.5 text-sm focus:border-purple-400 focus:outline-none"
					/>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Guanyador -->
	<div>
		<div class="mb-1.5 text-xs font-medium text-gray-600">Guanyador</div>
		<div class="flex gap-2">
			<button
				type="button"
				on:click={() => (manualWinner = player1ParticipantId)}
				class="flex-1 rounded border py-2 text-sm font-medium transition-colors
					{derivedWinner === player1ParticipantId
						? 'border-green-400 bg-green-50 text-green-800'
						: 'border-gray-200 text-gray-600 hover:bg-gray-50'}"
			>
				{player1Name.split(' ')[0]}
				{#if suggestedWinner === player1ParticipantId && !manualWinner}
					<span class="ml-1 text-xs text-green-600">★</span>
				{/if}
			</button>
			<button
				type="button"
				on:click={() => (manualWinner = player2ParticipantId)}
				class="flex-1 rounded border py-2 text-sm font-medium transition-colors
					{derivedWinner === player2ParticipantId
						? 'border-green-400 bg-green-50 text-green-800'
						: 'border-gray-200 text-gray-600 hover:bg-gray-50'}"
			>
				{player2Name.split(' ')[0]}
				{#if suggestedWinner === player2ParticipantId && !manualWinner}
					<span class="ml-1 text-xs text-green-600">★</span>
				{/if}
			</button>
		</div>
		{#if manualWinner && suggestedWinner && manualWinner !== suggestedWinner}
			<p class="mt-1 text-xs text-amber-600">
				⚠ El resultat suggeria un altre guanyador. Confirmes la selecció manual?
			</p>
		{/if}
	</div>

	<!-- Botons -->
	<div class="flex justify-end gap-2 pt-2 border-t border-gray-100">
		<button
			type="button"
			on:click={cancel}
			disabled={saving}
			class="rounded border border-gray-300 bg-white px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
		>
			Cancel·lar
		</button>
		<button
			type="button"
			on:click={confirm}
			disabled={!isValid || saving}
			class="rounded px-5 py-2 text-sm font-semibold text-white transition-colors
				{isValid && !saving
					? 'bg-green-600 hover:bg-green-700'
					: 'cursor-not-allowed bg-gray-300'}"
		>
			{saving ? 'Guardant...' : 'Confirmar resultat'}
		</button>
	</div>
</div>
