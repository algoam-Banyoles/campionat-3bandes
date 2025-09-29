<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { searchPlayerInClassifications, searchActivePlayers } from '$lib/api/socialLeagues';
  import { debounce } from 'lodash-es';

  export let searchType: 'active_players' | 'classifications' = 'active_players';
  export let title: string = 'Cercar Jugador';
  export let description: string = 'Busca jugadors en el sistema';
  export let placeholder: string = 'Escriu el nom...';
  export let allowSelection: boolean = true;

  const dispatch = createEventDispatcher();

  let searchTerm = '';
  let searchResults: any[] = [];
  let loading = false;
  let error: string | null = null;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const debouncedSearch = debounce(async (term: string) => {
    if (term.length < 3) {
      searchResults = [];
      return;
    }

    loading = true;
    error = null;

    try {
      if (searchType === 'classifications') {
        searchResults = await searchPlayerInClassifications(term);
      } else {
        searchResults = await searchActivePlayers(term);
      }
    } catch (e) {
      error = searchType === 'classifications' ? 'Error buscant jugadors' : 'Error buscant socis';
      console.error(e);
    } finally {
      loading = false;
    }
  }, 300);

  $: debouncedSearch(searchTerm);

  function selectPlayer(player: any) {
    if (allowSelection) {
      dispatch('playerSelected', player);
      clearSearch();
    }
  }

  function clearSearch() {
    searchTerm = '';
    searchResults = [];
    error = null;
  }

  function handleResultClick(result: any) {
    if (searchType === 'classifications') {
      // Per classifications, no hi ha selecció directa
      return;
    } else {
      selectPlayer(result);
    }
  }
</script>

<div class="bg-white border border-gray-200 rounded-lg">
  <div class="px-6 py-4 border-b border-gray-200">
    <h3 class="text-lg font-semibold text-gray-900">{title}</h3>
    <p class="text-sm text-gray-600 mt-1">{description}</p>
  </div>

  <div class="p-6">
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
        {placeholder}
        class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
      />
      {#if searchTerm}
        <button
          on:click={clearSearch}
          class="absolute inset-y-0 right-0 pr-3 flex items-center"
          aria-label="Neteja cerca"
        >
          <svg class="h-5 w-5 text-gray-400 hover:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      {/if}
    </div>

    <!-- Loading -->
    {#if loading}
      <div class="mt-4 flex items-center justify-center py-4">
        <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
        <span class="ml-2 text-sm text-gray-600">Cercant...</span>
      </div>
    {/if}

    <!-- Error -->
    {#if error}
      <div class="mt-4 bg-red-50 border border-red-200 rounded-md p-4">
        <p class="text-sm text-red-600">{error}</p>
      </div>
    {/if}

    <!-- Results -->
    {#if searchResults.length > 0}
      <div class="mt-6 space-y-{searchType === 'classifications' ? '6' : '2'}">
        {#each searchResults as result}
          {#if searchType === 'classifications'}
            <!-- Classification results -->
            <div class="border border-gray-200 rounded-lg p-4">
              <h4 class="font-medium text-gray-900 mb-3">
                {result.player.nom} {result.player.cognom || ''}
              </h4>

              <div class="space-y-2">
                {#each result.classifications as classification}
                  <div class="flex items-center justify-between py-2 px-3 bg-gray-50 rounded">
                    <div class="flex items-center space-x-3">
                      <span class="font-medium text-blue-600">#{classification.posicio}</span>
                      <span class="text-sm font-medium text-gray-900">
                        {modalityNames[classification.modalitat]} {classification.temporada}
                      </span>
                      <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                        {classification.categoria}
                      </span>
                    </div>
                    <div class="text-right">
                      <div class="text-sm font-medium text-gray-900">{classification.punts} punts</div>
                      <div class="text-xs text-gray-500">{classification.partides_jugades} partides</div>
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          {:else}
            <!-- Active players results -->
            <button
              on:click={() => handleResultClick(result)}
              class="w-full text-left border border-gray-200 rounded-lg p-4 hover:bg-blue-50 hover:border-blue-300 transition-colors"
              class:cursor-default={!allowSelection}
              class:hover:bg-blue-50={allowSelection}
              class:hover:border-blue-300={allowSelection}
            >
              <div class="flex items-center justify-between">
                <div>
                  <h4 class="font-medium text-gray-900">
                    {result.nom} {result.cognoms}
                  </h4>
                  <p class="text-sm text-gray-600">
                    Soci #{result.numero_soci}
                    {#if result.email}
                      • {result.email}
                    {/if}
                  </p>
                </div>
                <div class="text-right">
                  {#if result.historicalAverage !== null}
                    <div class="text-sm font-medium text-blue-600">
                      Mitjana: {result.historicalAverage.toFixed(2)}
                    </div>
                    <div class="text-xs text-gray-500">Millor 2 temporades</div>
                  {:else}
                    <div class="text-sm text-gray-500">Sense mitjana històrica</div>
                  {/if}
                </div>
              </div>
            </button>
          {/if}
        {/each}
      </div>
    {:else if searchTerm.length >= 3 && !loading}
      <div class="mt-4 text-center py-4">
        <p class="text-sm text-gray-500">
          No s'han trobat {searchType === 'classifications' ? 'jugadors' : 'socis'} amb "{searchTerm}"
        </p>
      </div>
    {:else if searchTerm.length > 0 && searchTerm.length < 3}
      <div class="mt-4 text-center py-4">
        <p class="text-sm text-gray-500">Escriu almenys 3 caràcters per cercar</p>
      </div>
    {/if}
  </div>
</div>