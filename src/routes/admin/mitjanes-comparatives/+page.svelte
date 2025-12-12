<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { goto } from '$app/navigation';
	import { adminStore } from '$lib/stores/auth';

	type JugadorMitjanes = {
		soci_id: number;
		nom: string;
		cognoms: string;
		numero_soci: number;
		mitjana_any_1: number | null;  // Temporada fa dos anys
		mitjana_any_2: number | null;  // Temporada anterior
		millor_mitjana: number | null;
	};

	let jugadors: JugadorMitjanes[] = [];
	let carregant = true;
	let error = '';
	let filtreModalitat = '3 BANDES';
	let cercaNom = '';
	let paginaActual = 1;
	let itemsPerPagina = 50;

	// Anys dinàmics
	let anyActual = new Date().getFullYear();
	let anyAnterior1 = anyActual - 2;  // Fa dos anys (23/24)
	let anyAnterior2 = anyActual - 1;  // Any anterior (24/25)

	// Estadístiques
	let totalJugadors = 0;
	let modalitatsDisponibles: string[] = [];

	onMount(async () => {
		// Assegurar-se que només els admins poden accedir
		if (!$adminStore) {
			goto('/');
			return;
		}
		await carregarModalitats();
		await carregarDades();
	});

	async function carregarModalitats() {
		const { data: metaData } = await supabase
			.from('mitjanes_historiques')
			.select('modalitat');

		if (metaData) {
			modalitatsDisponibles = [...new Set(metaData.map(m => m.modalitat).filter(Boolean))].sort();
		}
	}

	async function carregarDades() {
		carregant = true;
		error = '';

		try {
			// Obtenir jugadors que tenen mitjanes en almenys una de les dues temporades per la modalitat seleccionada
			const { data: mitjanes, error: queryError } = await supabase
				.from('mitjanes_historiques')
				.select(`
					soci_id,
					year,
					modalitat,
					mitjana,
					socis:soci_id (
						id,
						nom,
						cognoms,
						numero_soci
					)
				`)
				.eq('modalitat', filtreModalitat)
				.in('year', [anyAnterior1, anyAnterior2])
				.order('soci_id');

			if (queryError) {
				error = `Error carregant mitjanes: ${queryError.message}`;
				carregant = false;
				return;
			}

			// Agrupar per jugador
			const jugadorsMap = new Map<number, JugadorMitjanes>();

			mitjanes?.forEach((m: any) => {
				const soci = Array.isArray(m.socis) ? m.socis[0] : m.socis;
				if (!soci) return;

				const sociId = m.soci_id;
				if (!jugadorsMap.has(sociId)) {
					jugadorsMap.set(sociId, {
						soci_id: sociId,
						nom: soci.nom,
						cognoms: soci.cognoms,
						numero_soci: soci.numero_soci,
						mitjana_any_1: null,
						mitjana_any_2: null,
						millor_mitjana: null
					});
				}

				const jugador = jugadorsMap.get(sociId)!;

				if (m.year === anyAnterior1) {
					jugador.mitjana_any_1 = m.mitjana;
				} else if (m.year === anyAnterior2) {
					jugador.mitjana_any_2 = m.mitjana;
				}
			});

			// Calcular millor mitjana i convertir a array
			jugadors = Array.from(jugadorsMap.values()).map(j => {
				const mitjanes = [j.mitjana_any_1, j.mitjana_any_2].filter(m => m !== null) as number[];
				j.millor_mitjana = mitjanes.length > 0 ? Math.max(...mitjanes) : null;
				return j;
			});

			// Filtrar per nom si cal
			if (cercaNom) {
				jugadors = jugadors.filter(j =>
					j.nom?.toLowerCase().includes(cercaNom.toLowerCase()) ||
					j.cognoms?.toLowerCase().includes(cercaNom.toLowerCase()) ||
					j.numero_soci?.toString().includes(cercaNom)
				);
			}

			// Ordenar per millor mitjana (descendant)
			jugadors.sort((a, b) => {
				if (a.millor_mitjana === null && b.millor_mitjana === null) return 0;
				if (a.millor_mitjana === null) return 1;
				if (b.millor_mitjana === null) return -1;
				return b.millor_mitjana - a.millor_mitjana;
			});

			totalJugadors = jugadors.length;

		} catch (e: any) {
			error = `Error: ${e.message}`;
		} finally {
			carregant = false;
		}
	}

	$: jugadorsPaginats = jugadors.slice(
		(paginaActual - 1) * itemsPerPagina,
		paginaActual * itemsPerPagina
	);

	$: totalPagines = Math.ceil(jugadors.length / itemsPerPagina);

	function canviarPagina(novaPagina: number) {
		paginaActual = novaPagina;
	}

	function exportarCSV() {
		const headers = ['Número Soci', 'Nom', 'Cognoms', `Mitjana ${anyAnterior1}`, `Mitjana ${anyAnterior2}`, 'Millor Mitjana'];
		const csvData = jugadors.map(j => [
			j.numero_soci || '',
			j.nom || '',
			j.cognoms || '',
			j.mitjana_any_1?.toFixed(3) || '',
			j.mitjana_any_2?.toFixed(3) || '',
			j.millor_mitjana?.toFixed(3) || ''
		]);

		const csvContent = [headers, ...csvData]
			.map(row => row.map(cell => `"${cell}"`).join(','))
			.join('\n');

		const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `mitjanes_comparatives_${filtreModalitat}_${new Date().toISOString().split('T')[0]}.csv`;
		a.click();
		URL.revokeObjectURL(url);
	}

	// Recarregar quan canvien els filtres
	$: {
		if (filtreModalitat !== undefined || cercaNom !== undefined) {
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
				<h1 class="text-3xl font-bold text-gray-900">Mitjanes Comparatives</h1>
				<p class="text-gray-600">Comparació de mitjanes de les dues temporades anteriors ({anyAnterior1} i {anyAnterior2})</p>
			</div>
			<button
				class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg flex items-center"
				on:click={exportarCSV}
				disabled={jugadors.length === 0}
			>
				<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
				</svg>
				Exportar CSV
			</button>
		</div>

		<!-- Estadístiques -->
		<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
			<div class="bg-white rounded-lg shadow p-6">
				<div class="flex items-center">
					<div class="text-3xl font-bold text-blue-600">{totalJugadors}</div>
					<div class="ml-2 text-sm text-gray-500">jugadors</div>
				</div>
				<div class="text-gray-600 mt-1">Total Jugadors</div>
			</div>
			<div class="bg-white rounded-lg shadow p-6">
				<div class="flex items-center">
					<div class="text-3xl font-bold text-green-600">{anyAnterior1}</div>
					<div class="ml-2 text-sm text-gray-500">/ {anyAnterior2}</div>
				</div>
				<div class="text-gray-600 mt-1">Temporades Comparades</div>
			</div>
			<div class="bg-white rounded-lg shadow p-6">
				<div class="flex items-center">
					<div class="text-2xl font-bold text-purple-600">{filtreModalitat}</div>
				</div>
				<div class="text-gray-600 mt-1">Modalitat Seleccionada</div>
			</div>
		</div>

		<!-- Filtres -->
		<div class="bg-white rounded-lg shadow p-6 mb-8">
			<h3 class="text-lg font-semibold mb-4">Filtres</h3>
			<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
				<div>
					<label for="filtre-modalitat" class="block text-sm font-medium text-gray-700 mb-2">Modalitat</label>
					<select
						id="filtre-modalitat"
						bind:value={filtreModalitat}
						class="w-full border border-gray-300 rounded-md px-3 py-2 focus:ring-blue-500 focus:border-blue-500"
					>
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

		<!-- Taula de jugadors -->
		<div class="bg-white rounded-lg shadow overflow-hidden">
			<div class="px-6 py-4 border-b border-gray-200">
				<h3 class="text-lg font-semibold">
					Jugadors ({jugadors.length})
				</h3>
			</div>

			{#if carregant}
				<div class="p-8 text-center">
					<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
					<p class="mt-4 text-gray-600">Carregant dades...</p>
				</div>
			{:else if jugadors.length === 0}
				<div class="p-8 text-center text-gray-500">
					No s'han trobat jugadors amb mitjanes per aquesta modalitat en les temporades {anyAnterior1} i {anyAnterior2}.
				</div>
			{:else}
				<div class="overflow-x-auto">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Número</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Jugador</th>
								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Mitjana {anyAnterior1}
								</th>
								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Mitjana {anyAnterior2}
								</th>
								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Millor Mitjana
								</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each jugadorsPaginats as jugador}
								<tr class="hover:bg-gray-50">
									<td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
										{jugador.numero_soci}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
										<div class="font-medium">{jugador.nom} {jugador.cognoms}</div>
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-center">
										{#if jugador.mitjana_any_1 !== null}
											<span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
												{jugador.mitjana_any_1.toFixed(3)}
											</span>
										{:else}
											<span class="text-gray-400">-</span>
										{/if}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-center">
										{#if jugador.mitjana_any_2 !== null}
											<span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
												{jugador.mitjana_any_2.toFixed(3)}
											</span>
										{:else}
											<span class="text-gray-400">-</span>
										{/if}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-center">
										{#if jugador.millor_mitjana !== null}
											<span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-purple-100 text-purple-800">
												{jugador.millor_mitjana.toFixed(3)}
											</span>
										{:else}
											<span class="text-gray-400">-</span>
										{/if}
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
									<span class="font-medium">{Math.min(paginaActual * itemsPerPagina, jugadors.length)}</span>
									de
									<span class="font-medium">{jugadors.length}</span>
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
