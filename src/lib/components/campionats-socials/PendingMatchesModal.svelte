<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  const dispatch = createEventDispatcher();

  export let eventId: string;
  export let slot: any;
  export let categories: any[] = [];

  let loading = true;
  let pendingMatches: any[] = [];
  let selectedMatch: any = null;
  let error = '';

  // Filtres
  let selectedCategoryFilter: string = 'all';
  let searchText: string = '';

  $: if (eventId) {
    loadPendingMatches();
  }

  // Filtrar partides segons els criteris seleccionats
  $: filteredMatches = pendingMatches.filter(match => {
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

  async function loadPendingMatches() {
    try {
      loading = true;
      error = '';
      const withdrawnSocis = new Set<number>();

      const { data: inscriptionsData, error: inscriptionsError } = await supabase
        .rpc('get_inscripcions_with_socis', {
          p_event_id: eventId
        });

      if (!inscriptionsError) {
        (inscriptionsData || [])
          .filter((item: any) => item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences)
          .forEach((item: any) => {
            if (typeof item.soci_numero === 'number') {
              withdrawnSocis.add(item.soci_numero);
            }
          });
      }

      // Carregar partides pendents de programar
      // Busquem partides amb estat 'generat' o 'pendent_programar' que no tinguin data
      const { data: matchesData, error: fetchError } = await supabase
        .from('calendari_partides')
        .select('*')
        .eq('event_id', eventId)
        .or('estat.eq.generat,estat.eq.pendent_programar')
        .is('data_programada', null)
        .order('categoria_id');

      if (fetchError) throw fetchError;

      if (!matchesData || matchesData.length === 0) {
        pendingMatches = [];
        loading = false;
        return;
      }
      let filteredMatchesData = [...matchesData];

      // Fase 5c-S2c-2: Filtrar i carregar socis directament per soci_numero,
      // sense passar per `players`.
      if (withdrawnSocis.size > 0) {
        filteredMatchesData = filteredMatchesData.filter((match: any) => {
          return !withdrawnSocis.has(match.jugador1_soci_numero ?? -1)
              && !withdrawnSocis.has(match.jugador2_soci_numero ?? -1);
        });
      }

      const sociNumbers = Array.from(new Set([
        ...filteredMatchesData.map((m: any) => m.jugador1_soci_numero),
        ...filteredMatchesData.map((m: any) => m.jugador2_soci_numero)
      ].filter((n: any) => typeof n === 'number'))) as number[];

      // Map per soci_numero (no per player_id UUID)
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
      pendingMatches = filteredMatchesData.map((match: any) => ({
        ...match,
        jugador1: playersMap.get(match.jugador1_soci_numero) || null,
        jugador2: playersMap.get(match.jugador2_soci_numero) || null,
        categoria: categoriesMap.get(match.categoria_id) || null
      }));

      // Ordenar per ordre de categoria (si existeix) o pel nom de categoria
      pendingMatches.sort((a, b) => {
        const categoriaA = a.categoria;
        const categoriaB = b.categoria;

        // Si ambdues categories tenen camp 'ordre_categoria', ordenar per ordre
        if (categoriaA?.ordre_categoria !== undefined && categoriaB?.ordre_categoria !== undefined) {
          return categoriaA.ordre_categoria - categoriaB.ordre_categoria;
        }

        // Si no, ordenar per nom de categoria
        const nomA = categoriaA?.nom || '';
        const nomB = categoriaB?.nom || '';
        return nomA.localeCompare(nomB);
      });

    } catch (e: any) {
      console.error('Error loading pending matches:', e);
      error = e.message || 'Error carregant partides pendents';
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

  function selectMatch(match: any) {
    selectedMatch = match;
  }

  let programming = false;

  async function confirmSelection() {
    if (!selectedMatch || programming) return;

    try {
      programming = true;
      error = '';

      console.log('Programming match:', selectedMatch.id, 'in slot:', slot);

      // Programar la partida en el slot seleccionat
      const updates = {
        data_programada: slot.dateStr + 'T' + slot.hora + ':00',
        hora_inici: slot.hora,
        taula_assignada: slot.taula,
        estat: 'validat'
      };

      console.log('Updating with:', updates);

      const { data: updateData, error: updateError } = await supabase
        .from('calendari_partides')
        .update(updates)
        .eq('id', selectedMatch.id)
        .select();

      if (updateError) {
        console.error('Update error:', updateError);
        console.error('Update error details:', JSON.stringify(updateError, null, 2));
        throw new Error(updateError.message || 'Error desconegut en actualitzar la partida');
      }

      console.log('Update result:', updateData);

      console.log('Match programmed successfully');
      dispatch('matchProgrammed', { matchId: selectedMatch.id });
      dispatch('close');
    } catch (e: any) {
      console.error('Error programming match:', e);
      error = e.message || 'Error programant la partida';
      programming = false;
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
        <div class="editorial-eyebrow">Pendents de programar</div>
        <h3 class="modal-title">Slot: {slot.dateStr} · {slot.hora} · Billar {slot.taula}</h3>
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
        <div class="state-empty">Carregant partides…</div>
      {:else if error}
        <div class="state-empty error-state">{error}</div>
      {:else if pendingMatches.length === 0}
        <div class="state-empty">No hi ha partides pendents de programar.</div>
      {:else}
        <!-- Filtres -->
        <div class="filters">
          <div class="form-grid form-grid-2">
            <div class="form-field">
              <label for="pending-filter-category">Categoria</label>
              <select
                id="pending-filter-category"
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
              <label for="pending-search-player">Cerca jugador</label>
              <input
                id="pending-search-player"
                type="text"
                bind:value={searchText}
                placeholder="Nom del jugador…"
                class="filter-input"
              />
            </div>
          </div>
          <div class="filter-meta tabular-nums">
            Mostrant {filteredMatches.length} de {pendingMatches.length} partides
          </div>
        </div>

        {#if filteredMatches.length === 0}
          <div class="state-empty">No hi ha partides que coincideixin amb els filtres.</div>
        {:else}
          <ul class="match-list">
            {#each filteredMatches as match}
              <li>
                <button
                  on:click={() => selectMatch(match)}
                  class="match-item"
                  class:active={selectedMatch?.id === match.id}
                >
                  <span class="match-cat">{getCategoryName(match)}</span>
                  <span class="match-vs">
                    <span class="match-player">{getPlayerName(match.jugador1)}</span>
                    <span class="match-sep">vs</span>
                    <span class="match-player">{getPlayerName(match.jugador2)}</span>
                  </span>
                  {#if selectedMatch?.id === match.id}
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
        {#if !loading && pendingMatches.length > 0}
          {filteredMatches.length} de {pendingMatches.length} {pendingMatches.length === 1 ? 'partida' : 'partides'}
        {/if}
      </div>
      <div class="actions-buttons">
        <button
          on:click={close}
          disabled={programming}
          class="btn-secondary"
        >
          Cancel·lar
        </button>
        <button
          on:click={confirmSelection}
          disabled={!selectedMatch || programming}
          class="btn-primary"
        >
          {programming ? 'Programant…' : 'Programar partida'}
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
  .modal-card-lg { max-width: 52rem; }
  .modal-head {
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
    display: flex; justify-content: space-between; align-items: center; gap: 1rem;
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
  .filter-meta { font-size: 0.8125rem; color: var(--ink-3); }

  .match-list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 0.4rem; }
  .match-item {
    width: 100%;
    display: grid;
    grid-template-columns: auto 1fr auto;
    gap: 0.75rem;
    align-items: center;
    text-align: left;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    padding: 0.75rem 0.85rem;
    cursor: pointer;
    font-family: var(--font-sans);
  }
  .match-item:hover { border-color: var(--ink); background: var(--paper); }
  .match-item.active { border-color: var(--ink); background: rgba(0,0,0,0.04); }
  .match-cat {
    font-size: 0.625rem; font-weight: 700;
    text-transform: uppercase; letter-spacing: 0.12em;
    border: 1px solid var(--rule-strong);
    padding: 0.18rem 0.5rem;
    color: var(--ink-2);
  }
  .match-vs { display: inline-flex; align-items: baseline; gap: 0.5rem; flex-wrap: wrap; }
  .match-player { font-weight: 700; color: var(--ink); letter-spacing: -0.012em; font-size: 0.9375rem; }
  .match-sep {
    font-size: 0.625rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.16em; color: var(--ink-3);
  }
  .match-check { font-weight: 800; font-size: 1.25rem; color: var(--ink); }

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
    .modal-actions { flex-direction: column; align-items: stretch; }
    .actions-buttons { justify-content: flex-end; }
  }
</style>
