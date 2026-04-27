<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  // --- Dades per al títol i badges ---
  export let totalMatches: number = 0;
  export let publishedCount: number = 0;
  export let isFilteringByPlayer: boolean = false;
  export let playerSearch: string = '';
  export let filteredMatchesCount: number = 0;
  export let playerMatchSlots: number = 0;

  // --- Estat dels controls admin ---
  export let isAdmin: boolean = false;
  export let canPublish: boolean = false;
  export let publishing: boolean = false;
  export let loading: boolean = false;
  export let swapMode: boolean = false;
  export let selectedMatchesCount: number = 0;

  const dispatch = createEventDispatcher<{
    publish: void;
    convertOldMatches: void;
    toggleSwapMode: void;
    confirmSwap: void;
    exportCSV: void;
    print: void;
  }>();
</script>

<div class="flex items-center justify-between mb-4">
  <div>
    <h3 class="text-lg font-medium text-gray-900">Calendari de Partits</h3>
    {#if totalMatches > 0}
      <div class="mt-1 text-sm text-gray-600">
        {#if publishedCount > 0}
          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-emerald-100 text-emerald-800 mr-2">
            📢 {publishedCount} publicats
          </span>
        {/if}

        {#if isFilteringByPlayer}
          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
            🔍 Filtrant per: {playerSearch} | Partits trobats: {filteredMatchesCount}/{totalMatches} | Slots amb partits: {playerMatchSlots}
          </span>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Botons d'acció admin -->
  <div class="flex flex-wrap items-center gap-3">
    {#if isAdmin && canPublish}
      <button
        type="button"
        on:click={() => dispatch('publish')}
        class="no-print px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 flex items-center gap-2 font-medium disabled:opacity-50"
        title="Publicar calendari al calendari general de la PWA"
        disabled={loading || publishing}
      >
        {#if publishing}
          <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
          Publicant...
        {:else}
          📢 Publicar
        {/if}
      </button>
    {/if}

    {#if isAdmin}
      <button
        type="button"
        on:click={() => dispatch('convertOldMatches')}
        class="no-print px-4 py-2 bg-purple-600 text-white text-sm rounded hover:bg-purple-700 flex items-center gap-2 font-medium disabled:opacity-50"
        title="Convertir partides antigues sense resultats a pendent de programar"
        disabled={loading}
      >
        🔄 Reciclar Antigues
      </button>
    {/if}

    {#if isAdmin}
      <div class="flex items-center gap-2">
        <button
          type="button"
          on:click={() => dispatch('toggleSwapMode')}
          class="no-print px-4 py-2 text-sm rounded font-medium flex items-center justify-center gap-2"
          class:bg-orange-600={swapMode}
          class:text-white={swapMode}
          class:hover:bg-orange-700={swapMode}
          class:bg-orange-100={!swapMode}
          class:text-orange-800={!swapMode}
          class:hover:bg-orange-200={!swapMode}
          title="Activar/desactivar mode d'intercanvi de partides"
        >
          🔄 <span class="hidden sm:inline">{swapMode ? 'Cancel·lar' : 'Intercanviar'}</span>
        </button>

        {#if swapMode && selectedMatchesCount === 2}
          <button
            type="button"
            on:click={() => dispatch('confirmSwap')}
            class="no-print px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 font-medium flex items-center justify-center gap-1"
            title="Confirmar intercanvi de les partides seleccionades"
          >
            ✅ <span class="hidden sm:inline">Confirmar</span>
          </button>
        {/if}

        {#if swapMode}
          <span class="text-sm text-gray-600 font-medium">
            {selectedMatchesCount}/2
          </span>
        {/if}
      </div>
    {/if}

    {#if isAdmin}
      <button
        type="button"
        on:click={() => dispatch('exportCSV')}
        class="no-print px-4 py-2 bg-purple-600 text-white text-sm rounded hover:bg-purple-700 items-center gap-2 font-medium flex"
        title="Exportar calendari a CSV"
      >
        📄 Exportar
      </button>
    {/if}

    <button
      type="button"
      on:click={() => dispatch('print')}
      class="no-print hidden md:flex px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 items-center gap-2 font-medium"
      title="Imprimir calendari cronològic"
    >
      🖨️ Imprimir
    </button>
  </div>
</div>
