<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import type { CompatibilityIssue, AlternativeSlot } from '$lib/utils/handicap-compatibility';

	export let issues: CompatibilityIssue[] = [];
	export let loading: boolean = false;
	export let onClose: () => void = () => {};

	const dispatch = createEventDispatcher<{
		apply: { matchId: string; slot: AlternativeSlot };
	}>();

	function fmtDate(iso: string): string {
		const [, m, d] = iso.split('-');
		return `${d}/${m}`;
	}
</script>

<div
	class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
	on:click|self={onClose}
	role="presentation"
>
	<div class="w-full max-w-3xl rounded-lg bg-white shadow-xl flex flex-col max-h-[90vh]" role="dialog" aria-modal="true">
		<div class="flex items-center justify-between border-b border-gray-200 px-5 py-4">
			<h2 class="text-lg font-semibold text-gray-900">Revisió d'incompatibilitats horàries</h2>
			<button type="button" on:click={onClose} class="text-gray-400 hover:text-gray-600" aria-label="Tancar">×</button>
		</div>

		<div class="overflow-y-auto px-5 py-4">
			{#if loading}
				<p class="text-sm text-gray-500">Comprovant…</p>
			{:else if issues.length === 0}
				<div class="rounded border border-green-300 bg-green-50 p-3 text-sm text-green-800">
					Cap incompatibilitat: totes les partides programades respecten les preferències horàries dels seus jugadors.
				</div>
			{:else}
				<p class="mb-3 text-sm text-gray-600">
					{issues.length} partid{issues.length === 1 ? 'a' : 'es'} amb conflicte. Selecciona una alternativa o tanca per deixar-ho com està.
				</p>
				<div class="space-y-3">
					{#each issues as iss}
						<div class="rounded border border-amber-300 bg-amber-50 p-3">
							<div class="flex items-baseline justify-between gap-2">
								<div>
									<span class="font-mono text-xs text-gray-500">{iss.matchCode}</span>
									<span class="ml-2 font-medium text-gray-900">{iss.player1Name} vs {iss.player2Name}</span>
								</div>
								<span class="text-xs text-gray-500">actual: {fmtDate(iss.current.data)} {iss.current.hora} B{iss.current.taula}</span>
							</div>
							<p class="mt-1 text-xs text-amber-800">{iss.motiu}</p>
							{#if iss.alternatives.length === 0}
								<p class="mt-2 text-xs text-gray-500 italic">Cap alternativa compatible disponible. Cal revisar les preferències del jugador o l'horari del torneig.</p>
							{:else}
								<div class="mt-2 flex flex-wrap gap-2">
									{#each iss.alternatives as alt}
										<button
											type="button"
											on:click={() => dispatch('apply', { matchId: iss.matchId, slot: alt })}
											class="rounded border border-green-300 bg-white px-3 py-1.5 text-xs font-medium text-green-700 hover:bg-green-50"
										>
											Aplicar {fmtDate(alt.data)} {alt.hora} B{alt.taula}
										</button>
									{/each}
								</div>
							{/if}
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<div class="flex items-center justify-end border-t border-gray-200 px-5 py-3">
			<button type="button" on:click={onClose} class="rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50">
				Tancar
			</button>
		</div>
	</div>
</div>
