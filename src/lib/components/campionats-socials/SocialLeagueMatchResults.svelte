<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  export let eventId: string = '';
  export let categories: any[] = [];

  let matches: any[] = [];
  let unprogrammedMatches: any[] = [];
  let allMatches: any[] = []; // All matches for total count
  let loadedCategories: any[] = []; // Categories loaded directly
  let loading = false;
  let error: string | null = null;
  let selectedCategories: Set<string> = new Set(); // Multiple category selection
  let searchPlayer = ''; // Search text for player filter

  onMount(() => {
    if (eventId) {
      loadMatches();
      loadCategories();
    }
  });

  $: if (eventId) {
    loadMatches();
    loadCategories();
  }

  async function loadCategories() {
    try {
      const { data, error: categoriesError } = await supabase
        .from('categories')
        .select('*')
        .eq('event_id', eventId)
        .order('ordre_categoria', { ascending: true });

      if (categoriesError) throw categoriesError;
      loadedCategories = data || [];
    } catch (e) {
      console.error('Error loading categories:', e);
    }
  }

  async function loadMatches() {
    loading = true;
    error = null;

    try {
      // Programmed and completed matches
      const { data, error: matchesError } = await supabase
        .rpc('get_match_results_public', {
          p_event_id: eventId
        });

      if (matchesError) throw matchesError;
      matches = data || [];

      // Load ALL matches for total count
      const { data: allMatchesData, error: allMatchesError } = await supabase
        .from('calendari_partides')
        .select('id, estat, caramboles_jugador1, caramboles_jugador2, data_programada')
        .eq('event_id', eventId);

      if (allMatchesError) throw allMatchesError;
      allMatches = allMatchesData || [];

      // Unprogrammed matches (estat = 'pendent_programar')
      const { data: unprogrammed, error: unprogrammedError } = await supabase
        .from('calendari_partides')
        .select('*')
        .eq('event_id', eventId)
        .eq('estat', 'pendent_programar');
      if (unprogrammedError) throw unprogrammedError;
      unprogrammedMatches = unprogrammed || [];
    } catch (e) {
      console.error('Error loading matches:', e);
      error = 'Error carregant els resultats';
    } finally {
      loading = false;
    }
  }

  function formatPlayerName(nom: string, cognoms: string, numeroSoci?: number) {
    if (!nom && !cognoms) return 'Jugador desconegut';

    // Format: inicial(s) del nom + primer cognom
    // Example: "Joan Pere" "García López" -> "J.P. García"

    let inicials = '';
    if (nom) {
      const noms = nom.trim().split(/\s+/);
      inicials = noms.map(n => n.charAt(0).toUpperCase() + '.').join('');
    }

    const primerCognom = cognoms ? cognoms.trim().split(/\s+/)[0] : '';

    if (inicials && primerCognom) {
      return `${inicials} ${primerCognom}`;
    } else if (inicials) {
      return inicials;
    } else if (primerCognom) {
      return primerCognom;
    }

    return 'Jugador desconegut';
  }

  function getMatchStatus(match: any) {
    // Una partida està completada si té resultats registrats
    if (match.caramboles_reptador !== null && match.caramboles_reptat !== null) {
      return 'completed';
    }
    if (match.data_programada && new Date(match.data_programada) < new Date()) return 'pending';
    return 'scheduled';
  }

  // Funció per verificar si una partida està completada
  function isMatchCompleted(match: any) {
    return match.caramboles_reptador !== null &&
           match.caramboles_reptat !== null;
  }

  function getStatusColor(status: string) {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'pending': return 'bg-red-100 text-red-800';
      case 'scheduled': return 'bg-blue-100 text-blue-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }

  function getStatusText(status: string) {
    switch (status) {
      case 'completed': return 'Completada';
      case 'pending': return 'Pendent resultat';
      case 'scheduled': return 'Programada';
      default: return 'Desconegut';
    }
  }

  function getMatchWinner(match: any) {
    if (!isMatchCompleted(match)) {
      return null;
    }

    if (match.caramboles_reptador > match.caramboles_reptat) return 1;
    if (match.caramboles_reptat > match.caramboles_reptador) return 2;
    return 0; // tie
  }

  // Calcular mitjana d'un jugador en una partida
  function calcularMitjana(caramboles: number, entrades: number): string {
    if (!entrades || entrades === 0) return '0.000';
    return (caramboles / entrades).toFixed(3);
  }

  function formatMatchDate(dateStr: string) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleDateString('ca-ES', {
      weekday: 'short',
      day: 'numeric',
      month: 'short'
    });
  }

  function formatMatchTime(timeStr: string) {
    if (!timeStr) return '';
    return timeStr.substring(0, 5); // HH:MM
  }

  // Toggle category selection
  function toggleCategory(categoryId: string) {
    if (selectedCategories.has(categoryId)) {
      selectedCategories.delete(categoryId);
    } else {
      selectedCategories.add(categoryId);
    }
    selectedCategories = selectedCategories; // Trigger reactivity
  }

  // Filter matches based on selected categories and player search
  $: filteredMatches = matches.filter(match => {
    // Only show completed matches (with results)
    if (!isMatchCompleted(match)) {
      return false;
    }

    // Filter by category (if any selected)
    if (selectedCategories.size > 0 && !selectedCategories.has(match.categoria_id)) {
      return false;
    }

    // Filter by player name
    if (searchPlayer.trim() !== '') {
      const searchLower = searchPlayer.toLowerCase();
      const player1Name = formatPlayerName(match.jugador1_nom, match.jugador1_cognoms, match.jugador1_numero_soci).toLowerCase();
      const player2Name = formatPlayerName(match.jugador2_nom, match.jugador2_cognoms, match.jugador2_numero_soci).toLowerCase();

      if (!player1Name.includes(searchLower) && !player2Name.includes(searchLower)) {
        return false;
      }
    }

    return true;
  });

  // Group matches by status for summary
  $: matchesByStatus = {
    completed: matches.filter(m => getMatchStatus(m) === 'completed').length,
    pending: matches.filter(m => getMatchStatus(m) === 'pending').length,
    scheduled: matches.filter(m => getMatchStatus(m) === 'scheduled').length
  };

  // Use loaded categories if available, otherwise use prop
  $: finalCategories = loadedCategories.length > 0 ? loadedCategories : categories;

  // Sort categories by order
  $: sortedCategories = finalCategories.sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));
</script>

<div class="space-y-6">
  <!-- Filters -->
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="space-y-6">
      <!-- Category filter with buttons (multiple selection) -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-3">
          Categories {selectedCategories.size > 0 ? `(${selectedCategories.size} seleccionades)` : ''}
        </label>
        <div class="flex flex-wrap gap-2">
          {#each sortedCategories as category}
            <button
              on:click={() => toggleCategory(category.id)}
              class="px-4 py-2 rounded-md text-sm font-medium transition-colors {
                selectedCategories.has(category.id)
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }"
            >
              {category.nom}
            </button>
          {/each}
          {#if selectedCategories.size > 0}
            <button
              on:click={() => selectedCategories = new Set()}
              class="px-4 py-2 rounded-md text-sm font-medium bg-red-100 text-red-700 hover:bg-red-200"
            >
              Netejar filtres
            </button>
          {/if}
        </div>
      </div>

      <!-- Player search -->
      <div>
        <label for="player-search" class="block text-sm font-medium text-gray-700 mb-2">
          Cerca per jugador
        </label>
        <div class="relative">
          <input
            id="player-search"
            type="text"
            bind:value={searchPlayer}
            placeholder="Escriu nom o cognoms del jugador..."
            class="w-full px-4 py-2 pl-10 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
          <svg class="absolute left-3 top-2.5 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
          </svg>
          {#if searchPlayer}
            <button
              on:click={() => searchPlayer = ''}
              class="absolute right-3 top-2.5 text-gray-400 hover:text-gray-600"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          {/if}
        </div>
      </div>

      <!-- Summary stats -->
      <div class="grid grid-cols-2 gap-4">
        <div class="text-center bg-gray-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-gray-900">{allMatches.length}</div>
          <div class="text-sm text-gray-500">Total Partides</div>
        </div>
        <div class="text-center bg-green-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-green-600">{matchesByStatus.completed}</div>
          <div class="text-sm text-gray-500">Partides Jugades</div>
        </div>
      </div>
    </div>
  </div>

  {#if loading}
    <div class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant resultats...</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-red-800 mb-2">Error</h3>
      <p class="text-red-600">{error}</p>
    </div>
  {:else if filteredMatches.length === 0}
    <div class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">
        {selectedCategories.size > 0 || searchPlayer !== '' ? 'No hi ha partides amb aquests filtres' : 'No hi ha resultats de partides'}
      </h3>
      <p class="mt-1 text-sm text-gray-500">
        {selectedCategories.size > 0 || searchPlayer !== '' ? 'Prova a canviar els filtres de categoria o cerca de jugador.' : 'Encara no s\'han jugat partides en aquest campionat.'}
      </p>
    </div>
  {:else}
    <!-- Matches list -->
    <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-300">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                Categoria
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Jugadors
              </th>
              <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                Caramboles
              </th>
              <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                Mitjanes
              </th>
              <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                Entrades
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            {#each filteredMatches as match (match.id)}
              {@const status = getMatchStatus(match)}
              {@const winner = getMatchWinner(match)}
              <tr class="hover:bg-gray-50">
                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6">
                  <div>
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      {match.categoria_nom || 'Sense categoria'}
                    </span>
                    {#if match.categoria_distancia}
                      <div class="text-xs text-gray-500 mt-1">
                        {match.categoria_distancia} caramboles
                      </div>
                    {/if}
                  </div>
                </td>
                <td class="px-3 py-4 text-sm">
                  <div class="space-y-1">
                    <div class="flex items-center {winner === 1 ? 'font-semibold text-green-600' : 'text-gray-900'}">
                      <span class="mr-2">{winner === 1 ? '🏆' : ''}</span>
                      {formatPlayerName(match.jugador1_nom, match.jugador1_cognoms, match.jugador1_numero_soci)}
                    </div>
                    <div class="text-gray-400 text-xs">vs</div>
                    <div class="flex items-center {winner === 2 ? 'font-semibold text-green-600' : 'text-gray-900'}">
                      <span class="mr-2">{winner === 2 ? '🏆' : ''}</span>
                      {formatPlayerName(match.jugador2_nom, match.jugador2_cognoms, match.jugador2_numero_soci)}
                    </div>
                  </div>
                </td>
                <td class="px-3 py-4 text-sm text-center">
                  {#if status === 'completed'}
                    <div class="space-y-1">
                      <div class="font-mono text-base {winner === 1 ? 'font-bold text-green-600' : 'text-gray-700'}">
                        {match.caramboles_reptador ?? 0}
                      </div>
                      <div class="text-gray-400 text-xs">-</div>
                      <div class="font-mono text-base {winner === 2 ? 'font-bold text-green-600' : 'text-gray-700'}">
                        {match.caramboles_reptat ?? 0}
                      </div>
                    </div>
                  {:else}
                    <span class="text-gray-400 text-sm">-</span>
                  {/if}
                </td>
                <td class="px-3 py-4 text-sm text-center">
                  {#if status === 'completed' && match.entrades}
                    <div class="space-y-1">
                      <div class="font-mono text-sm {winner === 1 ? 'font-semibold text-green-600' : 'text-gray-600'}">
                        {calcularMitjana(match.caramboles_reptador, match.entrades)}
                      </div>
                      <div class="text-gray-400 text-xs">-</div>
                      <div class="font-mono text-sm {winner === 2 ? 'font-semibold text-green-600' : 'text-gray-600'}">
                        {calcularMitjana(match.caramboles_reptat, match.entrades)}
                      </div>
                    </div>
                  {:else}
                    <span class="text-gray-400 text-sm">-</span>
                  {/if}
                </td>
                <td class="px-3 py-4 text-sm text-center">
                  {#if status === 'completed'}
                    <span class="font-mono text-gray-700">{match.entrades ?? '-'}</span>
                  {:else}
                    <span class="text-gray-400">-</span>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>

  {/if}
</div>