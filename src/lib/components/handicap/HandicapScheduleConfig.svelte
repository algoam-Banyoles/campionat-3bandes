<script lang="ts">
	import { createEventDispatcher } from 'svelte';

	export let horaris_extra_enabled = false;
	export let horaris_extra_franja = '17:00';
	export let horaris_extra_dies: string[] = [];
	export let data_inici = '';
	export let data_fi = '';
	export let blockedPeriods: Array<{ start: string; end: string; description: string }> = [];
	export let participantsCount = 0;

	const dispatch = createEventDispatcher();
	const TAULES = 3;

	const diesSetmana = [
		{ value: 'dl', label: 'Dl', full: 'Dilluns' },
		{ value: 'dt', label: 'Dt', full: 'Dimarts' },
		{ value: 'dc', label: 'Dc', full: 'Dimecres' },
		{ value: 'dj', label: 'Dj', full: 'Dijous' },
		{ value: 'dv', label: 'Dv', full: 'Divendres' }
	];

	const horesEstandard = ['18:00', '19:00'];

	let showBlockedPeriods = false;
	let newBlockStart = '';
	let newBlockEnd = '';
	let newBlockDesc = '';

	function toggleDiaExtra(dia: string) {
		if (horaris_extra_dies.includes(dia)) {
			horaris_extra_dies = horaris_extra_dies.filter(d => d !== dia);
		} else {
			horaris_extra_dies = [...horaris_extra_dies, dia];
		}
		dispatch('change');
	}

	function addBlockedPeriod() {
		if (!newBlockStart || !newBlockEnd) return;
		if (new Date(newBlockStart) > new Date(newBlockEnd)) return;
		blockedPeriods = [...blockedPeriods, {
			start: newBlockStart,
			end: newBlockEnd,
			description: newBlockDesc || 'Bloqueig'
		}];
		newBlockStart = '';
		newBlockEnd = '';
		newBlockDesc = '';
		dispatch('change');
	}

	function removeBlockedPeriod(index: number) {
		blockedPeriods = blockedPeriods.filter((_, i) => i !== index);
		dispatch('change');
	}

	// Compute schedule grid
	$: horesDisponibles = horaris_extra_enabled
		? [horaris_extra_franja, ...horesEstandard]
		: [...horesEstandard];

	$: slotsPerDia = (dia: string): number => {
		const base = horesEstandard.length * TAULES;
		const extra = (horaris_extra_enabled && horaris_extra_dies.includes(dia)) ? TAULES : 0;
		return base + extra;
	};

	$: totalSlotsSetmana = diesSetmana.reduce((sum, d) => sum + slotsPerDia(d.value), 0);

	// Double elimination: N players -> approx 2N-1 matches (winners) + N-1 (losers) + 1-2 (grand final)
	// Simplified: ~2N - 1 total matches for double elim
	$: totalMatchesEstimacio = participantsCount > 1
		? 2 * participantsCount - 1
		: 0;

	$: setmanesEstimades = totalSlotsSetmana > 0 && totalMatchesEstimacio > 0
		? Math.ceil(totalMatchesEstimacio / totalSlotsSetmana)
		: 0;

	// Check if a day+hour has an extra slot
	function isExtraSlot(dia: string, hora: string): boolean {
		return hora === horaris_extra_franja && horaris_extra_enabled && horaris_extra_dies.includes(dia);
	}

	function isStandardSlot(_dia: string, hora: string): boolean {
		return horesEstandard.includes(hora);
	}
</script>

<div class="space-y-6">
	<!-- Dates del torneig -->
	<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
		<h3 class="mb-3 text-base font-semibold text-gray-900">Dates del Torneig</h3>
		<div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
			<div>
				<label for="hs_data_inici" class="block text-sm font-medium text-gray-700">Data d'inici</label>
				<input
					type="date"
					id="hs_data_inici"
					bind:value={data_inici}
					on:change={() => dispatch('change')}
					class="mt-1 block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-blue-500 focus:ring-blue-500"
				/>
			</div>
			<div>
				<label for="hs_data_fi" class="block text-sm font-medium text-gray-700">Data de fi</label>
				<input
					type="date"
					id="hs_data_fi"
					bind:value={data_fi}
					on:change={() => dispatch('change')}
					class="mt-1 block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-blue-500 focus:ring-blue-500"
				/>
			</div>
		</div>
		{#if data_inici && data_fi && new Date(data_inici) >= new Date(data_fi)}
			<p class="mt-2 text-xs text-red-600">La data de fi ha de ser posterior a la d'inici.</p>
		{/if}
	</div>

	<!-- Horaris -->
	<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
		<h3 class="mb-3 text-base font-semibold text-gray-900">Horaris</h3>

		<p class="mb-3 text-xs text-gray-500">
			Horaris estandard: {horesEstandard.join(' i ')} (dl-dv) &middot; {TAULES} taules per franja
		</p>

		<div class="flex items-center mb-3">
			<input
				type="checkbox"
				id="hs_extra"
				bind:checked={horaris_extra_enabled}
				on:change={() => dispatch('change')}
				class="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500"
			/>
			<label for="hs_extra" class="ml-2 text-sm font-medium text-gray-700">
				Habilitar franja extra
			</label>
		</div>

		{#if horaris_extra_enabled}
			<div class="ml-6 space-y-3 mb-4">
				<div>
					<label for="hs_franja" class="block text-sm font-medium text-gray-700">Hora de la franja extra</label>
					<input
						type="time"
						id="hs_franja"
						bind:value={horaris_extra_franja}
						on:change={() => dispatch('change')}
						class="mt-1 w-32 rounded-md border-gray-300 text-sm shadow-sm focus:border-blue-500 focus:ring-blue-500"
					/>
				</div>
				<div>
					<label class="mb-1 block text-sm font-medium text-gray-700">Dies amb franja extra</label>
					<div class="flex flex-wrap gap-2">
						{#each diesSetmana as dia}
							<button
								type="button"
								on:click={() => toggleDiaExtra(dia.value)}
								class="rounded-full border px-3 py-1 text-sm {
									horaris_extra_dies.includes(dia.value)
										? 'border-purple-600 bg-purple-600 text-white'
										: 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50'
								}"
							>
								{dia.full}
							</button>
						{/each}
					</div>
				</div>
			</div>
		{/if}

		<!-- Preview graella setmanal -->
		<div class="mt-4">
			<h4 class="mb-2 text-sm font-medium text-gray-700">Preview setmanal</h4>
			<div class="overflow-x-auto">
				<table class="w-full text-xs border-collapse">
					<thead>
						<tr>
							<th class="border border-gray-200 bg-gray-50 px-2 py-1 text-left">Hora</th>
							{#each diesSetmana as dia}
								<th class="border border-gray-200 bg-gray-50 px-2 py-1 text-center">{dia.label}</th>
							{/each}
						</tr>
					</thead>
					<tbody>
						{#each horesDisponibles.sort() as hora}
							<tr>
								<td class="border border-gray-200 px-2 py-1 font-medium text-gray-700">{hora}</td>
								{#each diesSetmana as dia}
									{@const isExtra = isExtraSlot(dia.value, hora)}
									{@const isStd = isStandardSlot(dia.value, hora)}
									{@const active = isStd || isExtra}
									<td class="border border-gray-200 px-2 py-1 text-center {
										active ? (isExtra ? 'bg-purple-50 text-purple-700' : 'bg-green-50 text-green-700') : 'bg-gray-100 text-gray-400'
									}">
										{#if active}
											{TAULES}T
										{:else}
											-
										{/if}
									</td>
								{/each}
							</tr>
						{/each}
						<tr class="font-semibold">
							<td class="border border-gray-200 bg-gray-50 px-2 py-1">Total</td>
							{#each diesSetmana as dia}
								<td class="border border-gray-200 bg-gray-50 px-2 py-1 text-center">{slotsPerDia(dia.value)}</td>
							{/each}
						</tr>
					</tbody>
				</table>
			</div>
			<p class="mt-2 text-sm text-gray-600">
				<strong>{totalSlotsSetmana}</strong> partides/setmana disponibles
			</p>
		</div>
	</div>

	<!-- Periodes de bloqueig -->
	<div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
		<div class="flex items-center justify-between mb-3">
			<h3 class="text-base font-semibold text-gray-900">Periodes de Bloqueig</h3>
			<button
				type="button"
				on:click={() => showBlockedPeriods = !showBlockedPeriods}
				class="text-xs text-purple-600 hover:text-purple-800"
			>
				{showBlockedPeriods ? 'Amagar' : 'Gestionar'}
			</button>
		</div>

		{#if blockedPeriods.length > 0}
			<div class="space-y-1 mb-3">
				{#each blockedPeriods as period, index}
					<div class="flex items-center justify-between rounded bg-red-50 px-3 py-1.5 text-xs">
						<span class="text-red-800">
							{period.start} - {period.end}: {period.description}
						</span>
						<button
							type="button"
							on:click={() => removeBlockedPeriod(index)}
							class="text-red-500 hover:text-red-700"
						>
							&#10005;
						</button>
					</div>
				{/each}
			</div>
		{:else}
			<p class="mb-3 text-xs text-gray-500">Cap periode bloquejat definit.</p>
		{/if}

		{#if showBlockedPeriods}
			<div class="rounded border border-gray-200 bg-gray-50 p-3">
				<div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
					<div>
						<label for="bp_start" class="block text-xs font-medium text-gray-700">Inici</label>
						<input type="date" id="bp_start" bind:value={newBlockStart}
							class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:border-blue-500 focus:ring-blue-500" />
					</div>
					<div>
						<label for="bp_end" class="block text-xs font-medium text-gray-700">Fi</label>
						<input type="date" id="bp_end" bind:value={newBlockEnd}
							class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:border-blue-500 focus:ring-blue-500" />
					</div>
					<div>
						<label for="bp_desc" class="block text-xs font-medium text-gray-700">Descripcio</label>
						<input type="text" id="bp_desc" bind:value={newBlockDesc} placeholder="Ex: Vacances Nadal"
							class="mt-1 block w-full rounded-md border-gray-300 text-xs shadow-sm focus:border-blue-500 focus:ring-blue-500" />
					</div>
				</div>
				<button
					type="button"
					on:click={addBlockedPeriod}
					disabled={!newBlockStart || !newBlockEnd}
					class="mt-2 rounded bg-red-600 px-3 py-1 text-xs font-medium text-white hover:bg-red-700 disabled:opacity-50"
				>
					Afegir bloqueig
				</button>
			</div>
		{/if}
	</div>

	<!-- Estimacio de durada -->
	{#if participantsCount > 1}
		<div class="rounded-lg border border-blue-200 bg-blue-50 p-4">
			<h3 class="mb-2 text-base font-semibold text-blue-900">Estimacio de Durada</h3>
			<div class="grid grid-cols-2 gap-3 text-sm">
				<div>
					<span class="text-blue-700">Jugadors inscrits:</span>
					<strong class="text-blue-900">{participantsCount}</strong>
				</div>
				<div>
					<span class="text-blue-700">Partides estimades:</span>
					<strong class="text-blue-900">~{totalMatchesEstimacio}</strong>
				</div>
				<div>
					<span class="text-blue-700">Slots/setmana:</span>
					<strong class="text-blue-900">{totalSlotsSetmana}</strong>
				</div>
				<div>
					<span class="text-blue-700">Setmanes estimades:</span>
					<strong class="text-blue-900">{setmanesEstimades > 0 ? `~${setmanesEstimades}` : '-'}</strong>
				</div>
			</div>
			<p class="mt-2 text-xs text-blue-600">
				Doble eliminacio: ~2N-1 partides. Estimacio basica sense considerar bloqueigs ni disponibilitat.
			</p>
		</div>
	{/if}
</div>
