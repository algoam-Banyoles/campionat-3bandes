<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';

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

	type MitjanaHistorica = {
		id: string;
		soci_id: number | null;
		year: number;
		modalitat: string;
		mitjana: number | null;
		partides: number | null;
		creat_el: string;
	};

	let socis: Soci[] = [];
	let mitjanes: (MitjanaHistorica & { soci: Soci })[] = [];
	let socisSeleccionats: number[] = [];
	let carregant = false;
	let error = '';

	onMount(async () => {
		await carregarDades();
	});

	async function carregarDades() {
		carregant = true;
		
		// Carregar socis actius
		const { data: socisData } = await supabase
			.from('socis')
			.select('*')
			.eq('actiu', true);
		
		if (socisData) socis = socisData;

		// Carregar mitjanes més recents per soci
		const { data: mitjanaData } = await supabase
			.from('mitjanes_historiques')
			.select(`
				*,
				socis:soci_id (*)
			`)
			.not('soci_id', 'is', null)
			.order('year', { ascending: false });

		if (mitjanaData) {
			// Agafar només la mitjana més recent de cada soci
			const mitjanesPorSoci = new Map();
			mitjanaData.forEach(m => {
				if (!mitjanesPorSoci.has(m.soci_id)) {
					mitjanesPorSoci.set(m.soci_id, {
						...m,
						soci: Array.isArray(m.socis) ? m.socis[0] : m.socis
					});
				}
			});
			mitjanes = Array.from(mitjanesPorSoci.values())
				.sort((a, b) => (b.mitjana || 0) - (a.mitjana || 0));
		}

		carregant = false;
	}

	function toggleSoci(numeroSoci: number) {
		if (socisSeleccionats.includes(numeroSoci)) {
			socisSeleccionats = socisSeleccionats.filter(id => id !== numeroSoci);
		} else if (socisSeleccionats.length < 20) {
			socisSeleccionats = [...socisSeleccionats, numeroSoci];
		}
	}

	async function crearRanquing() {
		if (socisSeleccionats.length !== 20) {
			error = 'Has de seleccionar exactament 20 jugadors';
			return;
		}

		carregant = true;
		error = '';

		try {
			// Netejar rànquing actual
			await supabase.from('ranking').delete().neq('id', 0);

			// Crear noves posicions ordenades per mitjana
			const socisOrdenats = socisSeleccionats
				.map(numeroSoci => {
					const mitjana = mitjanes.find(m => m.soci_id === numeroSoci);
					return {
						numero_soci: numeroSoci,
						mitjana_referencia: mitjana?.mitjana || 0,
						soci: mitjana?.soci
					};
				})
				.sort((a, b) => (b.mitjana_referencia || 0) - (a.mitjana_referencia || 0));

			// Inserir al rànquing
			const ranquingData = socisOrdenats.map((soci, index) => ({
				posicio: index + 1,
				soci_id: soci.numero_soci,
				mitjana_referencia: soci.mitjana_referencia,
				data_entrada: new Date().toISOString().split('T')[0]
			}));

			const { error: insertError } = await supabase
				.from('ranking')
				.insert(ranquingData);

			if (insertError) throw insertError;

			alert('Rànquing inicial creat correctament!');
			socisSeleccionats = [];
			
		} catch (err) {
			error = `Error creant el rànquing: ${err}`;
		}

		carregant = false;
	}

	$: socisDisponibles = mitjanes.filter(m => 
		!socisSeleccionats.includes(m.soci_id!) && m.soci
	);
	
	$: socisSeleccionatsData = socisSeleccionats
		.map(id => mitjanes.find(m => m.soci_id === id))
		.filter(Boolean)
		.sort((a, b) => (b!.mitjana || 0) - (a!.mitjana || 0));
</script>

<div class="max-w-6xl mx-auto p-6">
	<h1 class="text-3xl font-bold mb-6">Crear Rànquing Inicial</h1>

	{#if error}
		<div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
			{error}
		</div>
	{/if}

	<div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
		<!-- Llista de jugadors disponibles -->
		<div>
			<h2 class="text-xl font-semibold mb-4">
				Jugadors Disponibles (ordenats per mitjana)
			</h2>
			
			<div class="bg-white rounded-lg shadow max-h-96 overflow-y-auto">
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
									{mitjana.year} - {mitjana.modalitat}
								</div>
							</div>
						</div>
					</button>
				{/each}
			</div>
		</div>

		<!-- Rànquing seleccionat -->
		<div>
			<h2 class="text-xl font-semibold mb-4">
				Rànquing Seleccionat ({socisSeleccionats.length}/20)
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
									Mitjana: {mitjana?.mitjana?.toFixed(3) || 'N/A'}
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
						Selecciona jugadors per formar el rànquing inicial
					</div>
				{/each}
			</div>

			{#if socisSeleccionats.length > 0}
				<div class="mt-4 p-4 bg-blue-50 rounded-lg">
					<p class="text-sm text-blue-800 mb-2">
						<strong>Nota:</strong> Els jugadors seran ordenats automàticament per mitjana, 
						amb la millor mitjana a la posició #1.
					</p>
				</div>
			{/if}
		</div>
	</div>

	<!-- Botó crear rànquing -->
	<div class="mt-8 flex justify-center">
		<button
			class="bg-green-600 hover:bg-green-700 text-white font-bold py-3 px-8 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed"
			disabled={socisSeleccionats.length !== 20 || carregant}
			on:click={crearRanquing}
		>
			{#if carregant}
				Creant...
			{:else}
				Crear Rànquing Inicial (20 jugadors)
			{/if}
		</button>
	</div>

	{#if socisSeleccionats.length < 20}
		<p class="text-center mt-4 text-gray-600">
			Necessites seleccionar {20 - socisSeleccionats.length} jugadors més
		</p>
	{/if}
</div>