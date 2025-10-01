<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  export let eventId: string = '';
  export let categories: any[] = [];

  let matches: any[] = [];
  let unprogrammedMatches: any[] = [];
  let loading = false;
  let error: string | null = null;
  let selectedCategory = 'all';
  let selectedStatus = 'all'; // all, completed, scheduled, pending

  onMount(() => {
    if (eventId) {
      loadMatches();
    }
  });

  $: if (eventId) {
    loadMatches();
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
    
    // Format: "Nom Cognoms" or just use what we have
    const fullName = `${nom || ''} ${cognoms || ''}`.trim();
    return fullName || 'Jugador desconegut';
  }

  function getMatchStatus(match: any) {
    // Una partida està completada si té resultats registrats
    if (match.caramboles_reptador !== null && match.caramboles_reptat !== null && match.match_id !== null) {
      return 'completed';
    }
    if (match.data_programada && new Date(match.data_programada) < new Date()) return 'pending';
    return 'scheduled';
  }

  // Funció per verificar si una partida està completada
  function isMatchCompleted(match: any) {
    return match.caramboles_reptador !== null && 
           match.caramboles_reptat !== null && 
           match.match_id !== null;
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
    if (match.estat !== 'completada' || match.resultat_jugador1 === null || match.resultat_jugador2 === null) {
      return null;
    }

    if (match.resultat_jugador1 > match.resultat_jugador2) return 1;
    if (match.resultat_jugador2 > match.resultat_jugador1) return 2;
    return 0; // tie
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

  // Filter matches based on selected category and status
  // For public users, only show completed matches
  $: filteredMatches = matches.filter(match => {
    // Only show completed matches (with results)
    if (!isMatchCompleted(match)) {
      return false;
    }

    if (selectedCategory !== 'all' && match.categoria_id !== selectedCategory) {
      return false;
    }

    if (selectedStatus !== 'all') {
      const status = getMatchStatus(match);
      if (status !== selectedStatus) {
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

  // Sort categories by order
  $: sortedCategories = categories.sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));
</script>

<div class="space-y-6">
  <!-- Filters and summary -->
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6">
      <h3 class="text-lg font-medium text-gray-900 flex items-center mb-4 sm:mb-0">
        <span class="mr-2">⚡</span>
        Resultats de Partides
      </h3>

      <!-- Filters -->
      <div class="flex flex-col sm:flex-row gap-3">
        <select
          bind:value={selectedCategory}
          class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="all">Totes les categories</option>
          {#each sortedCategories as category}
            <option value={category.id}>{category.nom}</option>
          {/each}
        </select>

        <select
          bind:value={selectedStatus}
          class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="all">Tots els estats</option>
          <option value="completed">Completades</option>
          <option value="pending">Pendents resultat</option>
          <option value="scheduled">Programades</option>
        </select>
      </div>
    </div>

    <!-- Summary stats -->
    <div class="grid grid-cols-1 sm:grid-cols-4 gap-4">
      <div class="text-center">
        <div class="text-2xl font-bold text-gray-900">{matches.length + (unprogrammedMatches ? unprogrammedMatches.length : 0)}</div>
        <div class="text-sm text-gray-500">Total Partides</div>
      </div>
      <div class="text-center">
        <div class="text-2xl font-bold text-green-600">{matchesByStatus.completed}</div>
        <div class="text-sm text-gray-500">Completades</div>
      </div>
      <div class="text-center">
        <div class="text-2xl font-bold text-red-600">{matchesByStatus.pending}</div>
        <div class="text-sm text-gray-500">Pendents</div>
      </div>
      <div class="text-center">
        <div class="text-2xl font-bold text-blue-600">{matchesByStatus.scheduled}</div>
        <div class="text-sm text-gray-500">Programades</div>
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
        {selectedCategory !== 'all' || selectedStatus !== 'all' ? 'No hi ha partides amb aquests filtres' : 'No hi ha resultats de partides'}
      </h3>
      <p class="mt-1 text-sm text-gray-500">
        {selectedCategory !== 'all' || selectedStatus !== 'all' ? 'Prova a canviar els filtres de categoria o estat.' : 'Només es mostren partides que ja s\'han jugat i tenen resultats.'}
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
                Data i Hora
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Categoria
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Partida
              </th>
              <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                Resultat
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Estat
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Taula
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
                    <div class="font-medium text-gray-900">
                      {formatMatchDate(match.data_programada)}
                    </div>
                    <div class="text-gray-500">
                      {formatMatchTime(match.hora_inici)}
                    </div>
                  </div>
                </td>
                <td class="whitespace-nowrap px-3 py-4 text-sm">
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    {match.categories?.nom || 'Sense categoria'}
                  </span>
                  {#if match.categories?.distancia_caramboles}
                    <div class="text-xs text-gray-500 mt-1">
                      {match.categories.distancia_caramboles} caramboles
                    </div>
                  {/if}
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
                    <div class="font-mono text-lg">
                      <span class={winner === 1 ? 'font-bold text-green-600' : 'text-gray-700'}>
                        {match.resultat_jugador1 ?? '-'}
                      </span>
                      <span class="text-gray-400 mx-2">-</span>
                      <span class={winner === 2 ? 'font-bold text-green-600' : 'text-gray-700'}>
                        {match.resultat_jugador2 ?? '-'}
                      </span>
                    </div>
                    {#if winner === 0}
                      <div class="text-xs text-yellow-600 mt-1">Empat</div>
                    {/if}
                  {:else}
                    <span class="text-gray-400 text-sm">-</span>
                  {/if}
                </td>
                <td class="px-3 py-4 text-sm">
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {getStatusColor(status)}">
                    {getStatusText(status)}
                  </span>
                </td>
                <td class="px-3 py-4 text-sm text-gray-500">
                  {#if match.taula_assignada}
                    Billar {match.taula_assignada}
                  {:else}
                    Per assignar
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>

    <!-- Results summary by category -->
    {#if selectedCategory === 'all' && selectedStatus === 'all'}
      <div class="bg-white border border-gray-200 rounded-lg p-6">
        <h4 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
          <span class="mr-2">📊</span>
          Resum per Categories
        </h4>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {#each sortedCategories as category}
            {@const categoryMatches = matches.filter(m => m.categoria_id === category.id)}
            {@const completedMatches = categoryMatches.filter(m => getMatchStatus(m) === 'completed')}
            {@const pendingMatches = categoryMatches.filter(m => getMatchStatus(m) === 'pending')}
            {@const scheduledMatches = categoryMatches.filter(m => getMatchStatus(m) === 'scheduled')}

            {#if categoryMatches.length > 0}
              <div class="bg-gray-50 border border-gray-200 rounded-lg p-4">
                <h5 class="font-medium text-gray-900 mb-3">{category.nom}</h5>

                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Total partides:</span>
                    <span class="font-medium">{categoryMatches.length}</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-green-600">Completades:</span>
                    <span class="font-medium">{completedMatches.length}</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-red-600">Pendents:</span>
                    <span class="font-medium">{pendingMatches.length}</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-blue-600">Programades:</span>
                    <span class="font-medium">{scheduledMatches.length}</span>
                  </div>
                </div>

                <!-- Progress bar -->
                <div class="mt-3">
                  <div class="w-full bg-gray-200 rounded-full h-2">
                    <div
                      class="bg-green-600 h-2 rounded-full transition-all duration-300"
                      style="width: {categoryMatches.length > 0 ? (completedMatches.length / categoryMatches.length) * 100 : 0}%"
                    ></div>
                  </div>
                  <div class="text-xs text-gray-500 mt-1 text-center">
                    {categoryMatches.length > 0 ? Math.round((completedMatches.length / categoryMatches.length) * 100) : 0}% completat
                  </div>
                </div>
              </div>
            {/if}
          {/each}
        </div>
      </div>
    {/if}
  {/if}
</div>