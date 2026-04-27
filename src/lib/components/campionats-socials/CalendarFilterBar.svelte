<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { PlayerSuggestion } from '$lib/services/calendarPlayerSearchService';

  // --- Filtres bidireccionals (parent fa `bind:`) ---
  export let selectedCategory: string = '';
  export let selectedDate: string = '';
  export let playerSearch: string = '';
  export let viewMode: 'category' | 'timeline' = 'timeline';
  export let showOnlyMyMatches: boolean = false;

  // --- Dades a renderitzar ---
  export let categories: any[] = [];
  export let playerSuggestions: PlayerSuggestion[] = [];
  export let hasMyPlayerData: boolean = false;

  const dispatch = createEventDispatcher<{
    selectSuggestion: { suggestion: PlayerSuggestion };
    clearPlayerSearch: void;
    clearAllFilters: void;
    /** Es dispara quan canvia el text per a netejar `selectedPlayerId` al pare. */
    playerInput: void;
  }>();

  $: sortedCategories = [...categories].sort(
    (a, b) => (a.ordre_categoria ?? 0) - (b.ordre_categoria ?? 0)
  );
</script>

<!-- Filtres - Primera fila -->
<div class="grid grid-cols-1 md:grid-cols-4 gap-4">
  <div>
    <label for="category-filter" class="block text-sm font-medium text-gray-700 mb-2">Categoria</label>
    <select
      id="category-filter"
      bind:value={selectedCategory}
      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
    >
      <option value="">Totes les categories</option>
      {#each sortedCategories as category (category.id)}
        <option value={category.id}>{category.nom}</option>
      {/each}
    </select>
  </div>

  <div>
    <label for="date-filter" class="block text-sm font-medium text-gray-700 mb-2">Data</label>
    <input
      id="date-filter"
      type="date"
      bind:value={selectedDate}
      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
    />
  </div>

  <div class="relative print-header-hide player-search-container">
    <label for="player-search" class="block text-sm font-medium text-gray-700 mb-2">Jugador</label>
    <div class="relative">
      <input
        id="player-search"
        type="text"
        bind:value={playerSearch}
        on:input={() => dispatch('playerInput')}
        placeholder="Escriu nom o cognoms..."
        class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 pr-8"
        disabled={showOnlyMyMatches}
      />
      {#if playerSearch}
        <button
          type="button"
          on:click={() => dispatch('clearPlayerSearch')}
          class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
          title="Netejar cerca"
        >
          ✕
        </button>
      {/if}
    </div>

    <!-- Suggeriments de jugadors -->
    {#if playerSuggestions.length > 0}
      <div class="absolute top-full left-0 right-0 z-50 bg-white border border-gray-300 rounded-md shadow-lg max-h-64 overflow-y-auto mt-1">
        {#each playerSuggestions as suggestion (suggestion.id)}
          <button
            type="button"
            on:click={() => dispatch('selectSuggestion', { suggestion })}
            class="w-full px-3 py-2 text-left hover:bg-gray-50 border-b border-gray-100 last:border-b-0 focus:outline-none focus:bg-gray-50"
          >
            <div class="text-sm font-medium text-gray-900">
              {suggestion.displayName}
            </div>
          </button>
        {/each}
      </div>
    {/if}
  </div>

  <div>
    <div class="block text-sm font-medium text-gray-700 mb-2 invisible" aria-hidden="true">Accions</div>
    <button
      type="button"
      on:click={() => dispatch('clearAllFilters')}
      class="w-full px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700 font-medium"
    >
      Netejar Filtres
    </button>
  </div>
</div>

<!-- Filtres - Segona fila: Selector de vista i checkbox -->
<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-2">
  <div class="flex items-end">
    <div class="flex bg-gray-100 rounded-lg p-1">
      <button
        type="button"
        on:click={() => (viewMode = 'category')}
        class="px-3 py-1.5 rounded text-sm transition-colors font-medium"
        class:bg-white={viewMode === 'category'}
        class:shadow-sm={viewMode === 'category'}
        class:text-gray-900={viewMode === 'category'}
        class:text-gray-600={viewMode !== 'category'}
      >
        📋 Per Categoria
      </button>
      <button
        type="button"
        on:click={() => (viewMode = 'timeline')}
        class="px-3 py-1.5 rounded text-sm transition-colors font-medium"
        class:bg-white={viewMode === 'timeline'}
        class:shadow-sm={viewMode === 'timeline'}
        class:text-gray-900={viewMode === 'timeline'}
        class:text-gray-600={viewMode !== 'timeline'}
      >
        📅 Cronològica
      </button>
    </div>
  </div>

  <div></div>

  <div class="flex items-start">
    {#if hasMyPlayerData}
      <label class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
        <input
          type="checkbox"
          bind:checked={showOnlyMyMatches}
          class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
        />
        <span class="font-medium">🎯 Les meves partides</span>
      </label>
    {/if}
  </div>

  <div></div>
</div>
