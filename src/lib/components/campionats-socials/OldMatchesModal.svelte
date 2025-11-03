<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  const dispatch = createEventDispatcher();

  export let eventId: string;
  export let categories: any[] = [];

  let loading = true;
  let oldMatches: any[] = [];
  let selectedMatches: Set<string> = new Set();
  let error = '';
  let converting = false;

  // Filtres
  let selectedCategoryFilter: string = 'all';
  let searchText: string = '';

  $: if (eventId) {
    loadOldMatches();
  }

  // Filtrar partides segons els criteris seleccionats
  $: filteredMatches = oldMatches.filter(match => {
    // Filtre per categoria
    if (selectedCategoryFilter !== 'all' && match.categoria_id !== selectedCategoryFilter) {
      return false;
    }

    // Filtre per text de cerca (nom jugadors)
    if (searchText.trim()) {
      const searchLower = searchText.toLowerCase();
      const player1Name = getPlayerName(match.jugador1).toLowerCase();
      const player2Name = getPlayerName(match.jugador2).toLowerCase();
      if (!player1Name.includes(searchLower) && !player2Name.includes(searchLower)) {
        return false;
      }
    }

    return true;
  });

  async function loadOldMatches() {
    try {
      loading = true;
      error = '';

      // Obtenir la data d'avui a les 00:00:00
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayStr = today.toISOString();

      console.log('Looking for matches programmed before:', todayStr);

      // Buscar partides programades en el passat sense resultats
      const { data: matchesData, error: fetchError } = await supabase
        .from('calendari_partides')
        .select('*')
        .eq('event_id', eventId)
        .in('estat', ['generat', 'validat', 'publicat'])
        .lt('data_programada', todayStr)
        .is('caramboles_jugador1', null)
        .is('caramboles_jugador2', null)
        .order('data_programada', { ascending: false });

      if (fetchError) throw fetchError;

      if (!matchesData || matchesData.length === 0) {
        oldMatches = [];
        loading = false;
        return;
      }

      // Obtenir IDs únics de jugadors
      const jugadorIds = Array.from(new Set([
        ...matchesData.map(m => m.jugador1_id),
        ...matchesData.map(m => m.jugador2_id)
      ].filter(id => id)));

      // Carregar dades de jugadors via players → socis
      const playersMap = new Map();
      if (jugadorIds.length > 0) {
        const { data: playersData } = await supabase
          .from('players')
          .select('id, numero_soci')
          .in('id', jugadorIds);

        if (playersData && playersData.length > 0) {
          const socisIds = playersData.map(p => p.numero_soci).filter(Boolean);
          const { data: socisData } = await supabase
            .from('socis')
            .select('numero_soci, nom, cognoms')
            .in('numero_soci', socisIds);

          if (socisData) {
            const socisMap = new Map(socisData.map(s => [s.numero_soci, s]));
            playersData.forEach(p => {
              const sociData = socisMap.get(p.numero_soci);
              if (sociData) {
                playersMap.set(p.id, sociData);
              }
            });
          }
        }
      }

      // Carregar categories
      const categoriesMap = new Map(categories.map(c => [c.id, c]));

      // Combinar tota la informació
      oldMatches = matchesData.map(match => ({
        ...match,
        jugador1: playersMap.get(match.jugador1_id) || null,
        jugador2: playersMap.get(match.jugador2_id) || null,
        categoria: categoriesMap.get(match.categoria_id) || null
      }));

    } catch (e: any) {
      console.error('Error loading old matches:', e);
      error = e.message || 'Error carregant partides antigues';
    } finally {
      loading = false;
    }
  }

  function getPlayerName(player: any): string {
    if (!player) return 'Desconegut';
    return `${player.nom} ${player.cognoms || ''}`.trim();
  }

  function getCategoryName(match: any): string {
    return match.categoria?.nom || 'Sense categoria';
  }

  function formatDate(dateStr: string): string {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleDateString('ca-ES', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      weekday: 'short'
    });
  }

  function toggleMatch(matchId: string) {
    if (selectedMatches.has(matchId)) {
      selectedMatches.delete(matchId);
    } else {
      selectedMatches.add(matchId);
    }
    selectedMatches = selectedMatches;
  }

  function selectAll() {
    selectedMatches = new Set(filteredMatches.map(m => m.id));
  }

  function deselectAll() {
    selectedMatches = new Set();
  }

  async function confirmConversion() {
    if (selectedMatches.size === 0 || converting) return;

    try {
      converting = true;
      error = '';

      console.log('Converting', selectedMatches.size, 'matches to pending...');

      // Convertir les partides a pendent_programar
      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          estat: 'pendent_programar',
          data_programada: null,
          hora_inici: null,
          taula_assignada: null
        })
        .in('id', Array.from(selectedMatches));

      if (updateError) {
        console.error('Update error:', updateError);
        throw new Error(updateError.message || 'Error desconegut en convertir les partides');
      }

      console.log('✅ Matches converted successfully');
      dispatch('matchesConverted', { count: selectedMatches.size });
      dispatch('close');
    } catch (e: any) {
      console.error('Error converting matches:', e);
      error = e.message || 'Error convertint les partides';
      converting = false;
    }
  }

  function close() {
    dispatch('close');
  }
</script>

<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 pt-20">
  <div class="bg-white rounded-lg shadow-xl max-w-3xl w-full max-h-[85vh] overflow-hidden flex flex-col">
    <!-- Header -->
    <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-xl font-bold text-gray-900">Partides Antigues sense Resultats</h3>
          <p class="text-sm text-gray-600 mt-1">
            Selecciona les partides que vols convertir a "Pendent de programar"
          </p>
        </div>
        <button
          on:click={close}
          class="text-gray-400 hover:text-gray-600 transition-colors"
          title="Tancar"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    </div>

    <!-- Content -->
    <div class="flex-1 overflow-y-auto p-6">
      {#if loading}
        <div class="flex items-center justify-center py-12">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600"></div>
          <p class="ml-3 text-gray-600">Carregant partides antigues...</p>
        </div>
      {:else if error}
        <div class="bg-red-50 border border-red-200 rounded-lg p-4">
          <p class="text-red-800">{error}</p>
        </div>
      {:else if oldMatches.length === 0}
        <div class="text-center py-12">
          <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <p class="text-gray-600 text-lg">No hi ha partides antigues sense resultats</p>
          <p class="text-gray-500 text-sm mt-2">Totes les partides programades en el passat tenen resultats o ja estan pendents</p>
        </div>
      {:else}
        <!-- Filtres -->
        <div class="mb-4 space-y-3 bg-gray-50 p-4 rounded-lg">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <!-- Filtre per categoria -->
            <div>
              <label for="old-filter-category" class="block text-sm font-medium text-gray-700 mb-1">Categoria</label>
              <select
                id="old-filter-category"
                bind:value={selectedCategoryFilter}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
              >
                <option value="all">Totes les categories</option>
                {#each categories as category}
                  <option value={category.id}>{category.nom}</option>
                {/each}
              </select>
            </div>

            <!-- Cerca per nom -->
            <div>
              <label for="old-search-player" class="block text-sm font-medium text-gray-700 mb-1">Cerca jugador</label>
              <input
                id="old-search-player"
                type="text"
                bind:value={searchText}
                placeholder="Nom del jugador..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
              />
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div class="text-sm text-gray-600">
              Mostrant {filteredMatches.length} de {oldMatches.length} partides
            </div>
            <div class="flex gap-2">
              <button
                on:click={selectAll}
                class="px-3 py-1 text-sm bg-purple-100 text-purple-700 rounded hover:bg-purple-200"
              >
                Seleccionar Totes ({filteredMatches.length})
              </button>
              <button
                on:click={deselectAll}
                class="px-3 py-1 text-sm bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
              >
                Deseleccionar Totes
              </button>
            </div>
          </div>
        </div>

        <!-- Llista de partides -->
        {#if filteredMatches.length === 0}
          <div class="text-center py-8">
            <p class="text-gray-500">No hi ha partides que coincideixin amb els filtres</p>
          </div>
        {:else}
          <div class="space-y-2">
            {#each filteredMatches as match}
              <button
                on:click={() => toggleMatch(match.id)}
                class="w-full text-left p-4 border-2 rounded-lg transition-all {
                  selectedMatches.has(match.id)
                    ? 'border-purple-500 bg-purple-50'
                    : 'border-gray-200 hover:border-purple-300 hover:bg-gray-50'
                }"
              >
                <div class="flex items-center justify-between">
                  <div class="flex-1">
                    <div class="flex items-center gap-3 mb-2">
                      <span class="px-2 py-1 bg-purple-100 text-purple-800 text-xs font-semibold rounded">
                        {getCategoryName(match)}
                      </span>
                      <span class="px-2 py-1 bg-red-100 text-red-800 text-xs font-semibold rounded">
                        {formatDate(match.data_programada)}
                      </span>
                      {#if match.hora_inici}
                        <span class="text-sm text-gray-600">
                          {match.hora_inici}
                        </span>
                      {/if}
                      {#if match.taula_assignada}
                        <span class="text-sm text-gray-600">
                          Billar {match.taula_assignada}
                        </span>
                      {/if}
                    </div>
                    <div class="font-semibold text-gray-900">
                      {getPlayerName(match.jugador1)} vs {getPlayerName(match.jugador2)}
                    </div>
                  </div>
                  {#if selectedMatches.has(match.id)}
                    <svg class="w-6 h-6 text-purple-600 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                    </svg>
                  {/if}
                </div>
              </button>
            {/each}
          </div>
        {/if}
      {/if}
    </div>

    <!-- Footer -->
    <div class="px-6 py-4 border-t border-gray-200 bg-gray-50 flex items-center justify-between">
      <div class="text-sm text-gray-600">
        {#if !loading && oldMatches.length > 0}
          {selectedMatches.size} {selectedMatches.size === 1 ? 'partida seleccionada' : 'partides seleccionades'}
        {/if}
      </div>
      <div class="flex gap-3">
        <button
          on:click={close}
          disabled={converting}
          class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-50"
        >
          Cancel·lar
        </button>
        <button
          on:click={confirmConversion}
          disabled={selectedMatches.size === 0 || converting}
          class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center"
        >
          {#if converting}
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
            Convertint...
          {:else}
            Convertir a Pendent ({selectedMatches.size})
          {/if}
        </button>
      </div>
    </div>
  </div>
</div>
