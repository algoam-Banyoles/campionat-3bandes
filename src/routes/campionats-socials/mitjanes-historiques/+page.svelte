<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import { showError } from '$lib/stores/toastStore';
	import { showConfirm } from '$lib/stores/confirmDialogStore';
	import { effectiveIsAdmin } from '$lib/stores/viewMode';
	import { formatarNomJugador } from '$lib/utils/playerUtils';

	function nomComplet(nom: string | null | undefined, cognoms: string | null | undefined): string {
		const raw = `${nom ?? ''} ${cognoms ?? ''}`.trim();
		return raw ? formatarNomJugador(raw) : '';
	}

	type MitjanaHistorica = {
		id: number;
		soci_id: number | null;
		year: number;
		modalitat: string;
		mitjana: number;
		nom_soci?: string | null;
		cognoms_soci?: string | null;
		socis?: { numero_soci: number; nom: string; cognoms: string; }[];
	};

	type Soci = {
		numero_soci: number;
		nom: string;
		cognoms: string;
		email: string | null;
	};

	let mitjanes: MitjanaHistorica[] = [];
	let socis: Soci[] = [];

	// Client-side pagination (límit alt perquè es vegin totes les temporades alhora)
	let currentPage: number = 1;
	let pageLimit: number = 10000;
	let totalCount: number | null = null;
	let loading = false;
	let searchTerm = '';
	let selectedModalitat = '';
	let selectedYear = '';
	let editingId: number | null = null;
	let tempSociId = '';
	let saving = false;

	// Ordenació
	let sortBy = 'year';
	let sortOrder: 'asc' | 'desc' = 'desc';

	// Filtres disponibles
	let modalitats: string[] = [];
	let years: number[] = [];

	onMount(() => {
		loadData();
	});

	async function loadData() {
		loading = true;
		try {
			console.log('Loading mitjanes històriques client-side...');

			// Load mitjanes with pagination
			const from = (currentPage - 1) * pageLimit;
			const to = from + pageLimit - 1;

			const { data: mitjanesList, error: mitjError, count } = await supabase
				.from('mitjanes_historiques')
				.select('*', { count: 'exact' })
				.order('year', { ascending: false })
				.order('mitjana', { ascending: false })
				.range(from, to);

			if (mitjError) {
				console.error('Error loading mitjanes:', mitjError);
				throw mitjError;
			}

			console.log(`Loaded ${mitjanesList?.length || 0} mitjanes`);
			totalCount = count;

			// Load all socis
			const { data: socisList, error: socisError } = await supabase
				.from('socis')
				.select('numero_soci, nom, cognoms, email')
				.order('cognoms');

			if (socisError) {
				console.error('Error loading socis:', socisError);
				throw socisError;
			}

			console.log(`Loaded ${socisList?.length || 0} socis`);

			// Create socis map for quick lookup
			const socisMap = new Map();
			(socisList || []).forEach(soci => {
				socisMap.set(soci.numero_soci, soci);
			});

			// Process mitjanes to include soci info
			const processedMitjanes = (mitjanesList || []).map(m => {
				const soci = socisMap.get(m.soci_id);
				return {
					...m,
					nom_soci: soci?.nom || null,
					cognoms_soci: soci?.cognoms || null
				};
			});

			mitjanes = processedMitjanes;
			socis = socisList || [];

			// Carregar TOTS els filtres disponibles (no només els de la pàgina actual).
			await loadAllFilters();

		} catch (error) {
			console.error('Error loading data:', error);
			showError('Error carregant les dades. Comprova la consola per més detalls.');
		} finally {
			loading = false;
		}
	}

	/**
	 * Llista totes les modalitats i anys disponibles a la taula `mitjanes_historiques`,
	 * independentment de la pàgina actual. Així el desplegable "Any" mostra totes les
	 * temporades, no només les que apareixen en els 200 registres carregats.
	 */
	async function loadAllFilters() {
		const { data, error: filtersError } = await supabase
			.from('mitjanes_historiques')
			.select('year, modalitat')
			.order('year', { ascending: false })
			.limit(20000);

		if (filtersError) {
			console.warn('Error loading filters:', filtersError);
			// Fallback: usar les dades carregades
			modalitats = [...new Set(mitjanes.map((m) => m.modalitat))].sort();
			years = [...new Set(mitjanes.map((m) => m.year))].sort((a, b) => b - a);
			return;
		}

		const all = data ?? [];
		modalitats = [...new Set(all.map((r) => r.modalitat).filter(Boolean))].sort();
		years = [...new Set(all.map((r) => r.year as number).filter((y) => typeof y === 'number'))]
			.sort((a, b) => b - a);

		// Garantim que sempre hi hagi una modalitat seleccionada (no té sentit veure-les barrejades)
		if (!selectedModalitat && modalitats.length > 0) {
			selectedModalitat = modalitats[0];
		}
	}

	async function reloadData() {
		// Recarregar dades després d'una modificació
		await loadData();
	}

	function startEditing(mitjana: MitjanaHistorica) {
		editingId = mitjana.id;
		tempSociId = mitjana.soci_id?.toString() || '';
	}

	function cancelEditing() {
		editingId = null;
		tempSociId = '';
	}

	async function saveAssignment(mitjanaId: number) {
		if (!$effectiveIsAdmin) return;
		if (!tempSociId) return;

		saving = true;
		try {
			const { error } = await supabase
				.from('mitjanes_historiques')
				.update({ soci_id: parseInt(tempSociId) })
				.eq('id', mitjanaId);

			if (error) throw error;

			// Recarregar la pàgina per obtenir dades actualitzades
			await reloadData();
		} catch (error) {
			console.error('Error assignant soci:', error);
			showError('Error assignant el soci. Intenta-ho de nou.');
		} finally {
			saving = false;
		}
	}

	async function removeAssignment(mitjanaId: number) {
		if (!$effectiveIsAdmin) return;
		const ok = await showConfirm({
			title: 'Desassignar soci',
			message: 'Estàs segur que vols desassignar aquest soci?',
			severity: 'warning',
			confirmLabel: 'Desassignar'
		});
		if (!ok) return;

		saving = true;
		try {
			const { error } = await supabase
				.from('mitjanes_historiques')
				.update({ soci_id: null })
				.eq('id', mitjanaId);

			if (error) throw error;

			await reloadData();
		} catch (error) {
			console.error('Error desassignant soci:', error);
			showError('Error desassignant el soci. Intenta-ho de nou.');
		} finally {
			saving = false;
		}
	}

	function changeSorting(newSortBy: string) {
		if (sortBy === newSortBy) {
			// Si ja estem ordenant per aquest camp, canviem l'ordre
			sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
		} else {
			// Nou camp d'ordenació
			sortBy = newSortBy;
			// Per dates i mitjanes, per defecte desc; per noms, asc
			sortOrder = ['year', 'mitjana', 'soci_id'].includes(newSortBy) ? 'desc' : 'asc';
		}
	}

async function gotoPage(p: number) {
		if (!p || p < 1) return;
		currentPage = p;
		await loadData();
	}

	// Funció d'ordenació
	function sortMitjanes(mitjanes: MitjanaHistorica[], sortBy: string, sortOrder: 'asc' | 'desc') {
		return [...mitjanes].sort((a, b) => {
			let aVal, bVal;
			
			switch (sortBy) {
				case 'year':
					aVal = a.year;
					bVal = b.year;
					break;
				case 'modalitat':
					aVal = a.modalitat;
					bVal = b.modalitat;
					break;
				case 'mitjana':
					aVal = a.mitjana;
					bVal = b.mitjana;
					break;
				case 'nom':
					aVal = a.nom_soci || '';
					bVal = b.nom_soci || '';
					break;
				case 'cognoms':
					aVal = a.cognoms_soci || '';
					bVal = b.cognoms_soci || '';
					break;
				case 'soci_id':
					aVal = a.soci_id || 0;
					bVal = b.soci_id || 0;
					break;
				case 'assignacio':
					aVal = a.soci_id ? 1 : 0; // Assignats primer
					bVal = b.soci_id ? 1 : 0;
					break;
				default:
					aVal = a.year;
					bVal = b.year;
			}
			
			if (typeof aVal === 'string' && typeof bVal === 'string') {
				const comparison = aVal.localeCompare(bVal);
				return sortOrder === 'asc' ? comparison : -comparison;
			} else {
				const comparison = aVal < bVal ? -1 : aVal > bVal ? 1 : 0;
				return sortOrder === 'asc' ? comparison : -comparison;
			}
		});
	}

	// Filtrar i ordenar mitjanes
	$: filteredAndSortedMitjanes = sortMitjanes(
		mitjanes.filter(m => {
			const q = searchTerm.toLowerCase();
			const matchesSearch = !searchTerm ||
				m.nom_soci?.toLowerCase().includes(q) ||
				m.cognoms_soci?.toLowerCase().includes(q);

			const matchesModalitat = !selectedModalitat || m.modalitat === selectedModalitat;
			const matchesYear = !selectedYear || m.year.toString() === selectedYear;

			return matchesSearch && matchesModalitat && matchesYear;
		}),
		sortBy,
		sortOrder
	);

	// Estadístiques
	$: stats = {
		total: mitjanes.length,
		assigned: mitjanes.filter(m => m.soci_id).length,
		unassigned: mitjanes.filter(m => !m.soci_id).length
	};
</script>

<svelte:head>
	<title>Mitjanes Històriques</title>
</svelte:head>

<div class="mh-root">
	<header class="mh-mast">
		<div class="editorial-eyebrow">Foment Martinenc · Secció billar</div>
		<h1 class="mh-title">Mitjanes històriques</h1>
		<p class="mh-sub">Registre de mitjanes per soci, modalitat i temporada.</p>
	</header>


	<!-- Filtres -->
	<div class="bg-white rounded-lg shadow p-4 mb-6 space-y-4">
		<!-- Modalitats: pills (cap "totes" — sempre cal triar-ne una) -->
		<div>
			<span class="block text-sm font-medium text-gray-700 mb-2">Modalitat</span>
			<div class="flex flex-wrap gap-2">
				{#each modalitats as modalitat}
					<button
						type="button"
						on:click={() => selectedModalitat = modalitat}
						class="modality-pill"
						class:active={selectedModalitat === modalitat}
					>
						{modalitat}
					</button>
				{/each}
			</div>
		</div>

		<!-- Cerca + any + reset -->
		<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
			<div>
				<label for="search" class="block text-sm font-medium text-gray-700 mb-1">Cerca per nom</label>
				<input
					type="text"
					id="search"
					bind:value={searchTerm}
					placeholder="Nom o cognoms…"
					class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
				/>
			</div>
			<div>
				<label for="year" class="block text-sm font-medium text-gray-700 mb-1">Any</label>
				<select
					id="year"
					bind:value={selectedYear}
					class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
				>
					<option value="">Tots els anys</option>
					{#each years as year}
						<option value={year.toString()}>{year}</option>
					{/each}
				</select>
			</div>
			<div class="flex items-end">
				<button
					on:click={() => {
						searchTerm = '';
						selectedYear = '';
						// La modalitat sempre roman seleccionada — netejar-la no té sentit
					}}
					class="w-full px-4 py-2 bg-gray-500 text-white rounded-md hover:bg-gray-600 transition-colors"
				>
					Netejar filtres
				</button>
			</div>
		</div>
	</div>

	<!-- Controls d'ordenació -->
	<div class="bg-white rounded-lg shadow p-4 mb-6">
		<div class="flex flex-wrap items-center gap-2">
			<span class="text-sm font-medium text-gray-700 mr-2">Ordenar per:</span>
			
			<button
				on:click={() => changeSorting('year')}
				class="px-3 py-1 text-sm rounded-md border transition-colors {sortBy === 'year' 
					? 'bg-blue-100 border-blue-300 text-blue-700' 
					: 'bg-gray-50 border-gray-300 text-gray-700 hover:bg-gray-100'}"
			>
				Any
				{#if sortBy === 'year'}
					<span class="ml-1">{sortOrder === 'asc' ? '↑' : '↓'}</span>
				{/if}
			</button>
			
			<button
				on:click={() => changeSorting('modalitat')}
				class="px-3 py-1 text-sm rounded-md border transition-colors {sortBy === 'modalitat' 
					? 'bg-blue-100 border-blue-300 text-blue-700' 
					: 'bg-gray-50 border-gray-300 text-gray-700 hover:bg-gray-100'}"
			>
				Modalitat
				{#if sortBy === 'modalitat'}
					<span class="ml-1">{sortOrder === 'asc' ? '↑' : '↓'}</span>
				{/if}
			</button>
			
			<button
				on:click={() => changeSorting('mitjana')}
				class="px-3 py-1 text-sm rounded-md border transition-colors {sortBy === 'mitjana' 
					? 'bg-blue-100 border-blue-300 text-blue-700' 
					: 'bg-gray-50 border-gray-300 text-gray-700 hover:bg-gray-100'}"
			>
				Mitjana
				{#if sortBy === 'mitjana'}
					<span class="ml-1">{sortOrder === 'asc' ? '↑' : '↓'}</span>
				{/if}
			</button>
			
			<button
				on:click={() => changeSorting('nom')}
				class="px-3 py-1 text-sm rounded-md border transition-colors {sortBy === 'nom' 
					? 'bg-blue-100 border-blue-300 text-blue-700' 
					: 'bg-gray-50 border-gray-300 text-gray-700 hover:bg-gray-100'}"
			>
				Nom
				{#if sortBy === 'nom'}
					<span class="ml-1">{sortOrder === 'asc' ? '↑' : '↓'}</span>
				{/if}
			</button>
			
			<button
				on:click={() => changeSorting('cognoms')}
				class="px-3 py-1 text-sm rounded-md border transition-colors {sortBy === 'cognoms' 
					? 'bg-blue-100 border-blue-300 text-blue-700' 
					: 'bg-gray-50 border-gray-300 text-gray-700 hover:bg-gray-100'}"
			>
				Cognoms
				{#if sortBy === 'cognoms'}
					<span class="ml-1">{sortOrder === 'asc' ? '↑' : '↓'}</span>
				{/if}
			</button>
			
			<button
				on:click={() => changeSorting('assignacio')}
				class="px-3 py-1 text-sm rounded-md border transition-colors {sortBy === 'assignacio' 
					? 'bg-blue-100 border-blue-300 text-blue-700' 
					: 'bg-gray-50 border-gray-300 text-gray-700 hover:bg-gray-100'}"
			>
				Assignació
				{#if sortBy === 'assignacio'}
					<span class="ml-1">{sortOrder === 'asc' ? '↑' : '↓'}</span>
				{/if}
			</button>
		</div>
	</div>

	{#if loading}
		<div class="flex justify-center items-center py-12">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
			<span class="ml-2 text-gray-600">Carregant mitjanes...</span>
		</div>
	{:else}
		<!-- Taula de mitjanes -->
		<div class="bg-white rounded-lg shadow overflow-hidden">
			<div class="overflow-x-auto">
				<table class="min-w-full divide-y divide-gray-200">
					<thead class="bg-gray-50">
						<tr>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Soci
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Any
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Modalitat
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Mitjana
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Accions
							</th>
						</tr>
					</thead>
					<tbody class="bg-white divide-y divide-gray-200">
						{#each filteredAndSortedMitjanes as mitjana (mitjana.id)}
							<tr class:bg-orange-50={!mitjana.soci_id}>
								<td class="px-6 py-4 whitespace-nowrap">
									{#if editingId === mitjana.id}
										<select
											bind:value={tempSociId}
											class="max-w-xs px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
										>
											<option value="">Selecciona un soci…</option>
											{#each socis as soci}
												<option value={soci.numero_soci.toString()}>
													{nomComplet(soci.nom, soci.cognoms)}
												</option>
											{/each}
										</select>
									{:else if mitjana.nom_soci && mitjana.cognoms_soci}
										<div class="text-sm text-gray-900 font-medium">
											{nomComplet(mitjana.nom_soci, mitjana.cognoms_soci)}
										</div>
									{:else}
										<span class="text-sm text-orange-600 font-medium">No assignat</span>
									{/if}
								</td>
								<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
									{mitjana.year}
								</td>
								<td class="px-6 py-4 whitespace-nowrap">
									<span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
										{mitjana.modalitat}
									</span>
								</td>
								<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-mono">
									{mitjana.mitjana.toFixed(3)}
								</td>
								<td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
									{#if $effectiveIsAdmin}
										{#if editingId === mitjana.id}
											<div class="flex space-x-2">
												<button
													on:click={() => saveAssignment(mitjana.id)}
													disabled={saving || !tempSociId}
													class="text-green-600 hover:text-green-900 disabled:text-gray-400"
												>
													{saving ? 'Guardant...' : 'Guardar'}
												</button>
												<button
													on:click={cancelEditing}
													disabled={saving}
													class="text-gray-600 hover:text-gray-900 disabled:text-gray-400"
												>
													Cancel·lar
												</button>
											</div>
										{:else}
											<div class="flex space-x-2">
												<button
													on:click={() => startEditing(mitjana)}
													class="text-blue-600 hover:text-blue-900"
												>
													{mitjana.soci_id ? 'Editar' : 'Assignar'}
												</button>
												{#if mitjana.soci_id}
													<button
														on:click={() => removeAssignment(mitjana.id)}
														class="text-red-600 hover:text-red-900"
													>
														Desassignar
													</button>
												{/if}
											</div>
										{/if}
									{:else}
										<span class="text-xs text-gray-400">—</span>
									{/if}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			{#if filteredAndSortedMitjanes.length === 0}
				<div class="text-center py-12">
					<div class="text-gray-500 text-lg">No s'han trobat mitjanes amb els filtres aplicats</div>
				</div>
			{/if}
		</div>

		<!-- Paginació (si cal) -->
		{#if filteredAndSortedMitjanes.length > 0}
				<div class="mt-4 text-sm text-gray-600 text-center">
					Mostrant {filteredAndSortedMitjanes.length} de {totalCount ?? mitjanes.length} mitjanes històriques
				</div>
				{#if totalCount && totalCount > pageLimit}
					<div class="mt-3 flex items-center justify-center space-x-3">
						<button on:click={() => gotoPage(currentPage - 1)} disabled={currentPage <= 1} class="px-3 py-1 border rounded">Anterior</button>
						<span>Pàgina {currentPage} de {Math.ceil(totalCount / pageLimit)}</span>
						<button on:click={() => gotoPage(currentPage + 1)} disabled={currentPage >= Math.ceil(totalCount / pageLimit)} class="px-3 py-1 border rounded">Següent</button>
					</div>
				{/if}
		{/if}
	{/if}
</div>

<style>
	.mh-root {
		max-width: 1180px;
		margin: 0 auto;
		padding: 1.75rem 1.25rem 4rem;
		font-family: var(--font-sans, sans-serif);
		color: var(--ink, #1a1814);
	}
	.mh-mast {
		margin-bottom: 1.75rem;
		padding-bottom: 1.1rem;
		border-bottom: 2px solid var(--ink, #1a1814);
	}
	.mh-title {
		margin: 0.4rem 0 0.4rem;
		font-size: clamp(1.75rem, 2.4vw, 2.4rem);
		font-weight: 800;
		letter-spacing: -0.022em;
		line-height: 1.1;
		color: var(--ink, #1a1814);
	}
	.mh-sub {
		margin: 0;
		font-size: 0.9375rem;
		color: var(--ink-2, #4a443e);
		max-width: 56ch;
	}
	.editorial-eyebrow {
		font-size: 0.625rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.16em;
		color: var(--ink-3, #807a72);
	}

	/* (Targes d'estadístiques mh-stat-* eliminades del template — no s'usen) */

	/* Modality pills */
	.modality-pill {
		background: transparent;
		border: 1px solid var(--rule-strong, #b8b3a8);
		color: var(--ink-2, #4a443e);
		padding: 0.4rem 0.85rem;
		font-family: var(--font-sans, sans-serif);
		font-weight: 600;
		font-size: 0.875rem;
		letter-spacing: -0.005em;
		cursor: pointer;
		min-height: 36px;
	}
	.modality-pill:hover { color: var(--ink, #1a1814); border-color: var(--ink, #1a1814); }
	.modality-pill.active {
		background: var(--ink, #1a1814);
		color: var(--paper, #fbfaf6);
		border-color: var(--ink, #1a1814);
	}

	/* Overrides Tailwind dins de .mh-root */
	.mh-root :global(.bg-white) {
		background: var(--paper-elevated, #fff) !important;
	}
	.mh-root :global(.bg-gray-50) {
		background: var(--paper, #fbfaf6) !important;
	}
	.mh-root :global(.bg-orange-50) {
		background: var(--paper, #fbfaf6) !important;
	}
	.mh-root :global(.shadow),
	.mh-root :global(.shadow-sm),
	.mh-root :global(.shadow-md) { box-shadow: none !important; }
	.mh-root :global(.rounded),
	.mh-root :global(.rounded-sm),
	.mh-root :global(.rounded-md),
	.mh-root :global(.rounded-lg),
	.mh-root :global(.rounded-full) { border-radius: 0 !important; }

	.mh-root :global(.bg-blue-100) {
		background: var(--paper, #fbfaf6) !important;
		color: var(--blue, #1f4a99) !important;
		border: 1px solid var(--blue, #1f4a99) !important;
	}
	.mh-root :global(.text-blue-800),
	.mh-root :global(.text-blue-600) { color: var(--blue, #1f4a99) !important; }
	.mh-root :global(.text-orange-600) { color: var(--amber, #b8860b) !important; }
	.mh-root :global(.text-gray-500),
	.mh-root :global(.text-gray-600) { color: var(--ink-3, #807a72) !important; }
	.mh-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
	.mh-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
	.mh-root :global(.text-green-600),
	.mh-root :global(.text-green-900) { color: var(--green, #1f7a3a) !important; }
	.mh-root :global(.text-red-600),
	.mh-root :global(.text-red-900) { color: var(--accent, #a30b1e) !important; }

	.mh-root :global(.border-gray-200),
	.mh-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }

	/* Botons "Netejar filtres" i d'ordenació */
	.mh-root :global(button.bg-gray-500) {
		background: var(--ink-2, #4a443e) !important;
		color: var(--paper, #fbfaf6) !important;
		border-radius: 0 !important;
	}
	.mh-root :global(button.bg-blue-100) {
		background: var(--paper, #fbfaf6) !important;
		color: var(--ink, #1a1814) !important;
		border: 1px solid var(--ink, #1a1814) !important;
	}

	.mh-root :global(input),
	.mh-root :global(select),
	.mh-root :global(textarea) {
		background: var(--paper-elevated, #fff) !important;
		border: 1px solid var(--rule-strong, #b8b3a8) !important;
		border-radius: 0 !important;
		font-family: var(--font-sans, sans-serif);
	}
	.mh-root :global(input:focus),
	.mh-root :global(select:focus) {
		outline: 2px solid var(--ink, #1a1814);
		outline-offset: -1px;
	}

	.mh-root :global(table) { font-family: var(--font-sans, sans-serif); }
	.mh-root :global(thead.bg-gray-50) {
		background: var(--paper, #fbfaf6) !important;
		border-bottom: 1px solid var(--ink, #1a1814) !important;
	}
	.mh-root :global(tr.bg-orange-50) {
		background: color-mix(in srgb, var(--amber, #b8860b) 8%, var(--paper-elevated, #fff)) !important;
	}
</style>