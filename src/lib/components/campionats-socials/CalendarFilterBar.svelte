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

<div class="filter-bar">
  <!-- Filtres principals -->
  <div class="filter-row">
    <div class="filter-field">
      <label for="category-filter" class="filter-label">Categoria</label>
      <select
        id="category-filter"
        bind:value={selectedCategory}
        class="filter-input"
      >
        <option value="">Totes les categories</option>
        {#each sortedCategories as category (category.id)}
          <option value={category.id}>{category.nom}</option>
        {/each}
      </select>
    </div>

    <div class="filter-field">
      <label for="date-filter" class="filter-label">Data</label>
      <input
        id="date-filter"
        type="date"
        bind:value={selectedDate}
        class="filter-input"
      />
    </div>

    <div class="filter-field player-search-container print-header-hide">
      <label for="player-search" class="filter-label">Jugador</label>
      <div class="player-search-wrap">
        <input
          id="player-search"
          type="text"
          bind:value={playerSearch}
          on:input={() => dispatch('playerInput')}
          placeholder="Nom o cognoms…"
          class="filter-input"
          disabled={showOnlyMyMatches}
        />
        {#if playerSearch}
          <button
            type="button"
            on:click={() => dispatch('clearPlayerSearch')}
            class="player-search-clear"
            title="Netejar cerca"
            aria-label="Netejar cerca"
          >
            ×
          </button>
        {/if}
      </div>

      <!-- Suggeriments de jugadors -->
      {#if playerSuggestions.length > 0}
        <div class="player-suggestions">
          {#each playerSuggestions as suggestion (suggestion.id)}
            <button
              type="button"
              on:click={() => dispatch('selectSuggestion', { suggestion })}
              class="player-suggestion-item"
            >
              {suggestion.displayName}
            </button>
          {/each}
        </div>
      {/if}
    </div>

    <div class="filter-field">
      <div class="filter-label-spacer" aria-hidden="true">&nbsp;</div>
      <button
        type="button"
        on:click={() => dispatch('clearAllFilters')}
        class="filter-btn-clear"
      >
        Netejar filtres
      </button>
    </div>
  </div>

  <!-- Vista + checkbox -->
  <div class="filter-row-secondary">
    <div class="view-toggle" role="group" aria-label="Mode de vista">
      <button
        type="button"
        on:click={() => (viewMode = 'category')}
        class="view-toggle-btn"
        class:active={viewMode === 'category'}
      >
        Per categoria
      </button>
      <button
        type="button"
        on:click={() => (viewMode = 'timeline')}
        class="view-toggle-btn"
        class:active={viewMode === 'timeline'}
      >
        Cronològica
      </button>
    </div>

    {#if hasMyPlayerData}
      <label class="my-matches-toggle">
        <input
          type="checkbox"
          bind:checked={showOnlyMyMatches}
        />
        <span>Només les meves partides</span>
      </label>
    {/if}
  </div>
</div>

<style>
  .filter-bar {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    font-family: var(--font-sans);
  }
  .filter-row {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 1rem;
  }
  .filter-row-secondary {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    flex-wrap: wrap;
    padding-top: 0.5rem;
    border-top: 1px solid var(--rule);
  }

  .filter-field { display: flex; flex-direction: column; }
  .filter-label {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--ink-3);
    margin-bottom: 0.4rem;
  }
  .filter-label-spacer {
    height: 1.1rem;
    margin-bottom: 0.4rem;
  }
  .filter-input {
    width: 100%;
    padding: 0.55rem 0.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    font-family: var(--font-sans);
    font-size: 0.9375rem;
    font-weight: 500;
    min-height: 44px;
  }
  .filter-input:focus {
    outline: 2px solid var(--ink);
    outline-offset: 1px;
    border-color: var(--ink);
  }
  .filter-input:disabled {
    opacity: 0.55;
    cursor: not-allowed;
  }

  .filter-btn-clear {
    width: 100%;
    padding: 0.55rem 0.85rem;
    background: var(--ink);
    color: var(--paper);
    border: 1px solid var(--ink);
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 44px;
  }
  .filter-btn-clear:hover { opacity: 0.92; }

  .player-search-container { position: relative; }
  .player-search-wrap { position: relative; }
  .player-search-clear {
    position: absolute;
    right: 0.5rem;
    top: 50%;
    transform: translateY(-50%);
    background: transparent;
    border: none;
    color: var(--ink-3);
    cursor: pointer;
    font-size: 1.25rem;
    line-height: 1;
    padding: 0.25rem;
    width: 1.75rem;
    height: 1.75rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .player-search-clear:hover { color: var(--ink); }

  .player-suggestions {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    margin-top: 0.25rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
    max-height: 16rem;
    overflow-y: auto;
    z-index: 50;
  }
  .player-suggestion-item {
    display: block;
    width: 100%;
    text-align: left;
    background: transparent;
    border: none;
    border-bottom: 1px solid var(--rule);
    padding: 0.6rem 0.85rem;
    font-family: var(--font-sans);
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--ink);
    cursor: pointer;
  }
  .player-suggestion-item:last-child { border-bottom: none; }
  .player-suggestion-item:hover,
  .player-suggestion-item:focus {
    background: var(--paper);
    outline: none;
  }

  /* Toggle de vista */
  .view-toggle {
    display: inline-flex;
    border: 1px solid var(--rule-strong);
  }
  .view-toggle-btn {
    background: transparent;
    border: none;
    padding: 0.55rem 1rem;
    font-family: var(--font-sans);
    font-weight: 500;
    font-size: 0.875rem;
    color: var(--ink-2);
    cursor: pointer;
    min-height: 44px;
    letter-spacing: -0.005em;
  }
  .view-toggle-btn + .view-toggle-btn { border-left: 1px solid var(--rule-strong); }
  .view-toggle-btn:hover { color: var(--ink); }
  .view-toggle-btn.active {
    background: var(--ink);
    color: var(--paper);
    font-weight: 600;
  }

  .my-matches-toggle {
    display: inline-flex;
    align-items: center;
    gap: 0.55rem;
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--ink-2);
    cursor: pointer;
  }
  .my-matches-toggle input[type='checkbox'] {
    width: 1.1rem;
    height: 1.1rem;
    accent-color: var(--ink);
    cursor: pointer;
  }
  .my-matches-toggle:hover { color: var(--ink); }

  @media (max-width: 768px) {
    .filter-row { grid-template-columns: 1fr 1fr; }
  }
  @media (max-width: 480px) {
    .filter-row { grid-template-columns: 1fr; }
    .filter-row-secondary { flex-direction: column; align-items: flex-start; }
    .view-toggle { width: 100%; }
    .view-toggle-btn { flex: 1; }
  }
</style>
