<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { goto } from '$app/navigation';

	type MitjanaHistorica = {
		id: string;
		soci_id: number | null;
		year: number;
		modalitat: string;
		mitjana: number | null;
		partides: number | null;
		creat_el: string;
	};

	type Soci = {
		id: string;
		numero_soci: number;
		nom: string;
		cognoms: string;
		email: string | null;
		telefon: string | null;
		actiu: boolean;
		creat_el: string;
		actualitzat_el: string;
	};

	let mitjanes: (MitjanaHistorica & { soci?: Soci })[] = [];
	let carregant = true;
	let error = '';
	let filtreAny = '';
	let filtreModalitat = '';
	let cercaNom = '';
	let paginaActual = 1;
	let itemsPerPagina = 50;

	// Estadístiques
	let totalMitjanes = 0;
	let mitjanesMitjanes = 0;
	let socisAmbMitjanes = 0;
	let anysDisponibles: number[] = [];
	let modalitatsDisponibles: string[] = [];

	onMount(async () => {
		await carregarDades();
		await carregarEstadistiques();
	});

	async function carregarDades() {
		carregant = true;
		
		let query = supabase
			.from('mitjanes_historiques')
			.select(`
				*,
				socis:soci_id (*)
			`)
			.order('year', { ascending: false })
			.order('mitjana', { ascending: false });

		// Aplicar filtres
		if (filtreAny) {
			query = query.eq('year', parseInt(filtreAny));
		}
		if (filtreModalitat) {
			query = query.eq('modalitat', filtreModalitat);
		}

		const { data, error: queryError } = await query;

		if (queryError) {
			error = `Error carregant mitjanes: ${queryError.message}`;
		} else if (data) {
			let mitjanesFiltrades = data.map(m => ({
				...m,
				soci: Array.isArray(m.socis) ? m.socis[0] : m.socis
			}));

			// Filtrar per nom si cal
			if (cercaNom) {
				mitjanesFiltrades = mitjanesFiltrades.filter(m => 
					m.soci && (
						m.soci.nom?.toLowerCase().includes(cercaNom.toLowerCase()) ||
						m.soci.cognoms?.toLowerCase().includes(cercaNom.toLowerCase()) ||
						m.soci.numero_soci?.toString().includes(cercaNom)
					)
				);
			}

			mitjanes = mitjanesFiltrades;
		}

		carregant = false;
	}

	async function carregarEstadistiques() {
		// Estadístiques generals
		const { count: total } = await supabase
			.from('mitjanes_historiques')
			.select('*', { count: 'exact', head: true });
		
		totalMitjanes = total || 0;

		// Mitjana de mitjanes
		const { data: avgData } = await supabase
			.from('mitjanes_historiques')
			.select('mitjana');
		
		if (avgData) {
			const sum = avgData.reduce((acc, m) => acc + (m.mitjana || 0), 0);
			mitjanesMitjanes = sum / avgData.length;
		}

		// Socis amb mitjanes
		const { data: socisData } = await supabase
			.from('mitjanes_historiques')
			.select('soci_id')
			.not('soci_id', 'is', null);
		
		if (socisData) {
			const socisUnics = new Set(socisData.map(s => s.soci_id));
			socisAmbMitjanes = socisUnics.size;
		}

		// Anys i modalitats disponibles
		const { data: metaData } = await supabase
			.from('mitjanes_historiques')
			.select('year, modalitat');
		
		if (metaData) {
			anysDisponibles = [...new Set(metaData.map(m => m.year))].sort((a, b) => b - a);
			modalitatsDisponibles = [...new Set(metaData.map(m => m.modalitat).filter(Boolean))].sort();
		}
	}

	$: mitjanesPaginades = mitjanes.slice(
		(paginaActual - 1) * itemsPerPagina,
		paginaActual * itemsPerPagina
	);

	$: totalPagines = Math.ceil(mitjanes.length / itemsPerPagina);

	function canviarPagina(novaPagina: number) {
		paginaActual = novaPagina;
	}

	function exportarCSV() {
		const headers = ['Any', 'Modalitat', 'Numero Soci', 'Nom', 'Cognoms', 'Mitjana'];
		const csvData = mitjanes.map(m => [
			m.year,
			m.modalitat || '',
			m.soci?.numero_soci || '',
			m.soci?.nom || '',
			m.soci?.cognoms || '',
			m.mitjana || ''
		]);
		
		const csvContent = [headers, ...csvData]
			.map(row => row.map(cell => `"${cell}"`).join(','))
			.join('\n');
		
		const blob = new Blob([csvContent], { type: 'text/csv' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `mitjanes_historiques_${new Date().toISOString().split('T')[0]}.csv`;
		a.click();
		URL.revokeObjectURL(url);
	}

	// Recarregar quan canvien els filtres
	$: {
		if (filtreAny !== undefined || filtreModalitat !== undefined || cercaNom !== undefined) {
			paginaActual = 1;
			carregarDades();
		}
	}
</script>

<div class="min-h-screen bg-gray-50">
	<div class="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
		<!-- Header amb navegació -->
		<div class="flex justify-between items-center mb-8">
			<div>
				<button
					class="flex items-center text-blue-600 hover:text-blue-800 mb-4"
					on:click={() => goto('/admin')}
				>
					<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
					</svg>
					Tornar a Administració
				</button>
				<h1 class="text-3xl font-bold text-gray-900">Mitjanes Històriques</h1>
				<p class="text-gray-600">Gestió i visualització de mitjanes històriques dels jugadors</p>
			</div>
			<button
				class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg flex items-center"
				on:click={exportarCSV}
			>
				<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
				</svg>
				Exportar CSV
			</button>
		</div>

		<!-- Estadístiques -->
		<div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
			<div class="bg-white rounded-lg shadow p-6">
				<div class="flex items-center">
					<div class="text-3xl font-bold text-blue-600">{totalMitjanes.toLocaleString()}</div>
					<div class="ml-2 text-sm text-gray-500">registres</div>
				</div>
				<div class="text-gray-600 mt-1">Total Mitjanes</div>
			</div>
			<div class="bg-white rounded-lg shadow p-6">
				<div class="flex items-center">
					<div class="text-3xl font-bold text-green-600">{mitjanesMitjanes.toFixed(3)}</div>
				</div>
				<div class="text-gray-600 mt-1">Mitjana General</div>
			</div>
			<div class="bg-white rounded-lg shadow p-6">
				<div class="flex items-center">
					<div class="text-3xl font-bold text-purple-600">{socisAmbMitjanes}</div>
					<div class="ml-2 text-sm text-gray-500">jugadors</div>
				</div>
				<div class="text-gray-600 mt-1">Socis amb Mitjanes</div>
			</div>
			<div class="bg-white rounded-lg shadow p-6">
				<div class="flex items-center">
					<div class="text-3xl font-bold text-orange-600">{anysDisponibles.length}</div>
					<div class="ml-2 text-sm text-gray-500">anys</div>
				</div>
				<div class="text-gray-600 mt-1">Període Cobert</div>
			</div>
		</div>

		<!-- Filtres -->
		<div class="bg-white rounded-lg shadow p-6 mb-8">
			<h3 class="text-lg font-semibold mb-4">Filtres</h3>
			<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
				<div>
					<label for="filtre-any" class="block text-sm font-medium text-gray-700 mb-2">Any</label>
					<select 
						id="filtre-any"
						bind:value={filtreAny}
						class="w-full border border-gray-300 rounded-md px-3 py-2 focus:ring-blue-500 focus:border-blue-500"
					>
						<option value="">Tots els anys</option>
						{#each anysDisponibles as any}
							<option value={any}>{any}</option>
						{/each}
					</select>
				</div>
				<div>
					<label for="filtre-modalitat" class="block text-sm font-medium text-gray-700 mb-2">Modalitat</label>
					<select 
						id="filtre-modalitat"
						bind:value={filtreModalitat}
						class="w-full border border-gray-300 rounded-md px-3 py-2 focus:ring-blue-500 focus:border-blue-500"
					>
						<option value="">Totes les modalitats</option>
						{#each modalitatsDisponibles as modalitat}
							<option value={modalitat}>{modalitat}</option>
						{/each}
					</select>
				</div>
				<div>
					<label for="cerca-nom" class="block text-sm font-medium text-gray-700 mb-2">Cerca per nom o número</label>
					<input 
						id="cerca-nom"
						type="text"
						bind:value={cercaNom}
						placeholder="Nom, cognoms o número soci..."
						class="w-full border border-gray-300 rounded-md px-3 py-2 focus:ring-blue-500 focus:border-blue-500"
					>
				</div>
			</div>
		</div>

		{#if error}
			<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
				{error}
			</div>
		{/if}

		<!-- Taula de mitjanes -->
		<div class="bg-white rounded-lg shadow overflow-hidden">
			<div class="px-6 py-4 border-b border-gray-200">
				<h3 class="text-lg font-semibold">
					Registres ({mitjanes.length.toLocaleString()})
				</h3>
			</div>

			{#if carregant}
				<div class="p-8 text-center">
					<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
					<p class="mt-4 text-gray-600">Carregant mitjanes...</p>
				</div>
			{:else}
				<div class="overflow-x-auto">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Any</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Modalitat</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Jugador</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Número Soci</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Mitjana</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each mitjanesPaginades as mitjana}
								<tr class="hover:bg-gray-50">
									<td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
										{mitjana.year}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
										{mitjana.modalitat || '-'}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
										{#if mitjana.soci}
											<div>
												<div class="font-medium">{mitjana.soci.nom} {mitjana.soci.cognoms}</div>
												{#if mitjana.soci.email}
													<div class="text-xs text-gray-500">{mitjana.soci.email}</div>
												{/if}
											</div>
										{:else}
											<span class="text-gray-400 italic">Sense assignar</span>
										{/if}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
										{mitjana.soci?.numero_soci || '-'}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm">
										<span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
											{mitjana.mitjana?.toFixed(3) || 'N/A'}
										</span>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>

				<!-- Paginació -->
				{#if totalPagines > 1}
					<div class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
						<div class="flex-1 flex justify-between sm:hidden">
							<button
								disabled={paginaActual === 1}
								class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
								on:click={() => canviarPagina(paginaActual - 1)}
							>
								Anterior
							</button>
							<button
								disabled={paginaActual === totalPagines}
								class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
								on:click={() => canviarPagina(paginaActual + 1)}
							>
								Següent
							</button>
						</div>
						<div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
							<div>
								<p class="text-sm text-gray-700">
									Mostrant
									<span class="font-medium">{(paginaActual - 1) * itemsPerPagina + 1}</span>
									a
									<span class="font-medium">{Math.min(paginaActual * itemsPerPagina, mitjanes.length)}</span>
									de
									<span class="font-medium">{mitjanes.length}</span>
									resultats
								</p>
							</div>
							<div>
								<nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
									{#each Array.from({ length: Math.min(totalPagines, 10) }, (_, i) => i + 1) as pagina}
										<button
											class="relative inline-flex items-center px-4 py-2 border text-sm font-medium
												{pagina === paginaActual 
													? 'z-10 bg-blue-50 border-blue-500 text-blue-600' 
													: 'bg-white border-gray-300 text-gray-500 hover:bg-gray-50'
												}"
											on:click={() => canviarPagina(pagina)}
										>
											{pagina}
										</button>
									{/each}
									{#if totalPagines > 10}
										<span class="relative inline-flex items-center px-4 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-700">
											...
										</span>
									{/if}
								</nav>
							</div>
						</div>
					</div>
				{/if}
			{/if}
		</div>
	</div>
</div>