<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { formatarNomJugador } from '$lib/utils/playerUtils';

	type JugadorMitjanes = {
		soci_id: number;
		nom: string;
		cognoms: string;
		mitjana_any_1: number | null; // any més antic dels dos
		mitjana_any_2: number | null; // any més recent dels dos
		millor_mitjana: number | null;
	};

	let jugadors: JugadorMitjanes[] = [];
	let carregant = true;
	let error = '';
	let filtreModalitat = '';
	let cercaNom = '';
	let paginaActual = 1;
	let itemsPerPagina = 50;

	// Els dos darrers anys disponibles al DB per la modalitat seleccionada
	let anyAnterior1: number | null = null;
	let anyAnterior2: number | null = null;

	// Estadístiques i metadades
	let totalJugadors = 0;
	let modalitatsDisponibles: string[] = [];

	function nomComplet(nom: string | null | undefined, cognoms: string | null | undefined): string {
		const raw = `${nom ?? ''} ${cognoms ?? ''}`.trim();
		return raw ? formatarNomJugador(raw) : '';
	}

	/** Format de temporada: el camp `year` és l'any final (ex: 2026 → "2025/2026"). */
	function formatSeason(year: number | null | undefined): string {
		if (year == null) return '—';
		return `${year - 1}/${year}`;
	}

	onMount(async () => {
		await carregarModalitats();
		if (modalitatsDisponibles.length > 0 && !filtreModalitat) {
			filtreModalitat = modalitatsDisponibles[0];
		}
		await carregarDades();
	});

	async function carregarModalitats() {
		const { data: metaData } = await supabase
			.from('mitjanes_historiques')
			.select('modalitat');

		if (metaData) {
			modalitatsDisponibles = [...new Set(metaData.map((m) => m.modalitat).filter(Boolean))].sort();
		}
	}

	/** Cerca els dos darrers anys disponibles al DB per a la modalitat. */
	async function detectarAnys(modalitat: string): Promise<[number | null, number | null]> {
		const { data, error: yErr } = await supabase
			.from('mitjanes_historiques')
			.select('year')
			.eq('modalitat', modalitat)
			.order('year', { ascending: false })
			.limit(20000);

		if (yErr || !data) return [null, null];

		const anys = [...new Set(data.map((r) => r.year as number))]
			.filter((y) => typeof y === 'number')
			.sort((a, b) => b - a);

		const recent = anys[0] ?? null;
		const previ = anys[1] ?? null;
		return [previ, recent]; // ordre cronològic (any_1 = més antic, any_2 = més recent)
	}

	async function carregarDades() {
		carregant = true;
		error = '';
		jugadors = [];

		try {
			if (!filtreModalitat) {
				carregant = false;
				return;
			}

			// 1) Detectem dinàmicament els dos darrers anys disponibles per la modalitat
			[anyAnterior1, anyAnterior2] = await detectarAnys(filtreModalitat);

			if (anyAnterior1 == null && anyAnterior2 == null) {
				carregant = false;
				return;
			}

			const yearsToQuery = [anyAnterior1, anyAnterior2].filter((y): y is number => y != null);

			// 2) Carrega mitjanes per la modalitat i els anys (sense join: PostgREST relationship
			//    no està definida amb FK; fem el join al client com fa /mitjanes-historiques).
			const { data: mitjanes, error: queryError } = await supabase
				.from('mitjanes_historiques')
				.select('soci_id, year, modalitat, mitjana')
				.eq('modalitat', filtreModalitat)
				.in('year', yearsToQuery);

			if (queryError) {
				error = `Error carregant mitjanes: ${queryError.message}`;
				carregant = false;
				return;
			}

			// 3) Carrega tots els socis en una crida i fem el lookup local per numero_soci
			const { data: socisList, error: socisError } = await supabase
				.from('socis')
				.select('numero_soci, nom, cognoms');

			if (socisError) {
				error = `Error carregant socis: ${socisError.message}`;
				carregant = false;
				return;
			}

			const socisMap = new Map<number, { nom: string; cognoms: string }>();
			(socisList || []).forEach((s) => {
				socisMap.set(s.numero_soci, { nom: s.nom, cognoms: s.cognoms });
			});

			// 4) Agrupa per jugador
			const jugadorsMap = new Map<number, JugadorMitjanes>();

			(mitjanes || []).forEach((m: any) => {
				const sociId: number | null = m.soci_id;
				if (sociId == null) return;
				const soci = socisMap.get(sociId);
				// Si el soci_id no té correspondència a la taula `socis`, l'ometem
				if (!soci) return;

				if (!jugadorsMap.has(sociId)) {
					jugadorsMap.set(sociId, {
						soci_id: sociId,
						nom: soci.nom ?? '',
						cognoms: soci.cognoms ?? '',
						mitjana_any_1: null,
						mitjana_any_2: null,
						millor_mitjana: null
					});
				}

				const jugador = jugadorsMap.get(sociId)!;
				if (m.year === anyAnterior1) jugador.mitjana_any_1 = m.mitjana;
				else if (m.year === anyAnterior2) jugador.mitjana_any_2 = m.mitjana;
			});

			// 5) Calcular millor mitjana
			let llista = Array.from(jugadorsMap.values()).map((j) => {
				const ms = [j.mitjana_any_1, j.mitjana_any_2].filter((m) => m !== null) as number[];
				j.millor_mitjana = ms.length > 0 ? Math.max(...ms) : null;
				return j;
			});

			// 6) Filtrar per nom si cal
			if (cercaNom) {
				const q = cercaNom.toLowerCase();
				llista = llista.filter(
					(j) =>
						j.nom?.toLowerCase().includes(q) ||
						j.cognoms?.toLowerCase().includes(q)
				);
			}

			// 7) Ordenar per millor mitjana (desc)
			llista.sort((a, b) => {
				if (a.millor_mitjana === null && b.millor_mitjana === null) return 0;
				if (a.millor_mitjana === null) return 1;
				if (b.millor_mitjana === null) return -1;
				return b.millor_mitjana - a.millor_mitjana;
			});

			jugadors = llista;
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
		const headers = ['Nom', 'Cognoms', `Mitjana ${formatSeason(anyAnterior1)}`, `Mitjana ${formatSeason(anyAnterior2)}`, 'Millor Mitjana'];
		const csvData = jugadors.map((j) => [
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

	function handleFilterChange() {
		paginaActual = 1;
		carregarDades();
	}
</script>

<div class="mc-root">
	<div class="mc-inner">
		<!-- Mast-head -->
		<header class="mc-mast">
			<div class="editorial-eyebrow">Foment Martinenc · Secció billar</div>
			<div class="mc-mast-row">
				<div>
					<h1 class="mc-title">Comparativa de mitjanes</h1>
					{#if anyAnterior1 != null && anyAnterior2 != null}
						<p class="mc-sub">Comparació de les dues últimes temporades disponibles ({formatSeason(anyAnterior1)} i {formatSeason(anyAnterior2)}).</p>
					{/if}
				</div>
				<button
					class="mc-export-btn"
					on:click={exportarCSV}
					disabled={jugadors.length === 0}
				>
					Exportar CSV
				</button>
			</div>
		</header>


		<!-- Filtres -->
		<div class="bg-white rounded-lg shadow p-6 mb-8 space-y-4">
			<div>
				<span class="block text-sm font-medium text-gray-700 mb-2">Modalitat</span>
				<div class="flex flex-wrap gap-2">
					{#each modalitatsDisponibles as modalitat}
						<button
							type="button"
							on:click={() => { filtreModalitat = modalitat; handleFilterChange(); }}
							class="modality-pill"
							class:active={filtreModalitat === modalitat}
						>
							{modalitat}
						</button>
					{/each}
				</div>
			</div>
			<div>
				<label for="cerca-nom" class="block text-sm font-medium text-gray-700 mb-2">Cerca per nom</label>
				<input
					id="cerca-nom"
					type="text"
					bind:value={cercaNom}
					on:input={handleFilterChange}
					placeholder="Nom o cognoms…"
					class="w-full md:max-w-md border border-gray-300 rounded-md px-3 py-2 focus:ring-blue-500 focus:border-blue-500"
				/>
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
					No s'han trobat jugadors amb mitjanes per aquesta modalitat en les temporades {formatSeason(anyAnterior1)} i {formatSeason(anyAnterior2)}.
				</div>
			{:else}
				<div class="overflow-x-auto">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th class="px-3 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider w-12">#</th>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Jugador</th>
								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Mitjana {formatSeason(anyAnterior1)}
								</th>
								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Mitjana {formatSeason(anyAnterior2)}
								</th>
								<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
									Millor Mitjana
								</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each jugadorsPaginats as jugador, idx}
								<tr class="hover:bg-gray-50">
									<td class="px-3 py-4 whitespace-nowrap text-sm text-gray-500 text-right tabular-nums">
										{(paginaActual - 1) * itemsPerPagina + idx + 1}
									</td>
									<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
										<div class="font-medium">{nomComplet(jugador.nom, jugador.cognoms)}</div>
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

<style>
	.mc-root {
		background: var(--paper, #fbfaf6);
		min-height: 100vh;
	}
	.mc-inner {
		max-width: 1180px;
		margin: 0 auto;
		padding: 1.75rem 1.25rem 4rem;
		font-family: var(--font-sans, sans-serif);
		color: var(--ink, #1a1814);
	}
	.mc-mast {
		margin-bottom: 1.75rem;
		padding-bottom: 1.1rem;
		border-bottom: 2px solid var(--ink, #1a1814);
	}
	.mc-mast-row {
		margin-top: 0.4rem;
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		gap: 1rem;
		flex-wrap: wrap;
	}
	.mc-title {
		margin: 0 0 0.4rem;
		font-size: clamp(1.75rem, 2.4vw, 2.4rem);
		font-weight: 800;
		letter-spacing: -0.022em;
		line-height: 1.1;
		color: var(--ink, #1a1814);
	}
	.mc-sub {
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
	.mc-export-btn {
		background: var(--paper-elevated, #fff);
		color: var(--ink, #1a1814);
		border: 1px solid var(--ink, #1a1814);
		padding: 0.55rem 1rem;
		font-family: var(--font-sans, sans-serif);
		font-weight: 600;
		font-size: 0.875rem;
		cursor: pointer;
		min-height: 40px;
	}
	.mc-export-btn:hover:not(:disabled) {
		background: var(--ink, #1a1814);
		color: var(--paper, #fbfaf6);
	}
	.mc-export-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	.tabular-nums { font-variant-numeric: tabular-nums; }

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

	/* Overrides Tailwind dins .mc-root */
	.mc-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
	.mc-root :global(.bg-gray-50) { background: var(--paper, #fbfaf6) !important; }
	.mc-root :global(.shadow),
	.mc-root :global(.shadow-sm),
	.mc-root :global(.shadow-md) { box-shadow: none !important; }
	.mc-root :global(.rounded),
	.mc-root :global(.rounded-sm),
	.mc-root :global(.rounded-md),
	.mc-root :global(.rounded-lg),
	.mc-root :global(.rounded-full) { border-radius: 0 !important; }

	.mc-root :global(.bg-blue-100) {
		background: var(--paper, #fbfaf6) !important;
		border: 1px solid var(--blue, #1f4a99) !important;
	}
	.mc-root :global(.bg-green-100) {
		background: var(--paper, #fbfaf6) !important;
		border: 1px solid var(--green, #1f7a3a) !important;
	}
	.mc-root :global(.bg-purple-100) {
		background: var(--paper, #fbfaf6) !important;
		border: 1px solid var(--ink-2, #4a443e) !important;
	}
	.mc-root :global(.bg-red-100) {
		background: var(--paper, #fbfaf6) !important;
		border: 1px solid var(--accent, #a30b1e) !important;
	}
	.mc-root :global(.bg-blue-50) {
		background: var(--paper-elevated, #fff) !important;
		border-color: var(--ink, #1a1814) !important;
		color: var(--ink, #1a1814) !important;
	}
	.mc-root :global(.bg-green-600),
	.mc-root :global(.bg-green-700) {
		background: var(--ink, #1a1814) !important;
		color: var(--paper, #fbfaf6) !important;
	}

	.mc-root :global(.text-blue-600),
	.mc-root :global(.text-blue-700),
	.mc-root :global(.text-blue-800) { color: var(--blue, #1f4a99) !important; }
	.mc-root :global(.text-green-600),
	.mc-root :global(.text-green-700),
	.mc-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
	.mc-root :global(.text-purple-600),
	.mc-root :global(.text-purple-700),
	.mc-root :global(.text-purple-800) { color: var(--ink, #1a1814) !important; }
	.mc-root :global(.text-gray-400),
	.mc-root :global(.text-gray-500),
	.mc-root :global(.text-gray-600) { color: var(--ink-3, #807a72) !important; }
	.mc-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
	.mc-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }

	.mc-root :global(.border-gray-200),
	.mc-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
	.mc-root :global(.border-blue-500) { border-color: var(--ink, #1a1814) !important; }
	.mc-root :global(.border-red-400) { border-color: var(--accent, #a30b1e) !important; }

	.mc-root :global(input),
	.mc-root :global(select),
	.mc-root :global(textarea) {
		background: var(--paper-elevated, #fff) !important;
		border: 1px solid var(--rule-strong, #b8b3a8) !important;
		border-radius: 0 !important;
		font-family: var(--font-sans, sans-serif);
	}
	.mc-root :global(input:focus),
	.mc-root :global(select:focus) {
		outline: 2px solid var(--ink, #1a1814);
		outline-offset: -1px;
	}
	.mc-root :global(table) { font-family: var(--font-sans, sans-serif); }
	.mc-root :global(thead.bg-gray-50) {
		background: var(--paper, #fbfaf6) !important;
		border-bottom: 1px solid var(--ink, #1a1814) !important;
	}
</style>
