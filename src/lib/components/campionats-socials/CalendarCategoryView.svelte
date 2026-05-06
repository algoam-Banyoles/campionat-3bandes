<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatDate } from '$lib/services/calendarTimelineService';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';

  export let matchesByCategory: Map<string, any[]> = new Map();
  export let totalMatches: number = 0;
  export let categoryNames: Record<string, string> = {};
  export let isAdmin: boolean = false;
  export let swapMode: boolean = false;
  export let selectedMatches: Set<string> = new Set();

  const dispatch = createEventDispatcher<{
    toggleMatch: { matchId: string };
    openResult: { match: any };
    openIncompareixenca: { match: any };
    startEdit: { match: any };
    convertUnprogrammed: { match: any };
  }>();

  function getCategoryName(categoryId: string): string {
    return categoryNames[categoryId] ?? 'Desconeguda';
  }
</script>

<div class="cat-view print-category-hide">
  {#if totalMatches === 0}
    <div class="state-empty">No hi ha partits programats.</div>
  {:else}
    {#each Array.from(matchesByCategory.entries()) as [categoryId, categoryMatches] (categoryId)}
      <article class="cat-section">
        <header class="cat-section-head">
          <div>
            <div class="cat-eyebrow">Categoria</div>
            <h3 class="cat-section-title">{getCategoryName(categoryId)}</h3>
          </div>
          <div class="cat-count tabular-nums">{categoryMatches.length} partits</div>
        </header>

        <div class="cat-table-wrap">
          <table class="cat-table">
            <thead>
              <tr>
                {#if isAdmin && swapMode}
                  <th class="col-narrow print-hide">Sel.</th>
                {/if}
                <th class="col-left">Data</th>
                <th class="col-left">Hora</th>
                <th class="col-left hide-sm">Billar</th>
                <th class="col-left">Enfrontament</th>
                {#if isAdmin}
                  <th class="col-left print-hide">Accions</th>
                {/if}
              </tr>
            </thead>
            <tbody>
              {#each categoryMatches as match (match.id)}
                <tr class:row-selected={swapMode && selectedMatches.has(match.id)}>
                  {#if isAdmin && swapMode}
                    <td class="col-narrow print-hide">
                      <input
                        type="checkbox"
                        checked={selectedMatches.has(match.id)}
                        on:change={() => dispatch('toggleMatch', { matchId: match.id })}
                        disabled={!match.data_programada || !match.hora_inici}
                      />
                    </td>
                  {/if}
                  <td>
                    <div class="data-cell">
                      <span>{match.data_programada ? formatDate(new Date(match.data_programada)) : 'No programada'}</span>
                      <span class="data-cell-mobile">
                        {match.hora_inici || '—'}
                        {#if match.taula_assignada}· B{match.taula_assignada}{/if}
                      </span>
                    </div>
                  </td>
                  <td class="tabular-nums">{match.hora_inici || '—'}</td>
                  <td class="hide-sm">
                    {#if match.taula_assignada}
                      <span class="billiard-badge">B{match.taula_assignada}</span>
                    {:else}
                      <span class="muted">—</span>
                    {/if}
                  </td>
                  <td>
                    <div class="vs-cell">
                      <span class="player">{formatPlayerName(match.jugador1)}</span>
                      <span class="sep">vs</span>
                      <span class="player">{formatPlayerName(match.jugador2)}</span>
                    </div>
                  </td>
                  {#if isAdmin}
                    <td class="print-hide">
                      <div class="actions-stack">
                        {#if match.estat !== 'jugada' && match.estat !== 'validat'}
                          <button
                            on:click={() => dispatch('openResult', { match })}
                            class="action-link link-green"
                            title="Introduir resultat de la partida"
                          >
                            Resultat
                          </button>
                          <button
                            on:click={() => dispatch('openIncompareixenca', { match })}
                            class="action-link link-red"
                            title="Marcar incompareixença"
                          >
                            Incompareixença
                          </button>
                        {/if}
                        <button
                          on:click={() => dispatch('startEdit', { match })}
                          class="action-link link-blue"
                        >
                          Editar
                        </button>
                        {#if match.data_programada}
                          <button
                            on:click={() => dispatch('convertUnprogrammed', { match })}
                            class="action-link link-amber"
                            title="Convertir a no programada"
                          >
                            No programar
                          </button>
                        {/if}
                      </div>
                    </td>
                  {/if}
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </article>
    {/each}
  {/if}
</div>

<style>
  .cat-view {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .state-empty {
    padding: 1.5rem 1.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    font-size: 0.9375rem;
    text-align: center;
  }

  .cat-section {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
  }
  .cat-section-head {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid var(--rule);
  }
  .cat-eyebrow {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--ink-3);
    margin-bottom: 0.3rem;
  }
  .cat-section-title {
    font-weight: 800;
    font-size: 1.25rem;
    letter-spacing: -0.018em;
    margin: 0;
    line-height: 1.15;
  }
  .cat-count {
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--ink-2);
  }

  .cat-table-wrap { overflow-x: auto; }
  .cat-table {
    width: 100%;
    border-collapse: collapse;
  }
  .cat-table th {
    padding: 0.75rem 0.85rem;
    border-bottom: 1px solid var(--rule);
    font-size: 0.625rem;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--ink-3);
    white-space: nowrap;
    background: var(--paper);
  }
  .cat-table th.col-left { text-align: left; }
  .cat-table th.col-narrow { width: 3rem; text-align: center; }
  .cat-table td {
    padding: 0.75rem 0.85rem;
    border-bottom: 1px solid var(--rule);
    font-size: 0.9375rem;
    color: var(--ink);
    vertical-align: middle;
  }
  .cat-table tr:last-child td { border-bottom: none; }
  .cat-table tr:hover { background: var(--paper); }
  .cat-table tr.row-selected { background: rgba(31, 79, 139, 0.08); }
  .col-narrow { text-align: center; }
  .data-cell { display: flex; flex-direction: column; }
  .data-cell-mobile {
    display: none;
    font-size: 0.75rem;
    color: var(--ink-3);
    margin-top: 0.15rem;
  }
  .billiard-badge {
    display: inline-block;
    padding: 0.18rem 0.5rem;
    border: 1px solid var(--rule-strong);
    font-weight: 700;
    color: var(--accent);
    font-size: 0.875rem;
    letter-spacing: -0.012em;
  }
  .muted { color: var(--ink-3); }
  .vs-cell {
    display: flex;
    flex-direction: column;
    line-height: 1.3;
  }
  .vs-cell .player {
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.012em;
  }
  .vs-cell .sep {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin: 0.2rem 0;
  }

  .actions-stack {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    align-items: flex-start;
  }
  .action-link {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.8125rem;
    border-bottom: 1px solid currentColor;
    padding-bottom: 1px;
  }
  .link-green { color: var(--green); }
  .link-red   { color: var(--accent); }
  .link-blue  { color: var(--blue); }
  .link-amber { color: var(--amber); font-size: 0.75rem; }
  .action-link:hover { opacity: 0.8; }

  @media (max-width: 640px) {
    .cat-table th.hide-sm,
    .cat-table td.hide-sm { display: none; }
    .data-cell-mobile { display: inline; }
    .cat-section-head { padding: 0.85rem 1rem; }
    .cat-table th, .cat-table td { padding: 0.6rem 0.5rem; }
  }
</style>
