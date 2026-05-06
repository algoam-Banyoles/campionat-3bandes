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

<div class="ctrl-bar">
  <div class="ctrl-title-block">
    <div class="ctrl-eyebrow">Calendari de partits</div>
    {#if totalMatches > 0}
      <div class="ctrl-meta">
        {#if publishedCount > 0}
          <span class="ctrl-badge published">{publishedCount} publicats</span>
        {/if}

        {#if isFilteringByPlayer}
          <span class="ctrl-badge filter">
            Filtre <strong>{playerSearch}</strong> · {filteredMatchesCount}/{totalMatches} partits · {playerMatchSlots} slots
          </span>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Botons d'acció admin -->
  <div class="ctrl-actions">
    {#if isAdmin && canPublish}
      <button
        type="button"
        on:click={() => dispatch('publish')}
        class="btn-action btn-publish no-print"
        title="Publicar calendari al calendari general de la PWA"
        disabled={loading || publishing}
      >
        {publishing ? 'Publicant…' : 'Publicar'}
      </button>
    {/if}

    {#if isAdmin}
      <button
        type="button"
        on:click={() => dispatch('convertOldMatches')}
        class="btn-action no-print"
        title="Convertir partides antigues sense resultats a pendent de programar"
        disabled={loading}
      >
        Reciclar antigues
      </button>
    {/if}

    {#if isAdmin}
      <div class="swap-group">
        <button
          type="button"
          on:click={() => dispatch('toggleSwapMode')}
          class="btn-action btn-swap no-print"
          class:active={swapMode}
          title="Activar/desactivar mode d'intercanvi de partides"
        >
          {swapMode ? 'Cancel·lar' : 'Intercanviar'}
        </button>

        {#if swapMode && selectedMatchesCount === 2}
          <button
            type="button"
            on:click={() => dispatch('confirmSwap')}
            class="btn-action btn-confirm no-print"
            title="Confirmar intercanvi de les partides seleccionades"
          >
            Confirmar
          </button>
        {/if}

        {#if swapMode}
          <span class="swap-count tabular-nums">{selectedMatchesCount}/2</span>
        {/if}
      </div>
    {/if}

    {#if isAdmin}
      <button
        type="button"
        on:click={() => dispatch('exportCSV')}
        class="btn-action no-print"
        title="Exportar calendari a CSV"
      >
        Exportar CSV
      </button>
    {/if}

    <button
      type="button"
      on:click={() => dispatch('print')}
      class="btn-action btn-print no-print"
      title="Imprimir calendari cronològic"
    >
      Imprimir
    </button>
  </div>
</div>

<style>
  .ctrl-bar {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
    margin-bottom: 1rem;
    flex-wrap: wrap;
    font-family: var(--font-sans);
  }
  .ctrl-title-block { flex: 1; min-width: 0; }
  .ctrl-eyebrow {
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .ctrl-meta {
    margin-top: 0.5rem;
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }
  .ctrl-badge {
    display: inline-flex;
    align-items: center;
    padding: 0.2rem 0.5rem;
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    border: 1px solid var(--rule-strong);
    color: var(--ink-2);
    background: var(--paper);
  }
  .ctrl-badge.published {
    border-color: var(--green);
    color: var(--green);
  }
  .ctrl-badge.filter strong { color: var(--ink); font-weight: 700; }

  .ctrl-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.5rem;
  }
  .btn-action {
    background: var(--paper-elevated);
    color: var(--ink);
    border: 1px solid var(--rule-strong);
    padding: 0.5rem 0.85rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.8125rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 40px;
  }
  .btn-action:hover { border-color: var(--ink); }
  .btn-action:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-action.btn-publish {
    background: var(--green);
    color: white;
    border-color: var(--green);
  }
  .btn-action.btn-publish:hover { opacity: 0.92; }
  .btn-action.btn-swap.active {
    background: var(--accent);
    color: white;
    border-color: var(--accent);
  }
  .btn-action.btn-confirm {
    background: var(--ink);
    color: var(--paper);
    border-color: var(--ink);
  }
  .btn-action.btn-print {
    display: none;
  }
  @media (min-width: 768px) {
    .btn-action.btn-print { display: inline-flex; }
  }
  .swap-group {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .swap-count {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink-2);
    padding: 0 0.4rem;
  }
</style>
