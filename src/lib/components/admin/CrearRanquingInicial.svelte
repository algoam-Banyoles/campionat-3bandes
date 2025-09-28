<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { withRetry, handleError } from '$lib/errors/handler';
	import { ERROR_CODES } from '$lib/errors/types';
	import { toastStore } from '$lib/stores/toastStore';
	import { logAction, logSuccess } from '$lib/errors/sentry';
	import ToastContainer from '$lib/components/general/ToastContainer.svelte';

	type Soci = {
		id?: string;
		numero_soci: number;
		nom: string;
		cognoms: string;
		email: string | null;
		telefon?: string | null;
		de_baixa?: boolean | null;
		creat_el?: string;
		actualitzat_el?: string;
	};

	type MitjanaHistorica = {
		id: string;
		soci_id: number | null;
		year: number | null;
		modalitat: string;
		mitjana: number | null;
		partides: number | null;
		creat_el: string | null;
	};

	let socis: Soci[] = [];
	let mitjanes: (MitjanaHistorica & { soci: Soci })[] = [];
	let socisSeleccionats: number[] = [];
	let carregant = false;
	let filtreText = '';
	
	// Any actual i anterior per mostrar en la UI
	const anyActual = new Date().getFullYear();
	const anyAnterior = anyActual - 1;

	onMount(async () => {
		await carregarDades();
	});

	async function carregarDades() {
		carregant = true;
		logAction('carregar_dades_ranquing_inicial');
		
		try {
			await withRetry(async () => {
				// 1. Carregar tots els socis actius
				const { data: socisActius, error: socisError } = await supabase
					.from('socis')
					.select('numero_soci, nom, cognoms, email, de_baixa, creat_el')
					.or('de_baixa.is.null,de_baixa.eq.false');

				if (socisError) {
					throw handleError(socisError, ERROR_CODES.DATABASE_QUERY_ERROR, {
						component: 'CrearRanquingInicial',
						action: 'carregar_socis_actius'
					});
				}

				// 2. Carregar mitjanes de 3 BANDES dels darrers 2 anys
				const anyActual = new Date().getFullYear();
				const anyAnterior = anyActual - 1;

				const { data: mitjanaData, error: mitjanaError } = await supabase
					.from('mitjanes_historiques')
					.select('*')
					.eq('modalitat', '3 BANDES')
					.not('soci_id', 'is', null)
					.in('year', [anyActual, anyAnterior]) // Només any actual i anterior
					.order('soci_id', { ascending: true }); // Ordenar per soci per facilitar agrupació

				if (mitjanaError) {
					throw handleError(mitjanaError, ERROR_CODES.DATABASE_QUERY_ERROR, {
						component: 'CrearRanquingInicial',
						action: 'carregar_mitjanes_historiques'
					});
				}

				// 3. Processar dades
				if (socisActius && mitjanaData) {
				// Crear mapa de mitjanes per soci (millor dels darrers 2 anys)
				const mitjanesPorSoci = new Map();
				
				// Agrupar per soci i trobar la millor mitjana dels darrers 2 anys
				const socisAmbMitjanes = new Map();
				mitjanaData.forEach((m: any) => {
					if (m.mitjana && m.mitjana > 0) {
						if (!socisAmbMitjanes.has(m.soci_id)) {
							socisAmbMitjanes.set(m.soci_id, []);
						}
						socisAmbMitjanes.get(m.soci_id).push(m);
					}
				});

				// Per cada soci, trobar la millor mitjana
				socisAmbMitjanes.forEach((mitjanes, sociId) => {
					const millorMitjana = mitjanes.reduce((millor: MitjanaHistorica, actual: MitjanaHistorica) => {
						return (actual.mitjana || 0) > (millor.mitjana || 0) ? actual : millor;
					});
					mitjanesPorSoci.set(sociId, millorMitjana);
				});

				// Crear llista combinada: socis amb mitjana + socis sense mitjana
				const socisAmbMitjana: (MitjanaHistorica & { soci: Soci })[] = [];
				const socisSenseMitjana: (MitjanaHistorica & { soci: Soci })[] = [];

				socisActius.forEach((soci: any) => {
					const mitjana = mitjanesPorSoci.get(soci.numero_soci);
					
					if (mitjana) {
						// Soci amb mitjana
						socisAmbMitjana.push({
							...mitjana,
							soci: soci,
							soci_id: soci.numero_soci
						});
					} else {
						// Soci sense mitjana
						socisSenseMitjana.push({
							id: `no-mitjana-${soci.numero_soci}`,
							soci_id: soci.numero_soci,
							year: null,
							modalitat: '3 BANDES',
							mitjana: null,
							partides: null,
							creat_el: null,
							soci: soci
						});
					}
				});

				// Ordenar: primers els amb mitjana (millor a pitjor), després els sense mitjana (alfabètic)
				socisAmbMitjana.sort((a, b) => (b.mitjana || 0) - (a.mitjana || 0));
					socisSenseMitjana.sort((a, b) => {
						const parsedA = a.soci.creat_el ? Date.parse(a.soci.creat_el) : Number.NaN;
						const parsedB = b.soci.creat_el ? Date.parse(b.soci.creat_el) : Number.NaN;
						const timeA = Number.isFinite(parsedA) ? parsedA : Number.MAX_SAFE_INTEGER;
						const timeB = Number.isFinite(parsedB) ? parsedB : Number.MAX_SAFE_INTEGER;
						if (timeA !== timeB) {
							return timeA - timeB;
						}
						return a.soci.numero_soci - b.soci.numero_soci;
					});

					// Combinar les dues llistes
					mitjanes = [...socisAmbMitjana, ...socisSenseMitjana];
					logSuccess('dades_carregades', {
						socisTotal: socisActius.length,
						socisAmbMitjana: socisAmbMitjana.length,
						socisSenseMitjana: socisSenseMitjana.length
					});
				}
			}, {
				component: 'CrearRanquingInicial',
				action: 'carregar_dades_completes'
			});
		} catch (error) {
			const appError = handleError(error, ERROR_CODES.UNKNOWN_ERROR, {
				component: 'CrearRanquingInicial',
				action: 'carregar_dades'
			});
			toastStore.showAppError(appError);
		}

		carregant = false;
	}

	function toggleSoci(numeroSoci: number) {
		try {
			if (socisSeleccionats.includes(numeroSoci)) {
				socisSeleccionats = socisSeleccionats.filter(id => id !== numeroSoci);
				logAction('soci_desseleccionat', { numeroSoci });
			} else if (socisSeleccionats.length < 20) {
				socisSeleccionats = [...socisSeleccionats, numeroSoci];
				logAction('soci_seleccionat', { numeroSoci, totalSeleccionats: socisSeleccionats.length + 1 });
			} else {
				const error = handleError(
					new Error('Màxim de jugadors assolit'),
					ERROR_CODES.VALIDATION_INVALID_RANGE,
					{
						component: 'CrearRanquingInicial',
						action: 'seleccionar_soci',
						data: { numeroSoci, actualSeleccionats: socisSeleccionats.length }
					}
				);
				toastStore.showWarning('Màxim 20 jugadors per al rànquing inicial. Els altres aniran a llista d\'espera.');
			}
		} catch (error) {
			const appError = handleError(error, ERROR_CODES.UNKNOWN_ERROR, {
				component: 'CrearRanquingInicial',
				action: 'toggle_soci'
			});
			toastStore.showAppError(appError);
		}
	}

	async function crearRanquing() {
		// Validació - mínim 1 jugador
		if (socisSeleccionats.length === 0) {
			const error = handleError(
				new Error('Cal seleccionar almenys un jugador'),
				ERROR_CODES.VALIDATION_REQUIRED_FIELD,
				{
					component: 'CrearRanquingInicial',
					action: 'crear_ranquing',
					data: { seleccionats: socisSeleccionats.length }
				}
			);
			toastStore.showAppError(error);
			return;
		}

		carregant = true;
		logAction('crear_ranquing_inicial', { jugadorsSeleccionats: socisSeleccionats.length });

		try {
			await withRetry(async () => {
				// Crear array de socis ordenats segons la selecció i ordre actual
				const socisOrdenats = socisSeleccionatsData.map(mitjana => mitjana!.soci_id!);

				// Cridar la funció SQL per crear el rànquing inicial
				const { data: result, error: functionError } = await supabase.rpc(
					'create_initial_ranking_from_ordered_socis',
					{
						p_event_id: null, // Usar event actiu
						p_socis_ordered: socisOrdenats
					}
				);

				if (functionError) {
					throw handleError(functionError, ERROR_CODES.DATABASE_QUERY_ERROR, {
						component: 'CrearRanquingInicial',
						action: 'cridar_funcio_crear_ranquing'
					});
				}

				// Verificar el resultat de la funció
				if (!result.success) {
					throw handleError(
						new Error(result.error || 'Error desconegut creant el rànquing'),
						ERROR_CODES.DATABASE_QUERY_ERROR,
						{
							component: 'CrearRanquingInicial',
							action: 'verificar_resultat_funcio',
							data: result
						}
					);
				}

				logSuccess('ranquing_inicial_creat', {
					jugadors: result.inserted_count,
					totalRequestat: result.total_requested,
					eventId: result.event_id,
					errors: result.errors
				});

				if (result.errors && result.errors.length > 0) {
					toastStore.showWarning(`Rànquing creat amb ${result.errors.length} advertències: ${result.errors.join(', ')}`);
				} else {
					toastStore.showSuccess(`Rànquing inicial creat correctament amb ${result.inserted_count} jugadors!`);
				}
			}, {
				component: 'CrearRanquingInicial',
				action: 'crear_ranquing_complet'
			});
			
			socisSeleccionats = [];
			
		} catch (error) {
			const appError = handleError(error, ERROR_CODES.RANKING_UPDATE_ERROR, {
				component: 'CrearRanquingInicial',
				action: 'crear_ranquing',
				data: { socisSeleccionats: socisSeleccionats.length }
			});
			toastStore.showAppError(appError);
		}

		carregant = false;
	}

	$: socisDisponibles = mitjanes.filter(m => {
		if (!m.soci || socisSeleccionats.includes(m.soci_id!)) {
			return false;
		}
		
		// Aplicar filtre de text si hi ha
		if (filtreText.trim()) {
			const textCerca = filtreText.toLowerCase().trim();
			const nomComplet = `${m.soci.nom} ${m.soci.cognoms}`.toLowerCase();
			const numeroSoci = m.soci.numero_soci.toString();
			
			return nomComplet.includes(textCerca) || numeroSoci.includes(textCerca);
		}
		
		return true;
	});
	
	$: socisSeleccionatsData = socisSeleccionats
		.map(id => mitjanes.find(m => m.soci_id === id))
		.filter(Boolean)
		.sort((a, b) => (b!.mitjana || 0) - (a!.mitjana || 0));
</script>

<div class="max-w-6xl mx-auto p-6">
	<h1 class="text-3xl font-bold mb-6">Crear Rànquing Inicial</h1>
	<div class="bg-blue-50 border-l-4 border-blue-400 p-4 mb-6">
		<div class="flex">
			<div class="ml-3">
				<p class="text-sm text-blue-700">
					<strong>Nou:</strong> Pots crear el rànquing amb qualsevol nombre de jugadors (1-20). 
					Els futurs inscrits s'afegiran automàticament fins completar els 20 places.
				</p>
			</div>
		</div>
	</div>

	<div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
		<!-- Llista de jugadors disponibles -->
		<div>
			<h2 class="text-xl font-semibold mb-4">
				Socis Actius ({socisDisponibles.length} {filtreText.trim() ? 'filtrats' : 'disponibles'})
			</h2>
			<p class="text-sm text-gray-600 mb-4">
				Millor mitjana de 3 BANDES de {anyActual} i {anyAnterior} primer, després socis sense mitjana
			</p>
			
			<!-- Camp de cerca -->
			<div class="mb-4">
				<div class="relative">
					<input
						type="text"
						placeholder="Cerca per nom, cognoms o número de soci..."
						bind:value={filtreText}
						class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
					/>
					<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
						<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m21 21-6-6m2-5a7 7 0 1 1-14 0 7 7 0 0 1 14 0Z"/>
						</svg>
					</div>
					{#if filtreText.trim()}
						<button
							on:click={() => filtreText = ''}
							class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
							aria-label="Netejar cerca"
						>
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
							</svg>
						</button>
					{/if}
				</div>
				{#if filtreText.trim() && socisDisponibles.length === 0}
					<p class="text-sm text-gray-500 mt-2">
						No s'han trobat jugadors que coincideixin amb "{filtreText}"
					</p>
				{/if}
			</div>
			
			<div class="bg-white rounded-lg shadow max-h-96 overflow-y-auto">
				{#if carregant}
					<div class="p-8 text-center text-gray-500">
						<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto mb-4"></div>
						Carregant socis amb millors mitjanes de {anyActual} i {anyAnterior}...
					</div>
				{:else if socisDisponibles.length === 0}
					<div class="p-8 text-center text-gray-500">
						<div class="text-2xl mb-4">📊</div>
						<p class="font-medium mb-2">No s'han trobat socis actius</p>
						<p class="text-sm">
							Cal que hi hagi socis actius per crear el rànquing inicial
						</p>
					</div>
				{:else}
					{#each socisDisponibles as mitjana}
						<button
							class="w-full p-3 text-left border-b hover:bg-gray-50 disabled:opacity-50"
							disabled={socisSeleccionats.length >= 20}
							on:click={() => toggleSoci(mitjana.soci_id!)}
						>
							<div class="flex justify-between items-center">
								<div>
									<span class="font-medium">
										{mitjana.soci?.nom} {mitjana.soci?.cognoms}
									</span>
									<span class="text-sm text-gray-500 ml-2">
										(#{mitjana.soci?.numero_soci})
									</span>
								</div>
								<div class="text-right">
									<div class="font-semibold text-blue-600">
										{mitjana.mitjana?.toFixed(3) || 'N/A'}
									</div>
									<div class="text-xs text-gray-500">
										Millor mitjana: {mitjana.year}
									</div>
									<div class="text-xs text-green-600 font-medium">
										3 BANDES
									</div>
								</div>
							</div>
						</button>
					{/each}
				{/if}
			</div>
		</div>

		<!-- Rànquing seleccionat -->
		<div>
			<h2 class="text-xl font-semibold mb-4">
				Rànquing Inicial ({socisSeleccionats.length} de màx. 20)
			</h2>
			
			<div class="bg-white rounded-lg shadow">
				{#each socisSeleccionatsData as mitjana, index}
					<div class="p-3 border-b flex justify-between items-center">
						<div class="flex items-center">
							<span class="w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center text-sm font-bold mr-3">
								{index + 1}
							</span>
							<div>
								<span class="font-medium">
									{mitjana?.soci?.nom} {mitjana?.soci?.cognoms}
								</span>
								<div class="text-xs text-gray-500">
									Mitjana: {mitjana?.mitjana?.toFixed(3) || 'Sense mitjana'}
								</div>
							</div>
						</div>
						<button
							class="text-red-500 hover:text-red-700 p-1"
							on:click={() => toggleSoci(mitjana!.soci_id!)}
						>
							✕
						</button>
					</div>
				{:else}
					<div class="p-8 text-center text-gray-500">
						<div class="text-2xl mb-4">🎯</div>
						<p class="font-medium mb-2">Selecciona jugadors per formar el rànquing inicial</p>
						<p class="text-sm">
							Pots començar amb qualsevol nombre de jugadors. Els altres s'afegiran després.
						</p>
					</div>
				{/each}
			</div>

			{#if socisSeleccionats.length > 0}
				<div class="mt-4 p-4 bg-blue-50 rounded-lg">
					<p class="text-sm text-blue-800 mb-2">
						<strong>Criteris aplicats:</strong>
					</p>
					<ul class="text-xs text-blue-700 space-y-1">
						<li>✓ Tots els socis actius (no de baixa)</li>
						<li>✓ Amb mitjana de 3 BANDES van primer</li>
						<li>✓ Sense mitjana van últims (ordenats alfabèticament)</li>
						<li>✓ Millor mitjana entre {anyActual} i {anyAnterior} de cada soci</li>
						<li>✓ Es poden afegir més jugadors després fins arribar als 20</li>
					</ul>
				</div>
			{/if}
		</div>
	</div>

	<!-- Botó crear rànquing -->
	<div class="mt-8 flex justify-center">
		<button
			class="bg-green-600 hover:bg-green-700 text-white font-bold py-3 px-8 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed"
			disabled={socisSeleccionats.length === 0 || carregant}
			on:click={crearRanquing}
		>
			{#if carregant}
				Creant...
			{:else if socisSeleccionats.length === 0}
				Selecciona jugadors per començar
			{:else}
				Crear Rànquing Inicial ({socisSeleccionats.length} jugador{socisSeleccionats.length !== 1 ? 's' : ''})
			{/if}
		</button>
	</div>

	{#if socisSeleccionats.length === 0}
		<p class="text-center mt-4 text-gray-600">
			Selecciona jugadors per crear el rànquing inicial. Es poden afegir més jugadors després.
		</p>
	{:else if socisSeleccionats.length < 20}
		<p class="text-center mt-4 text-blue-600">
			Pots afegir {20 - socisSeleccionats.length} jugadors més al rànquing. Els futurs inscrits s'afegiran automàticament.
		</p>
	{:else}
		<p class="text-center mt-4 text-orange-600">
			Rànquing complet amb 20 jugadors. Els futurs inscrits aniran a la llista d'espera.
		</p>
	{/if}
</div>

<!-- Contenidor de toasts per mostrar errors i notificacions -->
<ToastContainer />
