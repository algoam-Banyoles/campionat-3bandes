<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  const dispatch = createEventDispatcher();

  export let eventId: string;
  export let categories: any[] = [];

  let loading = true;
  let oldMatches: any[] = [];
  let selectedMatches: Set<string> = new Set();
  let error = '';
  let converting = false;

  // Filtres
  let selectedCategoryFilter: string = 'all';
  let searchText: string = '';

  $: if (eventId) {
    loadOldMatches();
  }

  // Filtrar partides segons els criteris seleccionats
  $: filteredMatches = oldMatches.filter(match => {
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

  async function loadOldMatches() {
    try {
      loading = true;
      error = '';

      // Obtenir la data d'avui a les 00:00:00
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayStr = today.toISOString();

      console.log('Looking for matches programmed before:', todayStr);

      // Buscar partides programades en el passat sense resultats
      const { data: matchesData, error: fetchError } = await supabase
        .from('calendari_partides')
        .select('*')
        .eq('event_id', eventId)
        .in('estat', ['generat', 'validat', 'publicat'])
        .lt('data_programada', todayStr)
        .is('caramboles_jugador1', null)
        .is('caramboles_jugador2', null)
        .order('data_programada', { ascending: false });

      if (fetchError) throw fetchError;

      if (!matchesData || matchesData.length === 0) {
        oldMatches = [];
        loading = false;
        return;
      }

      // Fase 5c-S2c-2: socis directes via soci_numero
      const sociNumbers = Array.from(new Set([
        ...matchesData.map((m: any) => m.jugador1_soci_numero),
        ...matchesData.map((m: any) => m.jugador2_soci_numero)
      ].filter((n: any) => typeof n === 'number'))) as number[];

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
      oldMatches = matchesData.map((match: any) => ({
        ...match,
        jugador1: playersMap.get(match.jugador1_soci_numero) || null,
        jugador2: playersMap.get(match.jugador2_soci_numero) || null,
        categoria: categoriesMap.get(match.categoria_id) || null
      }));

    } catch (e: any) {
      console.error('Error loading old matches:', e);
      error = e.message || 'Error carregant partides antigues';
    } finally {
      loading = false;
    }
  }

  function getPlayerName(player: any): string {
    if (!player) return 'Desconegut';
    return formatarNomJugador(`${player.nom ?? ''} ${player.cognoms ?? ''}`.trim());
  }

  function getCategoryName(match: any): string {
    return match.categoria?.nom || 'Sense categoria';
  }

  function formatDate(dateStr: string): string {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleDateString('ca-ES', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      weekday: 'short'
    });
  }

  function toggleMatch(matchId: string) {
    if (selectedMatches.has(matchId)) {
      selectedMatches.delete(matchId);
    } else {
      selectedMatches.add(matchId);
    }
    selectedMatches = selectedMatches;
  }

  function selectAll() {
    selectedMatches = new Set(filteredMatches.map(m => m.id));
  }

  function deselectAll() {
    selectedMatches = new Set();
  }

  async function confirmConversion() {
    if (selectedMatches.size === 0 || converting) return;

    try {
      converting = true;
      error = '';

      console.log('Converting', selectedMatches.size, 'matches to pending...');

      // Convertir les partides a pendent_programar
      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          estat: 'pendent_programar',
          data_programada: null,
          hora_inici: null,
          taula_assignada: null
        })
        .in('id', Array.from(selectedMatches));

      if (updateError) {
        console.error('Update error:', updateError);
        throw new Error(updateError.message || 'Error desconegut en convertir les partides');
      }

      console.log('✅ Matches converted successfully');
      dispatch('matchesConverted', { count: selectedMatches.size });
      dispatch('close');
    } catch (e: any) {
      console.error('Error converting matches:', e);
      error = e.message || 'Error convertint les partides';
      converting = false;
    }
  }

  function close() {
    dispatch('close');
  }
</script>

<div class="modal-root">
  <div class="modal-overlay" on:click={close} role="presentation"></div>
  <div class="modal-card modal-card-lg">
    <div class="modal-head">
      <div>
        <div class="editorial-eyebrow">Partides antigues</div>
        <h3 class="modal-title">Reciclar a "pendent de programar"</h3>
        <div class="modal-sub">Selecciona les partides programades en el passat sense resultat per a tornar-les a la cua de pendents.</div>
      </div>
      <button
        type="button"
        on:click={close}
        class="modal-close"
        title="Tancar"
        aria-label="Tancar modal"
      >×</button>
    </div>

    <div class="modal-body">
      {#if loading}
        <div class="state-empty">Carregant partides antigues…</div>
      {:else if error}
        <div class="state-empty error-state">{error}</div>
      {:else if oldMatches.length === 0}
        <div class="state-empty">
          <div class="state-title">No hi ha partides antigues sense resultats</div>
          <div class="state-sub">Totes les partides programades en el passat tenen resultats o ja estan pendents.</div>
        </div>
      {:else}
        <div class="filters">
          <div class="form-grid form-grid-2">
            <div class="form-field">
              <label for="old-filter-category">Categoria</label>
              <select
                id="old-filter-category"
                bind:value={selectedCategoryFilter}
                class="filter-input"
              >
                <option value="all">Totes les categories</option>
                {#each categories as category}
                  <option value={category.id}>{category.nom}</option>
                {/each}
              </select>
            </div>
            <div class="form-field">
              <label for="old-search-player">Cerca jugador</label>
              <input
                id="old-search-player"
                type="text"
                bind:value={searchText}
                placeholder="Nom del jugador…"
                class="filter-input"
              />
            </div>
          </div>

          <div class="filter-row-meta">
            <span class="filter-meta tabular-nums">
              Mostrant {filteredMatches.length} de {oldMatches.length} partides
            </span>
            <div class="filter-actions">
              <button on:click={selectAll} class="btn-link-action">
                Seleccionar totes ({filteredMatches.length})
              </button>
              <span class="filter-sep">·</span>
              <button on:click={deselectAll} class="btn-link-action btn-link-muted">
                Deseleccionar
              </button>
            </div>
          </div>
        </div>

        {#if filteredMatches.length === 0}
          <div class="state-empty">No hi ha partides que coincideixin amb els filtres.</div>
        {:else}
          <ul class="match-list">
            {#each filteredMatches as match}
              <li>
                <button
                  on:click={() => toggleMatch(match.id)}
                  class="match-item"
                  class:active={selectedMatches.has(match.id)}
                >
                  <div class="match-tags">
                    <span class="tag tag-cat">{getCategoryName(match)}</span>
                    <span class="tag tag-date tabular-nums">{formatDate(match.data_programada)}</span>
                    {#if match.hora_inici}
                      <span class="tag-meta tabular-nums">{match.hora_inici}</span>
                    {/if}
                    {#if match.taula_assignada}
                      <span class="tag-meta">Billar {match.taula_assignada}</span>
                    {/if}
                  </div>
                  <div class="match-vs">
                    <span class="match-player">{getPlayerName(match.jugador1)}</span>
                    <span class="match-sep">vs</span>
                    <span class="match-player">{getPlayerName(match.jugador2)}</span>
                  </div>
                  {#if selectedMatches.has(match.id)}
                    <span class="match-check" aria-hidden="true">✓</span>
                  {/if}
                </button>
              </li>
            {/each}
          </ul>
        {/if}
      {/if}
    </div>

    <div class="modal-actions">
      <div class="actions-meta tabular-nums">
        {#if !loading && oldMatches.length > 0}
          {selectedMatches.size} {selectedMatches.size === 1 ? 'partida seleccionada' : 'partides seleccionades'}
        {/if}
      </div>
      <div class="actions-buttons">
        <button
          on:click={close}
          disabled={converting}
          class="btn-secondary"
        >
          Cancel·lar
        </button>
        <button
          on:click={confirmConversion}
          disabled={selectedMatches.size === 0 || converting}
          class="btn-primary"
        >
          {converting ? 'Convertint…' : `Convertir a pendent (${selectedMatches.size})`}
        </button>
      </div>
    </div>
  </div>
</div>

<style>
  .modal-root { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 1rem; }
  .modal-overlay { position: absolute; inset: 0; background: rgba(26, 24, 20, 0.55); }
  .modal-card {
    position: relative; z-index: 10; max-width: 28rem; width: 100%;
    background: var(--paper-elevated); border: 1px solid var(--rule);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.18);
    max-height: 90vh; overflow-y: hidden;
    font-family: var(--font-sans); color: var(--ink);
    display: flex; flex-direction: column;
  }
  .modal-card-lg { max-width: 48rem; }
  .modal-head {
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
    display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem;
  }
  .editorial-eyebrow {
    font-size: 0.6875rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.16em;
    color: var(--ink-3);
  }
  .modal-title {
    font-weight: 800; font-size: 1.0625rem;
    letter-spacing: -0.018em; margin: 0.25rem 0 0;
  }
  .modal-sub {
    margin-top: 0.4rem;
    font-size: 0.8125rem;
    color: var(--ink-2);
  }
  .modal-close {
    background: transparent; border: none; color: var(--ink-3);
    font-size: 1.5rem; width: 2rem; height: 2rem; cursor: pointer;
  }
  .modal-close:hover { color: var(--ink); }

  .modal-body {
    padding: 1.25rem 1.5rem;
    display: flex; flex-direction: column; gap: 1rem;
    flex: 1; overflow-y: auto;
  }

  .state-empty {
    padding: 1.5rem; background: var(--paper); border: 1px solid var(--rule);
    text-align: center; color: var(--ink-2);
  }
  .state-empty.error-state { color: var(--accent); border-color: var(--accent); }
  .state-title { font-weight: 700; font-size: 1.0625rem; color: var(--ink); }
  .state-sub { margin-top: 0.4rem; font-size: 0.875rem; color: var(--ink-3); }

  .filters {
    background: var(--paper);
    border: 1px solid var(--rule);
    padding: 1rem;
    display: flex; flex-direction: column; gap: 0.85rem;
  }
  .form-grid { display: grid; gap: 0.85rem; }
  .form-grid-2 { grid-template-columns: 1fr 1fr; }
  .form-field { display: flex; flex-direction: column; gap: 0.35rem; }
  .form-field label { font-size: 0.75rem; font-weight: 600; color: var(--ink-2); }
  .filter-input {
    padding: 0.55rem 0.75rem;
    background: var(--paper-elevated); border: 1px solid var(--rule-strong);
    color: var(--ink); font-family: var(--font-sans);
    font-size: 0.9375rem; min-height: 44px;
  }
  .filter-input:focus { outline: 2px solid var(--ink); outline-offset: 1px; border-color: var(--ink); }

  .filter-row-meta {
    display: flex; justify-content: space-between; align-items: center; gap: 1rem;
    flex-wrap: wrap;
  }
  .filter-meta { font-size: 0.8125rem; color: var(--ink-3); }
  .filter-actions { display: flex; gap: 0.5rem; align-items: center; }
  .btn-link-action {
    background: transparent; border: none; padding: 0;
    color: var(--blue); font-family: var(--font-sans);
    font-weight: 600; font-size: 0.8125rem;
    cursor: pointer; border-bottom: 1px solid var(--blue); padding-bottom: 1px;
  }
  .btn-link-action:hover { color: var(--ink); border-color: var(--ink); }
  .btn-link-action.btn-link-muted { color: var(--ink-3); border-color: var(--ink-3); }
  .filter-sep { color: var(--ink-3); }

  .match-list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 0.4rem; }
  .match-item {
    width: 100%;
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 0.5rem;
    text-align: left;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    padding: 0.75rem 0.85rem;
    cursor: pointer;
    font-family: var(--font-sans);
  }
  .match-item:hover { border-color: var(--ink); background: var(--paper); }
  .match-item.active { border-color: var(--ink); background: rgba(0,0,0,0.04); }
  .match-tags {
    grid-column: 1 / -1;
    display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: baseline;
    margin-bottom: 0.4rem;
  }
  .tag {
    font-size: 0.625rem; font-weight: 700;
    text-transform: uppercase; letter-spacing: 0.12em;
    border: 1px solid var(--rule-strong);
    padding: 0.18rem 0.5rem;
  }
  .tag.tag-cat { color: var(--ink-2); }
  .tag.tag-date { color: var(--accent); border-color: var(--accent); }
  .tag-meta {
    font-size: 0.75rem;
    color: var(--ink-2);
    font-weight: 500;
  }
  .match-vs { display: inline-flex; align-items: baseline; gap: 0.5rem; flex-wrap: wrap; }
  .match-player { font-weight: 700; color: var(--ink); letter-spacing: -0.012em; font-size: 0.9375rem; }
  .match-sep {
    font-size: 0.625rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.16em; color: var(--ink-3);
  }
  .match-check {
    grid-column: 2; grid-row: 2;
    font-weight: 800; font-size: 1.25rem; color: var(--ink);
    align-self: end;
  }

  .modal-actions {
    display: flex; justify-content: space-between; align-items: center; gap: 1rem;
    padding: 1rem 1.5rem; border-top: 1px solid var(--rule);
  }
  .actions-meta { font-size: 0.8125rem; color: var(--ink-3); }
  .actions-buttons { display: flex; gap: 0.5rem; }
  .btn-secondary {
    padding: 0.55rem 1rem; background: transparent;
    border: 1px solid var(--rule-strong); color: var(--ink);
    font-family: var(--font-sans); font-weight: 600; font-size: 0.875rem;
    cursor: pointer; min-height: 44px;
  }
  .btn-secondary:hover { border-color: var(--ink); }
  .btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary {
    padding: 0.55rem 1rem; background: var(--ink); border: 1px solid var(--ink);
    color: var(--paper); font-family: var(--font-sans);
    font-weight: 600; font-size: 0.875rem; cursor: pointer; min-height: 44px;
  }
  .btn-primary:hover { opacity: 0.92; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  @media (max-width: 640px) {
    .form-grid-2 { grid-template-columns: 1fr; }
    .filter-row-meta { flex-direction: column; align-items: flex-start; }
    .modal-actions { flex-direction: column; align-items: stretch; }
    .actions-buttons { justify-content: flex-end; }
  }
</style>
