<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';
  import { formatDate } from '$lib/services/calendarTimelineService';

  export let matches: any[] = [];
  export let allUnplayedMatches: any[] = [];
  export let isAdmin: boolean = false;
  export let categoryNames: Record<string, string> = {};
  export let estatOptions: Array<{ value: string; label: string }> = [];

  let showAllUnplayed = false;

  const dispatch = createEventDispatcher<{
    program: { match: any };
    openResult: { match: any };
  }>();

  function getCategoryName(categoryId: string): string {
    return categoryNames[categoryId] ?? 'Desconeguda';
  }

  function getEstatLabel(estat: string): string {
    return estatOptions.find(opt => opt.value === estat)?.label ?? 'Pendent programar';
  }

  function formatScheduleCell(match: any): string {
    if (!match.data_programada) return '—';
    const dateLabel = formatDate(new Date(match.data_programada));
    const hora = match.hora_inici ? match.hora_inici.substring(0, 5) : '—';
    const billar = match.taula_assignada ? `B${match.taula_assignada}` : '—';
    return `${dateLabel} · ${hora} · ${billar}`;
  }

  $: extraUnplayed = allUnplayedMatches.filter(
    m => !matches.some(u => u.id === m.id)
  );
  $: hasExtraUnplayed = isAdmin && extraUnplayed.length > 0;
  $: visibleMatches = showAllUnplayed
    ? [...matches, ...extraUnplayed]
    : matches;
</script>

{#if matches.length > 0 || hasExtraUnplayed}
  <section class="unprog">
    <header class="unprog-head">
      <div>
        <div class="unprog-eyebrow">A programar</div>
        <h3 class="unprog-title">
          Partides pendents
          <span class="unprog-count tabular-nums">({visibleMatches.length})</span>
        </h3>
      </div>
      {#if hasExtraUnplayed}
        <label class="unprog-toggle">
          <input type="checkbox" bind:checked={showAllUnplayed} />
          <span>Mostra totes les pendents (+{extraUnplayed.length})</span>
        </label>
      {/if}
    </header>

    <p class="unprog-note">
      Aquestes partides no s'han pogut programar automàticament dins el període establert del campionat.
      Caldrà programar-les manualment o ampliar el període.
      {#if showAllUnplayed && extraUnplayed.length > 0}
        <br />
        <strong>Vista ampliada:</strong> també es mostren les partides programades però encara no jugades,
        per si alguna està mal programada i cal corregir-la.
      {/if}
    </p>

    <div class="unprog-table-wrap">
      <table class="unprog-table">
        <thead>
          <tr>
            <th class="col-left">Categoria</th>
            <th class="col-left">Jugador 1</th>
            <th class="col-left">Jugador 2</th>
            {#if showAllUnplayed}
              <th class="col-left">Programació</th>
            {/if}
            <th class="col-left">Estat</th>
            {#if isAdmin}
              <th class="col-left">Accions</th>
            {/if}
          </tr>
        </thead>
        <tbody>
          {#each visibleMatches as match (match.id)}
            <tr>
              <td>{match.categoria_nom || getCategoryName(match.categoria_id)}</td>
              <td><span class="player-cell">{formatPlayerName(match.jugador1)}</span></td>
              <td><span class="player-cell">{formatPlayerName(match.jugador2)}</span></td>
              {#if showAllUnplayed}
                <td class="tabular-nums">{formatScheduleCell(match)}</td>
              {/if}
              <td><span class="estat-badge">{getEstatLabel(match.estat)}</span></td>
              {#if isAdmin}
                <td>
                  <div class="action-row">
                    <button
                      on:click={() => dispatch('openResult', { match })}
                      class="result-btn"
                    >
                      Resultat
                    </button>
                    <button
                      on:click={() => dispatch('program', { match })}
                      class="program-btn"
                    >
                      Programar →
                    </button>
                  </div>
                </td>
              {/if}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </section>
{/if}

<style>
  .unprog {
    margin-top: 1.5rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    border-top: 3px solid var(--amber);
    padding: 1.5rem 1.75rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .unprog-head {
    margin-bottom: 0.75rem;
    display: flex;
    flex-wrap: wrap;
    gap: 0.85rem 1.25rem;
    align-items: flex-end;
    justify-content: space-between;
  }
  .unprog-toggle {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--ink-2);
    cursor: pointer;
    user-select: none;
  }
  .unprog-toggle input { width: 1rem; height: 1rem; cursor: pointer; }
  .unprog-eyebrow {
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--amber);
    margin-bottom: 0.4rem;
  }
  .unprog-title {
    font-weight: 800;
    font-size: 1.375rem;
    letter-spacing: -0.022em;
    margin: 0;
    line-height: 1.15;
  }
  .unprog-count {
    color: var(--ink-3);
    font-weight: 500;
    font-size: 1rem;
  }
  .unprog-note {
    margin: 0.25rem 0 1rem;
    font-size: 0.8125rem;
    color: var(--ink-2);
    line-height: 1.55;
  }
  .unprog-table-wrap { overflow-x: auto; }
  .unprog-table {
    width: 100%;
    border-collapse: collapse;
  }
  .unprog-table th {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    padding: 0.75rem 0.5rem;
    border-bottom: 1px solid var(--rule);
    white-space: nowrap;
    text-align: left;
  }
  .unprog-table td {
    padding: 0.75rem 0.5rem;
    border-bottom: 1px solid var(--rule);
    font-size: 0.9375rem;
    color: var(--ink-2);
  }
  .unprog-table tr:last-child td { border-bottom: none; }
  .unprog-table tr:hover { background: var(--paper); }
  .player-cell { font-weight: 700; color: var(--ink); }
  .estat-badge {
    display: inline-flex;
    align-items: center;
    padding: 0.18rem 0.5rem;
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--amber);
    border: 1px solid var(--amber);
  }
  .action-row {
    display: flex;
    gap: 0.85rem;
    align-items: center;
    flex-wrap: wrap;
  }
  .program-btn,
  .result-btn {
    background: transparent;
    border: none;
    padding: 0 0 1px 0;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
  }
  .program-btn {
    color: var(--blue);
    border-bottom: 1px solid var(--blue);
  }
  .program-btn:hover { color: var(--ink); border-color: var(--ink); }
  .result-btn {
    color: var(--green);
    border-bottom: 1px solid var(--green);
  }
  .result-btn:hover { color: var(--ink); border-color: var(--ink); }
</style>
