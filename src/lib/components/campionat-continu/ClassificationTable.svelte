<script lang="ts">
  import type { Classification } from '$lib/types';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  export let classifications: Classification[] = [];
  export let title: string = 'Classificació';
  export let showStats: boolean = true;

  function formatAverage(avg: number | null): string {
    if (avg === null || avg === undefined) return '—';
    return avg.toFixed(3);
  }

  $: hasEmpat = classifications.some(c => c.partides_empat > 0);
</script>

<section class="cls-block">
  <header class="cls-head">
    <div>
      <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Classificació</div>
      <h3 class="cls-title">{title}</h3>
    </div>
    {#if classifications.length > 0}
      <div class="cls-count tabular-nums">{classifications.length} jugadors</div>
    {/if}
  </header>

  {#if classifications.length === 0}
    <div class="state-empty">No hi ha classificacions disponibles.</div>
  {:else}
    <div class="cls-table-wrap">
      <table class="cls-table">
        <thead>
          <tr>
            <th class="col-pos">Pos</th>
            <th class="col-left">Jugador</th>
            <th class="col-num hide-sm">PJ</th>
            <th class="col-num hide-sm">PG</th>
            <th class="col-num hide-sm">PP</th>
            {#if hasEmpat}
              <th class="col-num hide-sm">PE</th>
            {/if}
            <th class="col-num col-pts">Punts</th>
            {#if showStats}
              <th class="col-num hide-md">CF</th>
              <th class="col-num hide-md">CC</th>
              <th class="col-num hide-lg">Mitjana</th>
            {/if}
          </tr>
        </thead>
        <tbody>
          {#each classifications as classification}
            <tr class:top1={classification.posicio === 1}
                class:top2={classification.posicio === 2}
                class:top3={classification.posicio === 3}>
              <td class="col-pos">
                <span class="pos-num tabular-nums">{classification.posicio.toString().padStart(2, '0')}</span>
              </td>
              <td class="col-left">
                <div class="player-name">
                  {formatarNomJugador(`${classification.player_nom ?? ''} ${classification.player_cognom ?? ''}`.trim())}
                </div>
                <div class="player-stats-mobile">
                  <span class="tabular-nums">{classification.partides_jugades}</span> PJ ·
                  <span class="tabular-nums">{classification.partides_guanyades}</span> PG ·
                  <span class="tabular-nums">{classification.partides_perdudes}</span> PP
                  {#if classification.partides_empat > 0}
                    · <span class="tabular-nums">{classification.partides_empat}</span> PE
                  {/if}
                </div>
              </td>
              <td class="col-num tabular-nums hide-sm">{classification.partides_jugades}</td>
              <td class="col-num col-win tabular-nums hide-sm">{classification.partides_guanyades}</td>
              <td class="col-num col-lose tabular-nums hide-sm">{classification.partides_perdudes}</td>
              {#if hasEmpat}
                <td class="col-num col-draw tabular-nums hide-sm">{classification.partides_empat}</td>
              {/if}
              <td class="col-num col-pts tabular-nums">{classification.punts}</td>
              {#if showStats}
                <td class="col-num tabular-nums hide-md">{classification.caramboles_favor}</td>
                <td class="col-num tabular-nums hide-md">{classification.caramboles_contra}</td>
                <td class="col-num tabular-nums hide-lg">{formatAverage(classification.mitjana_particular)}</td>
              {/if}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <div class="cls-legend">
      <span><strong>PJ</strong> Partides jugades</span>
      <span><strong>PG</strong> Guanyades</span>
      <span><strong>PP</strong> Perdudes</span>
      {#if hasEmpat}
        <span><strong>PE</strong> Empat</span>
      {/if}
      {#if showStats}
        <span><strong>CF</strong> Caramboles favor</span>
        <span><strong>CC</strong> Caramboles contra</span>
        <span><strong>Mitjana</strong> CF/CC</span>
      {/if}
    </div>
  {/if}
</section>

<style>
  .cls-block {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .cls-head {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
  }
  .editorial-eyebrow {
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .cls-title {
    font-weight: 800;
    font-size: 1.25rem;
    letter-spacing: -0.022em;
    margin: 0;
    line-height: 1.15;
  }
  .cls-count {
    font-size: 0.8125rem;
    color: var(--ink-2);
    font-weight: 600;
  }

  .state-empty {
    padding: 2rem 1.5rem;
    text-align: center;
    color: var(--ink-2);
  }

  .cls-table-wrap { overflow-x: auto; }
  .cls-table { width: 100%; border-collapse: collapse; }
  .cls-table th {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    padding: 0.85rem 0.6rem;
    border-bottom: 1px solid var(--rule);
    white-space: nowrap;
    background: var(--paper);
  }
  .cls-table th.col-left { text-align: left; }
  .cls-table th.col-num { text-align: right; }
  .cls-table th.col-pos { width: 4rem; padding-left: 1.25rem; text-align: left; }
  .cls-table th.col-pts { color: var(--ink); }
  .cls-table td {
    padding: 0.85rem 0.6rem;
    border-bottom: 1px solid var(--rule);
    font-size: 0.9375rem;
    color: var(--ink);
    vertical-align: middle;
  }
  .cls-table td.col-pos { padding-left: 1.25rem; text-align: left; }
  .cls-table td.col-left { text-align: left; padding-left: 0; }
  .cls-table td.col-num { text-align: right; color: var(--ink-2); }
  .cls-table tr:last-child td { border-bottom: none; }
  .cls-table tr:hover { background: var(--paper); }

  .cls-table tr.top1 .pos-num { color: var(--accent); }
  .cls-table tr.top3 .pos-num { color: var(--amber); }

  .pos-num {
    font-weight: 800;
    font-size: 1.375rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    line-height: 1;
  }
  .player-name {
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.012em;
    font-size: 1rem;
  }
  .player-stats-mobile {
    display: none;
    font-size: 0.6875rem;
    color: var(--ink-3);
    margin-top: 0.3rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .col-win { color: var(--green) !important; font-weight: 600; }
  .col-lose { color: var(--accent) !important; font-weight: 600; }
  .col-draw { color: var(--amber) !important; font-weight: 600; }
  .col-pts.col-num {
    color: var(--ink) !important;
    font-weight: 800 !important;
    font-size: 1.125rem !important;
    letter-spacing: -0.02em;
  }

  .cls-legend {
    padding: 0.85rem 1.5rem;
    border-top: 1px solid var(--rule);
    background: var(--paper);
    font-size: 0.6875rem;
    color: var(--ink-3);
    display: flex;
    gap: 1.25rem;
    flex-wrap: wrap;
  }
  .cls-legend strong {
    color: var(--ink-2);
    font-weight: 700;
    margin-right: 0.25rem;
  }

  @media (max-width: 640px) {
    .cls-table th.hide-sm,
    .cls-table td.hide-sm { display: none; }
    .player-stats-mobile { display: block; }
    .cls-head { padding: 0.85rem 1rem; }
    .cls-title { font-size: 1.125rem; }
  }
  @media (max-width: 768px) {
    .cls-table th.hide-md,
    .cls-table td.hide-md { display: none; }
  }
  @media (max-width: 1024px) {
    .cls-table th.hide-lg,
    .cls-table td.hide-lg { display: none; }
  }
</style>
