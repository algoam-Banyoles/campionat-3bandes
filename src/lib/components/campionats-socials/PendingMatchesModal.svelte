<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  const dispatch = createEventDispatcher();

  export let eventId: string;
  export let slot: any;
  export let categories: any[] = [];

  let loading = true;
  let pendingMatches: any[] = [];
  let selectedMatch: any = null;
  let error = '';

  // Filtres
  let selectedCategoryFilter: string = 'all';
  let searchText: string = '';

  $: if (eventId) {
    loadPendingMatches();
  }

  // Filtrar partides segons els criteris seleccionats
  $: filteredMatches = pendingMatches.filter(match => {
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

  async function loadPendingMatches() {
    try {
      loading = true;
      error = '';
      const withdrawnSocis = new Set<number>();

      const { data: inscriptionsData, error: inscriptionsError } = await supabase
        .rpc('get_inscripcions_with_socis', {
          p_event_id: eventId
        });

      if (!inscriptionsError) {
        (inscriptionsData || [])
          .filter((item: any) => item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences)
          .forEach((item: any) => {
            if (typeof item.soci_numero === 'number') {
              withdrawnSocis.add(item.soci_numero);
            }
          });
      }

      // Carregar partides pendents de programar
      // Busquem partides amb estat 'generat' o 'pendent_programar' que no tinguin data
      const { data: matchesData, error: fetchError } = await supabase
        .from('calendari_partides')
        .select('*')
        .eq('event_id', eventId)
        .or('estat.eq.generat,estat.eq.pendent_programar')
        .is('data_programada', null)
        .order('categoria_id');

      if (fetchError) throw fetchError;

      if (!matchesData || matchesData.length === 0) {
        pendingMatches = [];
        loading = false;
        return;
      }
      let filteredMatchesData = [...matchesData];

      // Fase 5c-S2c-2: Filtrar i carregar socis directament per soci_numero,
      // sense passar per `players`.
      if (withdrawnSocis.size > 0) {
        filteredMatchesData = filteredMatchesData.filter((match: any) => {
          return !withdrawnSocis.has(match.jugador1_soci_numero ?? -1)
              && !withdrawnSocis.has(match.jugador2_soci_numero ?? -1);
        });
      }

      const sociNumbers = Array.from(new Set([
        ...filteredMatchesData.map((m: any) => m.jugador1_soci_numero),
        ...filteredMatchesData.map((m: any) => m.jugador2_soci_numero)
      ].filter((n: any) => typeof n === 'number'))) as number[];

      // Map per soci_numero (no per player_id UUID)
      const playersMap = new Map<number, any>();
      if (sociNumbers.length > 0) {
        const { data: socisData } = await supabase
          .from('socis')
          .select('numero_soci, nom, cognoms')
          .in('numero_soci', sociNumbers);
        (socisData ?? []).forEach((s: any) => playersMap.set(s.numero_soci, s));
      }

      // Carregar categories
      const categoriesMap = new Map(categories.map(c => [c.id, c]));

      // Combinar tota la informació
      pendingMatches = filteredMatchesData.map((match: any) => ({
        ...match,
        jugador1: playersMap.get(match.jugador1_soci_numero) || null,
        jugador2: playersMap.get(match.jugador2_soci_numero) || null,
        categoria: categoriesMap.get(match.categoria_id) || null
      }));

      // Ordenar per ordre de categoria (si existeix) o pel nom de categoria
      pendingMatches.sort((a, b) => {
        const categoriaA = a.categoria;
        const categoriaB = b.categoria;

        // Si ambdues categories tenen camp 'ordre', ordenar per ordre
        if (categoriaA?.ordre !== undefined && categoriaB?.ordre !== undefined) {
          return categoriaA.ordre - categoriaB.ordre;
        }

        // Si no, ordenar per nom de categoria
        const nomA = categoriaA?.nom || '';
        const nomB = categoriaB?.nom || '';
        return nomA.localeCompare(nomB);
      });

    } catch (e: any) {
      console.error('Error loading pending matches:', e);
      error = e.message || 'Error carregant partides pendents';
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

  function selectMatch(match: any) {
    selectedMatch = match;
  }

  let programming = false;

  async function confirmSelection() {
    if (!selectedMatch || programming) return;

    try {
      programming = true;
      error = '';

      console.log('Programming match:', selectedMatch.id, 'in slot:', slot);

      // Programar la partida en el slot seleccionat
      const updates = {
        data_programada: slot.dateStr + 'T' + slot.hora + ':00',
        hora_inici: slot.hora,
        taula_assignada: slot.taula,
        estat: 'validat'
      };

      console.log('Updating with:', updates);

      const { data: updateData, error: updateError } = await supabase
        .from('calendari_partides')
        .update(updates)
        .eq('id', selectedMatch.id)
        .select();

      if (updateError) {
        console.error('Update error:', updateError);
        console.error('Update error details:', JSON.stringify(updateError, null, 2));
        throw new Error(updateError.message || 'Error desconegut en actualitzar la partida');
      }

      console.log('Update result:', updateData);

      console.log('Match programmed successfully');
      dispatch('matchProgrammed', { matchId: selectedMatch.id });
      dispatch('close');
    } catch (e: any) {
      console.error('Error programming match:', e);
      error = e.message || 'Error programant la partida';
      programming = false;
    }
  }

  function close() {
    dispatch('close');
  }
</script>

<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
  <div class="bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
    <!-- Header -->
    <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-xl font-bold text-gray-900">Partides Pendents de Programar</h3>
          <p class="text-sm text-gray-600 mt-1">
            Slot: {slot.dateStr} · {slot.hora} · Billar {slot.taula}
          </p>
        </div>
        <button
          type="button"
          on:click={close}
          class="text-gray-400 hover:text-gray-600 transition-colors"
          title="Tancar"
          aria-label="Tancar modal"
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
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          <p class="ml-3 text-gray-600">Carregant partides...</p>
        </div>
      {:else if error}
        <div class="bg-red-50 border border-red-200 rounded-lg p-4">
          <p class="text-red-800">{error}</p>
        </div>
      {:else if pendingMatches.length === 0}
        <div class="text-center py-12">
          <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
          </svg>
          <p class="text-gray-600 text-lg">No hi ha partides pendents de programar</p>
        </div>
      {:else}
        <!-- Filtres -->
        <div class="mb-4 space-y-3 bg-gray-50 p-4 rounded-lg">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <!-- Filtre per categoria -->
            <div>
              <label for="pending-filter-category" class="block text-sm font-medium text-gray-700 mb-1">Categoria</label>
                <select
                  id="pending-filter-category"
                  bind:value={selectedCategoryFilter}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="all">Totes les categories</option>
                {#each categories as category}
                  <option value={category.id}>{category.nom}</option>
                {/each}
              </select>
            </div>

            <!-- Cerca per nom -->
            <div>
              <label for="pending-search-player" class="block text-sm font-medium text-gray-700 mb-1">Cerca jugador</label>
              <input
                id="pending-search-player"
                type="text"
                bind:value={searchText}
                placeholder="Nom del jugador..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>

          <div class="text-sm text-gray-600">
            Mostrant {filteredMatches.length} de {pendingMatches.length} partides
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
              on:click={() => selectMatch(match)}
              class="w-full text-left p-4 border-2 rounded-lg transition-all {
                selectedMatch?.id === match.id
                  ? 'border-blue-500 bg-blue-50'
                  : 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'
              }"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-3">
                    <span class="px-2 py-1 bg-purple-100 text-purple-800 text-xs font-semibold rounded">
                      {getCategoryName(match)}
                    </span>
                    <div class="font-semibold text-gray-900">
                      {getPlayerName(match.jugador1)} vs {getPlayerName(match.jugador2)}
                    </div>
                  </div>
                </div>
                {#if selectedMatch?.id === match.id}
                  <svg class="w-6 h-6 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
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
        {#if !loading && pendingMatches.length > 0}
          {filteredMatches.length} de {pendingMatches.length} {pendingMatches.length === 1 ? 'partida' : 'partides'}
        {/if}
      </div>
      <div class="flex gap-3">
        <button
          on:click={close}
          disabled={programming}
          class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-50"
        >
          Cancel·lar
        </button>
        <button
          on:click={confirmSelection}
          disabled={!selectedMatch || programming}
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center"
        >
          {#if programming}
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
            Programant...
          {:else}
            Programar Partida
          {/if}
        </button>
      </div>
    </div>
  </div>
</div>
