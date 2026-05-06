<script lang="ts">
	// Props
	export let participants: any[] = [];         // array de handicap_participants amb socis niat (Fase 5c+)
	export let horesDisponibles: string[] = [];  // ex: ['17:00','18:00','19:00']
	export let mode: 'resum' | 'individual' = 'resum';

	// Individual mode: editable availability
	export let preferencies_dies: string[] = [];
	export let preferencies_hores: string[] = [];

	const dies = [
		{ value: 'dl', label: 'Dl', full: 'Dilluns' },
		{ value: 'dt', label: 'Dt', full: 'Dimarts' },
		{ value: 'dc', label: 'Dc', full: 'Dimecres' },
		{ value: 'dj', label: 'Dj', full: 'Dijous' },
		{ value: 'dv', label: 'Dv', full: 'Divendres' }
	];

	function toggleDia(val: string) {
		if (preferencies_dies.includes(val)) {
			preferencies_dies = preferencies_dies.filter(d => d !== val);
		} else {
			preferencies_dies = [...preferencies_dies, val];
		}
	}

	function toggleHora(val: string) {
		if (preferencies_hores.includes(val)) {
			preferencies_hores = preferencies_hores.filter(h => h !== val);
		} else {
			preferencies_hores = [...preferencies_hores, val];
		}
	}

	// Resum mode: count players available per slot
	function countAvailable(dia: string, hora: string): number {
		return participants.filter(p => {
			const dies = p.preferencies_dies || [];
			const hores = p.preferencies_hores || [];
			// If player has declared no preferences, consider them available everywhere
			if (dies.length === 0 && hores.length === 0) return true;
			const diaOk = dies.length === 0 || dies.includes(dia);
			const horaOk = hores.length === 0 || hores.includes(hora);
			return diaOk && horaOk;
		}).length;
	}

	function slotColor(count: number, total: number): string {
		if (total === 0) return 'bg-gray-100 text-gray-400';
		const ratio = count / total;
		if (count < 2) return 'bg-red-100 text-red-800 font-bold';
		if (ratio < 0.33) return 'bg-orange-100 text-orange-800';
		if (ratio < 0.6) return 'bg-yellow-100 text-yellow-700';
		return 'bg-green-100 text-green-800';
	}

	function isSlotActive(dia: string, hora: string): boolean {
		const diaOk = preferencies_dies.length === 0 || preferencies_dies.includes(dia);
		const horaOk = preferencies_hores.length === 0 || preferencies_hores.includes(hora);
		return diaOk && horaOk;
	}

	$: playersWithoutAvailability = participants.filter(p => {
		const d = p.preferencies_dies || [];
		const h = p.preferencies_hores || [];
		return d.length === 0 && h.length === 0;
	});

	function playerNom(p: any): string {
		// Fase 5c+: la relació va directament a `socis`. El fallback a
		// `players.socis` és per registres antics abans de la migració.
		const s = p.socis ?? p.players?.socis;
		return s ? `${s.nom} ${s.cognoms}` : '—';
	}
</script>

<div class="hcap-component-root">
{#if mode === 'individual'}
	<!-- ── Mode individual: selecció interactiva ─────────────── -->
	<div>
		<div class="mb-3">
			<p class="mb-1 text-xs text-gray-500">Clica per activar/desactivar disponibilitat</p>
			<div class="overflow-x-auto">
				<table class="w-full text-xs border-collapse">
					<thead>
						<tr>
							<th class="border border-gray-200 bg-gray-50 px-2 py-1 text-left w-16">Hora</th>
							{#each dies as dia}
								<th class="border border-gray-200 bg-gray-50 px-2 py-1 text-center w-14">{dia.full}</th>
							{/each}
						</tr>
					</thead>
					<tbody>
						{#each horesDisponibles as hora}
							<tr>
								<td class="border border-gray-200 px-2 py-1 font-medium text-gray-700">{hora}</td>
								{#each dies as dia}
									{@const active = isSlotActive(dia.value, hora)}
									<td class="border border-gray-200 p-0">
										<button
											type="button"
											on:click={() => {
												// Toggle both dia and hora independently
												if (!preferencies_dies.includes(dia.value) && !preferencies_hores.includes(hora)) {
													// Both unrestricted → restrict this slot by adding both
													toggleDia(dia.value);
													toggleHora(hora);
												} else if (preferencies_dies.includes(dia.value) && preferencies_hores.includes(hora)) {
													toggleDia(dia.value);
													toggleHora(hora);
												} else if (!preferencies_dies.includes(dia.value)) {
													toggleDia(dia.value);
												} else {
													toggleHora(hora);
												}
											}}
											class="w-full h-full min-h-[32px] text-center transition-colors {
												active
													? 'bg-purple-100 text-purple-800 hover:bg-purple-200'
													: 'bg-gray-100 text-gray-400 hover:bg-gray-200'
											}"
											title="{dia.full} {hora}: {active ? 'disponible' : 'no disponible'}"
										>
											{active ? '✓' : ''}
										</button>
									</td>
								{/each}
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>

		<!-- Quick toggles -->
		<div class="flex flex-wrap gap-4 text-xs text-gray-600 mt-2">
			<div>
				<span class="font-medium mr-1">Dies:</span>
				{#each dies as dia}
					<button
						type="button"
						on:click={() => toggleDia(dia.value)}
						class="mr-1 rounded px-2 py-0.5 border {preferencies_dies.includes(dia.value) ? 'border-purple-500 bg-purple-100 text-purple-800' : 'border-gray-300 bg-white text-gray-600 hover:bg-gray-50'}"
					>
						{dia.label}
					</button>
				{/each}
			</div>
			<div>
				<span class="font-medium mr-1">Hores:</span>
				{#each horesDisponibles as hora}
					<button
						type="button"
						on:click={() => toggleHora(hora)}
						class="mr-1 rounded px-2 py-0.5 border {preferencies_hores.includes(hora) ? 'border-purple-500 bg-purple-100 text-purple-800' : 'border-gray-300 bg-white text-gray-600 hover:bg-gray-50'}"
					>
						{hora}
					</button>
				{/each}
			</div>
		</div>

		{#if preferencies_dies.length === 0 && preferencies_hores.length === 0}
			<p class="mt-2 text-xs text-amber-600">Sense restriccions declarades → disponible tots els slots.</p>
		{/if}
	</div>

{:else}
	<!-- ── Mode resum: vista agregada ────────────────────────── -->
	{#if participants.length === 0}
		<p class="text-sm text-gray-500">Sense participants inscrits.</p>
	{:else}
		{#if playersWithoutAvailability.length > 0}
			<div class="mb-3 rounded border border-amber-300 bg-amber-50 p-2 text-xs text-amber-800">
				<strong>{playersWithoutAvailability.length} jugador{playersWithoutAvailability.length !== 1 ? 's' : ''} sense disponibilitat declarada</strong>
				(es consideren disponibles a tots els slots):
				{playersWithoutAvailability.map(p => playerNom(p)).join(', ')}
			</div>
		{/if}

		<div class="overflow-x-auto">
			<table class="w-full text-xs border-collapse">
				<thead>
					<tr>
						<th class="border border-gray-200 bg-gray-50 px-2 py-1 text-left w-16">Hora</th>
						{#each dies as dia}
							<th class="border border-gray-200 bg-gray-50 px-2 py-1 text-center">{dia.full}</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each horesDisponibles as hora}
						<tr>
							<td class="border border-gray-200 px-2 py-1 font-medium text-gray-700">{hora}</td>
							{#each dies as dia}
								{@const count = countAvailable(dia.value, hora)}
								<td class="border border-gray-200 px-2 py-1 text-center {slotColor(count, participants.length)}"
									title="{count}/{participants.length} jugadors disponibles {dia.full} {hora}">
									{count}/{participants.length}
								</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
		<div class="mt-2 flex flex-wrap gap-3 text-xs text-gray-500">
			<span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded bg-green-200"></span> Molts disponibles</span>
			<span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded bg-yellow-200"></span> Disponibilitat moderada</span>
			<span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded bg-orange-200"></span> Pocs disponibles</span>
			<span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded bg-red-200"></span> Crític (&lt;2)</span>
		</div>
	{/if}
{/if}
</div>

<style>
	.hcap-component-root :global(.bg-white) { background: var(--paper-elevated) !important; }
	.hcap-component-root :global(.bg-gray-50),
	.hcap-component-root :global(.bg-gray-100) { background: var(--paper) !important; color: var(--ink-soft) !important; }
	.hcap-component-root :global(.bg-gray-200) { background: var(--rule) !important; }

	.hcap-component-root :global(.bg-green-100),
	.hcap-component-root :global(.bg-green-200) { background: var(--paper) !important; color: var(--green) !important; border: 1px solid var(--green) !important; }
	.hcap-component-root :global(.bg-yellow-100),
	.hcap-component-root :global(.bg-yellow-200) { background: var(--paper) !important; color: var(--amber) !important; border: 1px solid var(--amber) !important; }
	.hcap-component-root :global(.bg-orange-100),
	.hcap-component-root :global(.bg-orange-200) { background: var(--paper) !important; color: #c2410c !important; border: 1px solid #c2410c !important; }
	.hcap-component-root :global(.bg-red-100),
	.hcap-component-root :global(.bg-red-200) { background: var(--paper) !important; color: var(--accent) !important; border: 1px solid var(--accent) !important; }
	.hcap-component-root :global(.bg-amber-50) { background: var(--paper) !important; border: 1px solid var(--amber) !important; }
	.hcap-component-root :global(.bg-purple-100),
	.hcap-component-root :global(.bg-purple-200) { background: var(--paper) !important; color: var(--sec-handicap) !important; border: 1px solid var(--sec-handicap) !important; }

	.hcap-component-root :global(.text-green-800) { color: var(--green) !important; }
	.hcap-component-root :global(.text-yellow-700),
	.hcap-component-root :global(.text-amber-600),
	.hcap-component-root :global(.text-amber-800) { color: var(--amber) !important; }
	.hcap-component-root :global(.text-orange-800) { color: #c2410c !important; }
	.hcap-component-root :global(.text-red-800) { color: var(--accent) !important; }
	.hcap-component-root :global(.text-purple-800) { color: var(--sec-handicap) !important; }
	.hcap-component-root :global(.text-gray-400),
	.hcap-component-root :global(.text-gray-500),
	.hcap-component-root :global(.text-gray-600) { color: var(--ink-soft) !important; }
	.hcap-component-root :global(.text-gray-700) { color: var(--ink) !important; }

	.hcap-component-root :global(.border-gray-200),
	.hcap-component-root :global(.border-gray-300) { border-color: var(--rule) !important; }
	.hcap-component-root :global(.border-purple-500) { border-color: var(--sec-handicap) !important; }
	.hcap-component-root :global(.border-amber-300) { border-color: var(--amber) !important; }

	.hcap-component-root :global(.rounded),
	.hcap-component-root :global(.rounded-sm),
	.hcap-component-root :global(.rounded-md),
	.hcap-component-root :global(.rounded-lg),
	.hcap-component-root :global(.rounded-xl) { border-radius: 0 !important; }

	.hcap-component-root :global(table) { font-family: var(--font-sans); }
	.hcap-component-root :global(button) { font-family: var(--font-sans); }
</style>
