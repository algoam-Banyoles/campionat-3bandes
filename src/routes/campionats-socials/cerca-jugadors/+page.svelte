<script lang="ts">
  import { searchActivePlayers, getPlayerAverageHistory, searchPlayerInClassifications } from '$lib/api/socialLeagues';
  import PlayerAverageEvolution from '$lib/components/campionats-socials/PlayerAverageEvolution.svelte';
  import { debounce } from 'lodash-es';

  type SearchActivePlayer = Awaited<ReturnType<typeof searchActivePlayers>>[number];
  type ClassificationEntry = {
    temporada: string;
    modalitat: string;
    categoria: string;
    posicio: number;
    punts: number;
    partides_jugades: number;
  };

  let searchTerm = '';
  let searchResults: SearchActivePlayer[] = [];
  let loading = false;
  let error: string | null = null;

  let selectedPlayer: SearchActivePlayer | null = null;
  let selectedModalitat: string = '';
  let playerHistory: any[] = [];
  let loadingHistory = false;

  let playerClassifications: ClassificationEntry[] = [];
  let loadingClassifications = false;

  const modalitats = [
    { value: '', label: 'Totes les modalitats' },
    { value: 'tres_bandes', label: '3 Bandes' },
    { value: 'lliure', label: 'Lliure' },
    { value: 'banda', label: 'Banda' }
  ];

  const debouncedSearch = debounce(async (term: string) => {
    if (term.length < 3) {
      searchResults = [];
      return;
    }

    loading = true;
    error = null;

    try {
      searchResults = await searchActivePlayers(term);
    } catch (e) {
      error = 'Error buscant socis';
      console.error(e);
    } finally {
      loading = false;
    }
  }, 300);

  $: debouncedSearch(searchTerm);

  async function selectPlayer(player: SearchActivePlayer) {
    selectedPlayer = player;
    await Promise.all([loadPlayerHistory(), loadPlayerClassifications()]);
  }

  async function loadPlayerHistory() {
    if (!selectedPlayer) return;

    loadingHistory = true;
    try {
      playerHistory = await getPlayerAverageHistory(
        selectedPlayer.numero_soci,
        selectedModalitat || undefined
      );
    } catch (e) {
      console.error('Error loading player history:', e);
      playerHistory = [];
    } finally {
      loadingHistory = false;
    }
  }

  async function loadPlayerClassifications() {
    if (!selectedPlayer) return;

    loadingClassifications = true;
    try {
      // Busquem per "nom cognoms" exacte i filtrem per numero_soci si cal.
      const fullName = `${selectedPlayer.nom} ${selectedPlayer.cognoms}`.trim();
      const matches = await searchPlayerInClassifications(fullName);
      // L'API agrupa per nom; agafem el primer que coincideix amb l'expected
      const found = matches.find(
        m => m.player.nom === selectedPlayer?.nom && m.player.cognom === selectedPlayer?.cognoms
      ) ?? matches[0];
      playerClassifications = found?.classifications ?? [];
    } catch (e) {
      console.error('Error loading player classifications:', e);
      playerClassifications = [];
    } finally {
      loadingClassifications = false;
    }
  }

  $: if (selectedPlayer && selectedModalitat !== undefined) {
    loadPlayerHistory();
  }

  function clearSearch() {
    searchTerm = '';
    searchResults = [];
    error = null;
  }

  function clearSelection() {
    selectedPlayer = null;
    playerHistory = [];
    playerClassifications = [];
    selectedModalitat = '';
  }

  // Filtrar classificacions per modalitat seleccionada
  $: filteredClassifications = selectedModalitat
    ? playerClassifications.filter(c => c.modalitat === modalitatLabel(selectedModalitat))
    : playerClassifications;

  function modalitatLabel(value: string): string {
    const map: Record<string, string> = {
      'tres_bandes': '3 BANDES',
      'lliure': 'LLIURE',
      'banda': 'BANDA'
    };
    return map[value] || value;
  }

  function getPositionMedal(pos: number): string {
    if (pos === 1) return '🥇';
    if (pos === 2) return '🥈';
    if (pos === 3) return '🥉';
    return '';
  }

  function getModalitatName(mod: string): string {
    const names: Record<string, string> = {
      'tres_bandes': '3 Bandes',
      'lliure': 'Lliure',
      'banda': 'Banda'
    };
    return names[mod] || mod;
  }
</script>

<svelte:head>
  <title>Cerca de Jugadors - Campionats Socials</title>
</svelte:head>

<div class="container mx-auto px-4 py-8 max-w-7xl">
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900">Cerca de Jugadors</h1>
    <p class="mt-2 text-gray-600">Consulta l'evolució històrica de mitjanes dels jugadors en els campionats socials</p>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <!-- Search Panel -->
    <div class="lg:col-span-1">
      <div class="bg-white border border-gray-200 rounded-lg sticky top-4">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">Cercar Jugador</h3>
        </div>

        <div class="p-6 space-y-4">
          <!-- Search input -->
          <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
            </div>
            <input
              type="text"
              bind:value={searchTerm}
              placeholder="Nom del jugador..."
              class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
            />
            {#if searchTerm}
              <button
                on:click={clearSearch}
                class="absolute inset-y-0 right-0 pr-3 flex items-center"
                aria-label="Netejar cerca"
              >
                <svg class="h-5 w-5 text-gray-400 hover:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            {/if}
          </div>

          <!-- Loading -->
          {#if loading}
            <div class="flex items-center justify-center py-4">
              <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
              <span class="ml-2 text-sm text-gray-600">Cercant...</span>
            </div>
          {/if}

          <!-- Error -->
          {#if error}
            <div class="bg-red-50 border border-red-200 rounded-md p-4">
              <p class="text-sm text-red-600">{error}</p>
            </div>
          {/if}

          <!-- Results -->
          {#if searchResults.length > 0}
            <div class="space-y-2 max-h-96 overflow-y-auto">
              {#each searchResults as player}
                <button
                  on:click={() => selectPlayer(player)}
                  class="w-full text-left border border-gray-200 rounded-lg p-3 hover:bg-blue-50 hover:border-blue-300 transition-colors {selectedPlayer?.numero_soci === player.numero_soci ? 'bg-blue-50 border-blue-400' : ''}"
                >
                  <div class="font-medium text-gray-900 text-sm">
                    {player.nom} {player.cognoms}
                  </div>
                </button>
              {/each}
            </div>
          {:else if searchTerm.length >= 3 && !loading}
            <div class="text-center py-4">
              <p class="text-sm text-gray-500">No s'han trobat jugadors</p>
            </div>
          {:else if searchTerm.length > 0 && searchTerm.length < 3}
            <div class="text-center py-4">
              <p class="text-sm text-gray-500">Escriu almenys 3 caràcters</p>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Results Panel -->
    <div class="lg:col-span-2">
      {#if selectedPlayer}
        <div class="space-y-6">
          <!-- Player Info -->
          <div class="bg-white border border-gray-200 rounded-lg p-6">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-2xl font-bold text-gray-900">
                  {selectedPlayer.nom} {selectedPlayer.cognoms}
                </h2>
              </div>
              <button
                on:click={clearSelection}
                class="text-gray-400 hover:text-gray-600"
                aria-label="Netejar selecció de jugador"
              >
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Modality Filter -->
            <div class="mt-6">
              <label for="modalitat" class="block text-sm font-medium text-gray-700 mb-2">
                Filtrar per modalitat
              </label>
              <select
                id="modalitat"
                bind:value={selectedModalitat}
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              >
                {#each modalitats as mod}
                  <option value={mod.value}>{mod.label}</option>
                {/each}
              </select>
            </div>
          </div>

          <!-- Chart -->
          {#if loadingHistory}
            <div class="bg-white border border-gray-200 rounded-lg p-6 flex items-center justify-center h-96">
              <div class="text-center">
                <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
                <p class="mt-4 text-sm text-gray-600">Carregant històric...</p>
              </div>
            </div>
          {:else}
            <PlayerAverageEvolution
              history={playerHistory}
              playerName="{selectedPlayer.nom} {selectedPlayer.cognoms}"
              modalitat={selectedModalitat}
            />
          {/if}

          <!-- Classifications Panel: posicions per categoria -->
          {#if loadingClassifications}
            <div class="bg-white border border-gray-200 rounded-lg p-6 text-center">
              <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600 inline-block"></div>
              <p class="mt-2 text-sm text-gray-600">Carregant classificacions...</p>
            </div>
          {:else if filteredClassifications.length > 0}
            <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900 flex items-center gap-2">
                  <span>🏆</span> Classificacions per Categoria
                </h3>
                <p class="text-xs text-gray-500 mt-1">Posició final i punts en cada campionat disputat</p>
              </div>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Temporada</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Modalitat</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Categoria</th>
                      <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Posició</th>
                      <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Punts</th>
                      <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">PJ</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    {#each filteredClassifications.slice().sort((a, b) => {
                      if (a.temporada !== b.temporada) return b.temporada.localeCompare(a.temporada);
                      if (a.modalitat !== b.modalitat) return a.modalitat.localeCompare(b.modalitat);
                      return a.posicio - b.posicio;
                    }) as record}
                      <tr class="hover:bg-gray-50">
                        <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">{record.temporada}</td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-600">{record.modalitat}</td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-600">{record.categoria}</td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-center font-semibold">
                          <span class="inline-flex items-center gap-1">
                            {getPositionMedal(record.posicio)}
                            <span class:text-yellow-700={record.posicio === 1} class:text-gray-700={record.posicio !== 1}>{record.posicio}</span>
                          </span>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-center">
                          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">{record.punts}</span>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-center text-gray-600">{record.partides_jugades}</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            </div>
          {/if}

          <!-- History Table -->
          {#if playerHistory.length > 0}
            <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Històric Detallat de Mitjanes</h3>
              </div>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Temporada
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Modalitat
                      </th>
                      <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Mitjana
                      </th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    {#each playerHistory.sort((a, b) => {
                      // Sort by modalitat first, then by temporada descending
                      if (a.modalitat !== b.modalitat) {
                        return a.modalitat.localeCompare(b.modalitat);
                      }
                      return b.temporada.localeCompare(a.temporada);
                    }) as record}
                      <tr class="hover:bg-gray-50">
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                          {record.temporada}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                          {getModalitatName(record.modalitat)}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-center font-semibold text-gray-900">
                          {record.mitjana_particular.toFixed(3)}
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            </div>
          {/if}
        </div>
      {:else}
        <!-- Empty State -->
        <div class="bg-white border border-gray-200 rounded-lg p-12 flex items-center justify-center min-h-96">
          <div class="text-center">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">Selecciona un jugador</h3>
            <p class="mt-1 text-sm text-gray-500">Cerca un jugador per veure la seva evolució de mitjanes</p>
          </div>
        </div>
      {/if}
    </div>
  </div>
</div>