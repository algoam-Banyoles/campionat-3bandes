<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import type { PageData } from './$types';

	export let data: PageData;

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

	let mitjanes: MitjanaHistorica[] = data.mitjanes || [];
	let socis: Soci[] = data.socis || [];
	 // Pagination from server
	let serverPage: number = data.page ?? 1;
	let serverLimit: number = data.limit ?? 200;
	let serverTotal: number | null = data.total ?? null;
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
		// Extreure filtres únics de les dades carregades del servidor
		modalitats = [...new Set(mitjanes.map(m => m.modalitat))].sort();
		years = [...new Set(mitjanes.map(m => m.year))].sort((a, b) => b - a);
	});

	async function reloadData() {
		// Recarregar dades després d'una modificació
		location.reload();
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
			alert('Error assignant el soci. Intenta-ho de nou.');
		} finally {
			saving = false;
		}
	}

	async function removeAssignment(mitjanaId: number) {
		if (!confirm('Estàs segur que vols desassignar aquest soci?')) return;

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
			alert('Error desassignant el soci. Intenta-ho de nou.');
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
		loading = true;
		const params = new URLSearchParams(location.search);
		params.set('page', String(p));
 		if (serverLimit) params.set('limit', String(serverLimit));
		await goto(`${location.pathname}?${params.toString()}`, { replaceState: false });
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
			const matchesSearch = !searchTerm || 
				m.soci_id?.toString().includes(searchTerm) ||
				m.nom_soci?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				m.cognoms_soci?.toLowerCase().includes(searchTerm.toLowerCase());
			
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
	<title>Gestió Mitjanes Històriques - Admin</title>
</svelte:head>

<div class="container mx-auto p-4">
	<div class="mb-6">
		<h1 class="text-3xl font-bold text-gray-900 mb-2">Gestió Mitjanes Històriques</h1>
		<p class="text-gray-600">Assigna o corregeix les mitjanes històriques als socis corresponents</p>
	</div>

	<!-- Estadístiques -->
	<div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
		<div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
			<div class="text-2xl font-bold text-blue-600">{stats.total}</div>
			<div class="text-sm text-blue-800">Total mitjanes</div>
		</div>
		<div class="bg-green-50 border border-green-200 rounded-lg p-4">
			<div class="text-2xl font-bold text-green-600">{stats.assigned}</div>
			<div class="text-sm text-green-800">Assignades</div>
		</div>
		<div class="bg-orange-50 border border-orange-200 rounded-lg p-4">
			<div class="text-2xl font-bold text-orange-600">{stats.unassigned}</div>
			<div class="text-sm text-orange-800">No assignades</div>
		</div>
	</div>

	<!-- Filtres -->
	<div class="bg-white rounded-lg shadow p-4 mb-6">
		<div class="grid grid-cols-1 md:grid-cols-4 gap-4">
			<div>
				<label for="search" class="block text-sm font-medium text-gray-700 mb-1">Cerca</label>
				<input
					type="text"
					id="search"
					bind:value={searchTerm}
					placeholder="ID soci, nom o cognoms..."
					class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
				/>
			</div>
			<div>
				<label for="modalitat" class="block text-sm font-medium text-gray-700 mb-1">Modalitat</label>
				<select
					id="modalitat"
					bind:value={selectedModalitat}
					class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
				>
					<option value="">Totes les modalitats</option>
					{#each modalitats as modalitat}
						<option value={modalitat}>{modalitat}</option>
					{/each}
				</select>
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
						selectedModalitat = '';
						selectedYear = '';
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
								ID Soci
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Soci Assignat
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
								<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
									{mitjana.soci_id || 'No assignat'}
								</td>
								<td class="px-6 py-4 whitespace-nowrap">
									{#if editingId === mitjana.id}
										<select
											bind:value={tempSociId}
											class="max-w-xs px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
										>
											<option value="">Selecciona un soci...</option>
											{#each socis as soci}
												<option value={soci.numero_soci.toString()}>
													{soci.numero_soci} - {soci.cognoms}, {soci.nom}
												</option>
											{/each}
										</select>
									{:else if mitjana.nom_soci && mitjana.cognoms_soci}
										<div class="text-sm text-gray-900 font-medium">
											{mitjana.cognoms_soci}, {mitjana.nom_soci}
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
					Mostrant {filteredAndSortedMitjanes.length} de {serverTotal ?? mitjanes.length} mitjanes històriques
				</div>
				{#if serverPage}
					<div class="mt-3 flex items-center justify-center space-x-3">
						<button on:click={() => gotoPage(serverPage! - 1)} disabled={serverPage <= 1} class="px-3 py-1 border rounded">Anterior</button>
						<span>Pàgina {serverPage} {#if serverTotal !== null}de {Math.ceil(serverTotal / (serverLimit || 1))}{/if}</span>
						<button on:click={() => gotoPage(serverPage! + 1)} disabled={serverTotal !== null && serverPage! >= Math.ceil(serverTotal / (serverLimit || 1))} class="px-3 py-1 border rounded">Següent</button>
					</div>
				{/if}
		{/if}
	{/if}
</div>