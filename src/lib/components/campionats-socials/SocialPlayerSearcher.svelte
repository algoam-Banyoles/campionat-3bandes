<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { searchActivePlayers } from '$lib/api/socialLeagues';
  import { debounce } from 'lodash-es';

  const dispatch = createEventDispatcher();

  let searchTerm = '';
  let searchResults: any[] = [];
  let loading = false;
  let error: string | null = null;

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

  function selectPlayer(player: any) {
    dispatch('playerSelected', player);
    clearSearch();
  }

  function clearSearch() {
    searchTerm = '';
    searchResults = [];
    error = null;
  }
</script>

<div class="bg-white border border-gray-200 rounded-lg">
  <div class="px-6 py-4 border-b border-gray-200">
    <h3 class="text-lg font-semibold text-gray-900">Cercar Soci</h3>
    <p class="text-sm text-gray-600 mt-1">Busca socis actius per inscriure a competicions socials</p>
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
        placeholder="Escriu el nom del soci..."
        class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
      />
      {#if searchTerm}
        <button
          on:click={clearSearch}
          class="absolute inset-y-0 right-0 pr-3 flex items-center"
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
      <div class="mt-6 space-y-2">
        {#each searchResults as player}
          <button
            on:click={() => selectPlayer(player)}
            class="w-full text-left border border-gray-200 rounded-lg p-4 hover:bg-blue-50 hover:border-blue-300 transition-colors"
          >
            <div class="flex items-center justify-between">
              <div>
                <h4 class="font-medium text-gray-900">
                  {player.nom} {player.cognoms}
                </h4>
                <p class="text-sm text-gray-600">
                  Soci #{player.numero_soci}
                  {#if player.email}
                    • {player.email}
                  {/if}
                </p>
              </div>
              <div class="text-right">
                {#if player.historicalAverage !== null}
                  <div class="text-sm font-medium text-blue-600">
                    Mitjana: {player.historicalAverage.toFixed(2)}
                  </div>
                  <div class="text-xs text-gray-500">Millor 2 temporades</div>
                {:else}
                  <div class="text-sm text-gray-500">Sense mitjana històrica</div>
                {/if}
              </div>
            </div>
          </button>
        {/each}
      </div>
    {:else if searchTerm.length >= 3 && !loading}
      <div class="mt-4 text-center py-4">
        <p class="text-sm text-gray-500">No s'han trobat socis amb "{searchTerm}"</p>
      </div>
    {:else if searchTerm.length > 0 && searchTerm.length < 3}
      <div class="mt-4 text-center py-4">
        <p class="text-sm text-gray-500">Escriu almenys 3 caràcters per cercar</p>
      </div>
    {/if}
  </div>
</div>