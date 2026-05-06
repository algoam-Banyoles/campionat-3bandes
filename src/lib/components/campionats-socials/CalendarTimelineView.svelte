<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatDate, getDayOfWeekCode, type TimelineSlot } from '$lib/services/calendarTimelineService';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';

  export let timelineGrouped: Map<string, Map<string, TimelineSlot[]>> = new Map();
  export let dayNames: Record<string, string> = {};
  export let isAdmin: boolean = false;
  export let swapMode: boolean = false;
  export let selectedMatches: Set<string> = new Set();
  /** Indicadors actius de filtres per al missatge de "buit" contextual. */
  export let hasPlayerFilter: boolean = false;
  export let hasOtherFilter: boolean = false;
  export let playerSearch: string = '';

  const dispatch = createEventDispatcher<{
    toggleMatch: { matchId: string };
    openResult: { match: any };
    openIncompareixenca: { match: any };
    startEdit: { match: any };
    convertUnprogrammed: { match: any };
    programSlot: { slot: TimelineSlot };
  }>();
</script>

{#if timelineGrouped.size === 0}
  <div class="state-empty">
    {#if hasPlayerFilter}
      <div class="state-title">Cap partit trobat per "{playerSearch}"</div>
      <div class="state-sub">Prova amb un altre nom o neteja els filtres.</div>
    {:else if hasOtherFilter}
      <div class="state-title">Cap partit amb els filtres aplicats</div>
      <div class="state-sub">Prova eliminant alguns filtres.</div>
    {:else}
      <div class="state-title">No s'han generat slots de calendari</div>
      <div class="state-sub">Comprova la configuració del calendari o que hi hagi partits programats.</div>
    {/if}
  </div>
{:else}
  <!-- Unified table view with merged columns for days and hours -->
  <div class="calendar-main-container">
    <div class="overflow-x-auto">
      <table class="calendar-table">
        <thead>
          <tr>
            {#if isAdmin && swapMode}
              <th class="th-narrow print-hide">Sel.</th>
            {/if}
            <th class="th-day col-day">Dia</th>
            <th class="th-hour col-hour">Hora</th>
            <th class="th-billiard col-billiard">Billar</th>
            <th class="th-player col-player hide-sm">Jugador 1</th>
            <th class="th-player col-player hide-sm">Jugador 2</th>
            <th class="th-player col-player show-sm-only">Partida</th>
            {#if isAdmin}
              <th class="th-actions print-hide">Accions</th>
            {/if}
          </tr>
        </thead>
        <tbody>
          {#each Array.from(timelineGrouped.entries()) as [dateStr, hourGroups], dayIndex}
            {@const totalSlotsForDay = Array.from(hourGroups.values()).reduce((total, slots) => total + slots.length, 0)}
            {#each Array.from(hourGroups.entries()) as [hora, slots], hourIndex}
              {#each slots as slot, slotIndex}
                <tr
                  class:row-day-start={hourIndex === 0 && slotIndex === 0 && dayIndex > 0}
                  class:row-hour-start={hourIndex > 0 && slotIndex === 0}
                  class:row-selected={swapMode && slot.match && selectedMatches.has(slot.match.id)}
                  class:row-empty={!slot.match}
                >
                  <!-- Checkbox column for swap mode -->
                  {#if isAdmin && swapMode}
                    <td class="cell-narrow print-hide">
                      {#if slot.match}
                        <input
                          type="checkbox"
                          checked={selectedMatches.has(slot.match.id)}
                          on:change={() => slot.match && dispatch('toggleMatch', { matchId: slot.match.id })}
                          disabled={!slot.match.data_programada || !slot.match.hora_inici}
                        />
                      {/if}
                    </td>
                  {/if}

                  <!-- Day column with rowspan -->
                  {#if hourIndex === 0 && slotIndex === 0}
                    <td class="td-day col-day" rowspan={totalSlotsForDay}>
                      <div class="day-cell">
                        <div class="day-date print-date-main">{formatDate(new Date(dateStr))}</div>
                        <div class="day-name print-day-name hide-sm">{dayNames[getDayOfWeekCode(new Date(dateStr + 'T00:00:00').getDay())]}</div>
                      </div>
                    </td>
                  {/if}

                  <!-- Hour column with rowspan -->
                  {#if slotIndex === 0}
                    <td class="td-hour col-hour" rowspan={slots.length}>
                      <div class="hour-cell tabular-nums print-hour-header">{hora}</div>
                    </td>
                  {/if}

                  <!-- Billiard column -->
                  <td class="td-billiard col-billiard" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                    {#if slot.match && slot.match.taula_assignada}
                      <span class="billiard-badge billiard-confirmed">B{slot.match.taula_assignada}</span>
                    {:else if slot.match}
                      <span class="billiard-badge billiard-pending">B{slot.taula}</span>
                    {:else}
                      <span class="billiard-badge billiard-empty">B{slot.taula}</span>
                    {/if}
                  </td>

                  <!-- Jugador 1 (hidden on mobile) -->
                  <td class="td-player col-player hide-sm" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                    {#if slot.match}
                      <span class="player-name">{formatPlayerName(slot.match.jugador1)}</span>
                    {/if}
                  </td>

                  <!-- Jugador 2 (hidden on mobile) -->
                  <td class="td-player col-player hide-sm" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                    {#if slot.match}
                      <span class="player-name">{formatPlayerName(slot.match.jugador2)}</span>
                    {/if}
                  </td>

                  <!-- Combined players column (visible only on mobile) -->
                  <td class="td-player-mobile col-player show-sm-only" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                    {#if slot.match}
                      <div class="vs-mobile">
                        <span class="player-name">{formatPlayerName(slot.match.jugador1)}</span>
                        <span class="vs-sep">vs</span>
                        <span class="player-name">{formatPlayerName(slot.match.jugador2)}</span>
                      </div>
                    {/if}
                  </td>

                  <!-- Actions column -->
                  {#if isAdmin}
                    <td class="td-actions print-hide">
                      {#if slot.match}
                        <div class="actions-stack">
                          {#if slot.match.estat !== 'jugada' && slot.match.estat !== 'cancel·lada'}
                            <button on:click={() => dispatch('openResult', { match: slot.match })} class="action-link link-green" title="Introduir resultat de la partida">Resultat</button>
                            <button on:click={() => dispatch('openIncompareixenca', { match: slot.match })} class="action-link link-red" title="Marcar incompareixença">Incompareixença</button>
                          {/if}
                          <button on:click={() => dispatch('startEdit', { match: slot.match })} class="action-link link-blue">Editar</button>
                          {#if slot.match.data_programada}
                            <button on:click={() => dispatch('convertUnprogrammed', { match: slot.match })} class="action-link link-amber" title="Convertir a no programada">No programar</button>
                          {/if}
                        </div>
                      {:else}
                        <button on:click={() => dispatch('programSlot', { slot })} class="action-link link-green" title="Programar partida en aquest slot">+ Programar</button>
                      {/if}
                    </td>
                  {/if}
                </tr>
              {/each}
            {/each}
          {/each}
        </tbody>
      </table>
    </div>
  </div>
{/if}

<style>
  /* ── Calendari cronològic — estils editorials ────── */
  .state-empty {
    padding: 2rem 1.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    text-align: center;
    font-family: var(--font-sans);
  }
  .state-title {
    font-weight: 700;
    font-size: 1.0625rem;
    color: var(--ink);
    letter-spacing: -0.014em;
  }
  .state-sub {
    margin-top: 0.4rem;
    font-size: 0.875rem;
    color: var(--ink-3);
  }

  .calendar-main-container {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    overflow: hidden;
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .calendar-table {
    width: 100%;
    border-collapse: collapse;
    border: 2px solid var(--ink);
  }
  .calendar-table th,
  .calendar-table td {
    border: 1px solid var(--rule);
  }
  .calendar-table thead {
    background: var(--paper);
  }
  .calendar-table th {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--ink-3);
    text-align: left;
    padding: 0.85rem 0.85rem;
    white-space: nowrap;
  }
  .calendar-table th.th-narrow,
  .calendar-table th.th-billiard,
  .calendar-table td.cell-narrow,
  .calendar-table td.td-billiard { text-align: center; }
  .calendar-table th.th-day,
  .calendar-table th.th-hour { border-right: 3px solid var(--ink); }

  /* Files: separadors visuals entre dies i hores */
  .calendar-table tbody tr:hover { background: var(--paper); }
  .calendar-table tbody tr.row-day-start td {
    border-top: 3px solid var(--ink);
  }
  .calendar-table tbody tr.row-hour-start td {
    border-top: 2px solid var(--rule-strong);
  }
  .calendar-table tbody tr.row-selected {
    background: rgba(31, 79, 139, 0.08);
  }
  .calendar-table td {
    padding: 0.75rem 0.85rem;
    font-size: 0.9375rem;
    color: var(--ink);
    vertical-align: middle;
  }

  /* Cel·la de dia: vertical, amb data destacada i nom del dia a sota */
  .calendar-table td.td-day {
    background: var(--paper);
    border-right: 3px solid var(--ink);
    vertical-align: top;
    padding: 0.85rem;
  }
  .day-cell { line-height: 1.2; }
  .day-date {
    font-weight: 800;
    font-size: 1rem;
    color: var(--ink);
    letter-spacing: -0.018em;
  }
  .day-name {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--ink-3);
    margin-top: 0.25rem;
  }

  .calendar-table td.td-hour {
    background: var(--paper);
    border-right: 3px solid var(--ink);
    vertical-align: top;
    padding: 0.85rem;
  }
  .hour-cell {
    font-weight: 700;
    font-size: 1rem;
    color: var(--ink);
    letter-spacing: -0.012em;
  }

  /* Billiard badge */
  .billiard-badge {
    display: inline-block;
    padding: 0.2rem 0.55rem;
    font-weight: 700;
    font-size: 0.875rem;
    letter-spacing: -0.012em;
    border: 1px solid var(--rule-strong);
    font-feature-settings: 'tnum' 1;
  }
  .billiard-confirmed {
    color: var(--green);
    border-color: var(--green);
  }
  .billiard-pending {
    color: var(--amber);
    border-color: var(--amber);
  }
  .billiard-empty {
    color: var(--ink-3);
    border-color: var(--rule);
  }

  /* Player */
  .player-name {
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.012em;
  }
  .empty-cell .player-name { color: var(--ink-3); }
  .vs-mobile {
    display: flex;
    flex-direction: column;
    line-height: 1.2;
  }
  .vs-sep {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin: 0.15rem 0;
  }

  /* Actions stack */
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

  /* Mostrar/amagar columnes en mòbil */
  .show-sm-only { display: none; }
  @media (max-width: 640px) {
    .hide-sm { display: none !important; }
    .show-sm-only { display: table-cell !important; }
    .calendar-table th, .calendar-table td { padding: 0.5rem 0.5rem; }
    .day-date { font-size: 0.875rem; }
    .hour-cell { font-size: 0.875rem; }
    .billiard-badge { font-size: 0.75rem; padding: 0.15rem 0.4rem; }
    .player-name { font-size: 0.875rem; }
  }

  /* ── Print ─────────────────────────────────────────── */
  @media print {
    .calendar-main-container {
      border: none !important;
      box-shadow: none !important;
      margin-top: 140px !important;
      position: relative !important;
    }
    .calendar-main-container .overflow-x-auto {
      overflow: visible !important;
    }
    .calendar-table {
      border-color: #000 !important;
    }
    .calendar-table th,
    .calendar-table td {
      border-color: #555 !important;
    }
    .calendar-table th.th-day,
    .calendar-table th.th-hour,
    .calendar-table td.td-day,
    .calendar-table td.td-hour {
      border-right: 4px solid #000 !important;
    }
    .calendar-table .col-day {
      width: 80px !important;
      min-width: 80px !important;
      max-width: 80px !important;
    }
    .calendar-table .col-hour {
      width: 50px !important;
      min-width: 50px !important;
      max-width: 50px !important;
    }
    .calendar-table .col-billiard {
      width: 60px !important;
      min-width: 60px !important;
      max-width: 60px !important;
    }
    .billiard-badge {
      background: white !important;
      color: #000 !important;
      border-color: #555 !important;
    }
    .print-date-main {
      font-size: 10px !important;
      font-weight: bold !important;
      line-height: 1.1 !important;
      margin: 0 !important;
    }
    .print-day-name {
      font-size: 8px !important;
      font-weight: normal !important;
      color: #666 !important;
      line-height: 1.1 !important;
      margin: 1px 0 0 0 !important;
    }
    .print-hour-header {
      font-size: 11px !important;
      font-weight: bold !important;
      text-align: center !important;
      line-height: 1.1 !important;
    }
    .match-cell .player-name {
      font-weight: 700 !important;
      font-size: 11px !important;
    }
    .empty-cell .player-name { color: #888 !important; }
  }
</style>

