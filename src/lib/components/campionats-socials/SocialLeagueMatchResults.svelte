<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { user } from '$lib/stores/auth';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
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
  let showOnlyMyResults = false;
  let myPlayerData: any = null;

  // Admin edit functionality
  let editingMatch: any = null;
  let editForm = {
    caramboles_reptador: 0,
    caramboles_reptat: 0,
    entrades: 0
  };
  let updateError: string | null = null;
  let updateSuccess: string | null = null;

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

  // Load player data for logged-in user
  async function loadMyPlayerData() {
    if (!$user) {
      myPlayerData = null;
      return;
    }

    try {
      // Use email to find player since players table doesn't have user_id
      const { data: playerData, error: playerError } = await supabase
        .from('players')
        .select('id, numero_soci, nom, email')
        .eq('email', $user.email)
        .single();

      if (playerError) {
        console.log('No player data found for user email:', $user.email);
        myPlayerData = null;
      } else {
        myPlayerData = playerData;
        console.log('✅ Loaded player data for user:', myPlayerData);
      }
    } catch (e) {
      console.error('Error loading player data:', e);
      myPlayerData = null;
    }
  }

  // React to user changes
  $: if ($user) {
    console.log('🔍 User detected in results, loading player data:', $user.id);
    loadMyPlayerData();
  } else {
    console.log('🔍 No user in results');
    myPlayerData = null;
    showOnlyMyResults = false;
  }

  // Debug myPlayerData changes
  $: console.log('🎯 Results - myPlayerData:', myPlayerData, 'showOnlyMyResults:', showOnlyMyResults);

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

    // Filter "Les meves dades" per jugador logat
    if (showOnlyMyResults && myPlayerData) {
      const isMyMatch = match.jugador1_id === myPlayerData.id || match.jugador2_id === myPlayerData.id;
      if (!isMyMatch) return false;
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

  // Admin functions
  function startEditingMatch(match: any) {
    editingMatch = match;
    editForm = {
      caramboles_reptador: match.caramboles_reptador ?? 0,
      caramboles_reptat: match.caramboles_reptat ?? 0,
      entrades: match.entrades ?? 0
    };
    updateError = null;
    updateSuccess = null;
  }

  function cancelEdit() {
    editingMatch = null;
    updateError = null;
    updateSuccess = null;
  }

  async function saveMatchResult() {
    if (!editingMatch) return;

    try {
      updateError = null;
      updateSuccess = null;

      const { data, error: updateErr } = await supabase
        .from('calendari_partides')
        .update({
          caramboles_reptador: editForm.caramboles_reptador,
          caramboles_reptat: editForm.caramboles_reptat,
          entrades: editForm.entrades
        })
        .eq('id', editingMatch.id)
        .select();

      if (updateErr) {
        console.error('Error updating match:', updateErr);
        throw updateErr;
      }

      if (!data || data.length === 0) {
        throw new Error('No s\'ha pogut actualitzar la partida. Comprova els permisos.');
      }

      updateSuccess = 'Resultat actualitzat correctament';

      // Reload matches to show updated data
      await loadMatches();

      // Close modal after a short delay
      setTimeout(() => {
        cancelEdit();
      }, 1500);

    } catch (e: any) {
      console.error('Exception updating match:', e);
      updateError = e.message || 'Error actualitzant el resultat';
    }
  }
</script>

<div class="space-y-6">
  <!-- Filters -->
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="space-y-6">
      <!-- Category filter with buttons (multiple selection) -->
      <fieldset>
        <legend class="block text-sm font-medium text-gray-700 mb-3">
          Categories {selectedCategories.size > 0 ? `(${selectedCategories.size} seleccionades)` : ''}
        </legend>
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
      </fieldset>

      <!-- Player search and checkbox in same row -->
      <div class="flex gap-4 items-start">
        <!-- Player search (more narrow) -->
        <div class="flex-1 max-w-md">
          <label for="player-search" class="block text-sm font-medium text-gray-700 mb-2">
            Cerca per jugador
          </label>
          <div class="relative">
            <input
              id="player-search"
              type="text"
              bind:value={searchPlayer}
              placeholder="Escriu nom o cognoms..."
              class="w-full px-4 py-2 pl-10 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              disabled={showOnlyMyResults}
            />
            <svg class="absolute left-3 top-2.5 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
            {#if searchPlayer}
              <button
                on:click={() => searchPlayer = ''}
                class="absolute right-3 top-2.5 text-gray-400 hover:text-gray-600"
                aria-label="Netejar cerca de jugador"
              >
                <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            {/if}
          </div>
        </div>

        <!-- Checkbox "Els meus resultats" al costat -->
        <div class="flex-shrink-0 pt-8">
          {#if myPlayerData}
            <label class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer whitespace-nowrap">
              <input
                type="checkbox"
                bind:checked={showOnlyMyResults}
                class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              />
              <span class="font-medium">🎯 Els meus resultats</span>
            </label>
          {:else}
            <div class="text-xs text-gray-400">
              DEBUG: user={$user ? 'YES' : 'NO'}, myPlayerData={myPlayerData ? 'YES' : 'NO'}
            </div>
          {/if}
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
              {#if $effectiveIsAdmin}
                <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                  Accions
                </th>
              {/if}
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
                      {#if match.incompareixenca_jugador1}
                        <span class="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">
                          No presentat
                        </span>
                      {/if}
                    </div>
                    <div class="text-gray-400 text-xs">vs</div>
                    <div class="flex items-center {winner === 2 ? 'font-semibold text-green-600' : 'text-gray-900'}">
                      <span class="mr-2">{winner === 2 ? '🏆' : ''}</span>
                      {formatPlayerName(match.jugador2_nom, match.jugador2_cognoms, match.jugador2_numero_soci)}
                      {#if match.incompareixenca_jugador2}
                        <span class="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">
                          No presentat
                        </span>
                      {/if}
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
                {#if $effectiveIsAdmin}
                  <td class="px-3 py-4 text-sm text-center">
                    {#if status === 'completed'}
                      <button
                        on:click={() => startEditingMatch(match)}
                        class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                      >
                        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                        </svg>
                        Editar
                      </button>
                    {:else}
                      <span class="text-gray-400">-</span>
                    {/if}
                  </td>
                {/if}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>

    <!-- Summary stats at the end -->
    <div class="bg-white border border-gray-200 rounded-lg p-6">
      <h4 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
        <span class="mr-2">📊</span>
        Resum de Partides
      </h4>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="text-center bg-gray-50 rounded-lg p-6">
          <div class="text-3xl font-bold text-gray-900">{allMatches.length}</div>
          <div class="text-sm text-gray-600 mt-1">Total Partides</div>
        </div>
        <div class="text-center bg-green-50 rounded-lg p-6">
          <div class="text-3xl font-bold text-green-600">{matchesByStatus.completed}</div>
          <div class="text-sm text-gray-600 mt-1">Partides Jugades</div>
        </div>
      </div>
    </div>

  {/if}
</div>

<!-- Edit Modal (Admin only) -->
{#if editingMatch && $effectiveIsAdmin}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" on:click={cancelEdit}>
    <div class="bg-white rounded-lg shadow-xl max-w-md w-full" on:click|stopPropagation>
      <div class="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 rounded-t-lg">
        <div class="flex items-center justify-between">
          <h2 class="text-xl font-semibold text-gray-900">Editar Resultat</h2>
          <button type="button" on:click={cancelEdit} class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <form on:submit|preventDefault={saveMatchResult} class="p-6 space-y-4">
        <!-- Match info -->
        <div class="bg-gray-50 rounded-lg p-4 mb-4">
          <div class="text-sm font-medium text-gray-900 mb-2">
            {formatPlayerName(editingMatch.jugador1_nom, editingMatch.jugador1_cognoms, editingMatch.jugador1_numero_soci)}
          </div>
          <div class="text-xs text-gray-500 mb-2">vs</div>
          <div class="text-sm font-medium text-gray-900">
            {formatPlayerName(editingMatch.jugador2_nom, editingMatch.jugador2_cognoms, editingMatch.jugador2_numero_soci)}
          </div>
        </div>

        <!-- Error/Success messages -->
        {#if updateError}
          <div class="rounded-md bg-red-50 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm font-medium text-red-800">{updateError}</p>
              </div>
            </div>
          </div>
        {/if}

        {#if updateSuccess}
          <div class="rounded-md bg-green-50 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm font-medium text-green-800">{updateSuccess}</p>
              </div>
            </div>
          </div>
        {/if}

        <!-- Form fields -->
        <div class="space-y-4">
          <div>
            <label for="caramboles_reptador" class="block text-sm font-medium text-gray-700 mb-2">
              Caramboles {formatPlayerName(editingMatch.jugador1_nom, editingMatch.jugador1_cognoms, editingMatch.jugador1_numero_soci)}
            </label>
            <input
              id="caramboles_reptador"
              type="number"
              min="0"
              bind:value={editForm.caramboles_reptador}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label for="caramboles_reptat" class="block text-sm font-medium text-gray-700 mb-2">
              Caramboles {formatPlayerName(editingMatch.jugador2_nom, editingMatch.jugador2_cognoms, editingMatch.jugador2_numero_soci)}
            </label>
            <input
              id="caramboles_reptat"
              type="number"
              min="0"
              bind:value={editForm.caramboles_reptat}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label for="entrades" class="block text-sm font-medium text-gray-700 mb-2">
              Entrades
            </label>
            <input
              id="entrades"
              type="number"
              min="1"
              bind:value={editForm.entrades}
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <!-- Calculated averages preview -->
          <div class="bg-blue-50 rounded-lg p-4">
            <div class="text-xs font-medium text-blue-900 mb-2">Mitjanes calculades:</div>
            <div class="grid grid-cols-2 gap-2 text-sm">
              <div>
                <div class="text-blue-700 font-mono">
                  {calcularMitjana(editForm.caramboles_reptador, editForm.entrades)}
                </div>
                <div class="text-xs text-blue-600">Jugador 1</div>
              </div>
              <div>
                <div class="text-blue-700 font-mono">
                  {calcularMitjana(editForm.caramboles_reptat, editForm.entrades)}
                </div>
                <div class="text-xs text-blue-600">Jugador 2</div>
              </div>
            </div>
          </div>
        </div>

        <div class="mt-6 flex justify-end space-x-3">
          <button
            type="button"
            on:click={cancelEdit}
            class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
          >
            Cancel·lar
          </button>
          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Guardar
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}