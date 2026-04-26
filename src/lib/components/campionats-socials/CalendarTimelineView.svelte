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
  <div class="bg-white border border-gray-200 rounded-lg p-8 text-center">
    <div class="text-gray-500">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 002 2z"/>
      </svg>
      {#if hasPlayerFilter}
        <p class="mt-2">Cap partit trobat per "{playerSearch}"</p>
        <p class="text-sm text-gray-400">Prova amb un altre nom o neteja els filtres</p>
      {:else if hasOtherFilter}
        <p class="mt-2">Cap partit trobat amb els filtres aplicats</p>
        <p class="text-sm text-gray-400">Prova eliminant alguns filtres</p>
      {:else}
        <p class="mt-2">No s'han generat slots de calendari</p>
        <p class="text-sm text-gray-400">Comprova la configuració del calendari o que hi hagi partits programats</p>
      {/if}
    </div>
  </div>
{:else}
  <!-- Unified table view with merged columns for days and hours -->
  <div class="bg-white border border-gray-200 rounded-lg overflow-hidden calendar-main-container">
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-500 calendar-table border-collapse">
        <thead class="bg-gray-100">
          <tr>
            {#if isAdmin && swapMode}
              <th class="px-3 py-4 text-center text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 print-hide">Seleccionar</th>
            {/if}
            <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-4 border-gray-800 day-column">Dia</th>
            <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-4 border-gray-800 hour-column">Hora</th>
            <th class="px-2 sm:px-6 py-2 sm:py-4 text-center text-xs sm:text-sm md:text-base font-semibold text-gray-800 uppercase border-r-2 border-gray-400 table-column min-w-[60px] sm:min-w-[100px]">Billar</th>
            <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-2 border-gray-400 player-column hidden sm:table-cell">Jugador 1</th>
            <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-2 border-gray-400 player-column hidden sm:table-cell">Jugador 2</th>
            <th class="px-2 sm:px-3 py-2 sm:py-4 text-left text-sm sm:text-base lg:text-lg xl:text-xl font-semibold text-gray-800 uppercase border-r-2 border-gray-400 player-column sm:hidden">Partida</th>
            {#if isAdmin}
              <th class="px-3 py-4 text-left text-sm md:text-base font-semibold text-gray-800 uppercase print-hide">Accions</th>
            {/if}
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-300">
          {#each Array.from(timelineGrouped.entries()) as [dateStr, hourGroups], dayIndex}
            {@const totalSlotsForDay = Array.from(hourGroups.values()).reduce((total, slots) => total + slots.length, 0)}
            {#each Array.from(hourGroups.entries()) as [hora, slots], hourIndex}
              {#each slots as slot, slotIndex}
                <tr class="hover:bg-gray-50"
                    class:border-t-4={hourIndex === 0 && slotIndex === 0 && dayIndex > 0}
                    class:border-t-gray-600={hourIndex === 0 && slotIndex === 0 && dayIndex > 0}
                    class:border-t-2={hourIndex > 0 && slotIndex === 0}
                    class:border-t-gray-400={hourIndex > 0 && slotIndex === 0}
                    class:bg-blue-50={swapMode && slot.match && selectedMatches.has(slot.match.id)}>

                  <!-- Checkbox column for swap mode -->
                  {#if isAdmin && swapMode}
                    <td class="px-3 py-4 whitespace-nowrap text-center border-r-2 border-gray-400 print-hide">
                      {#if slot.match}
                        <input
                          type="checkbox"
                          checked={selectedMatches.has(slot.match.id)}
                          on:change={() => slot.match && dispatch('toggleMatch', { matchId: slot.match.id })}
                          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                          disabled={!slot.match.data_programada || !slot.match.hora_inici}
                        />
                      {/if}
                    </td>
                  {/if}

                  <!-- Day column with rowspan -->
                  {#if hourIndex === 0 && slotIndex === 0}
                    <td class="px-2 sm:px-3 py-2 sm:py-4 text-base sm:text-lg lg:text-xl xl:text-2xl font-bold text-gray-900 border-r-4 border-gray-800 bg-gray-50 align-top day-column" rowspan={totalSlotsForDay}>
                      <div class="sticky top-0 print-day-header">
                        <div class="print-date-main text-base sm:text-lg lg:text-xl xl:text-2xl">{formatDate(new Date(dateStr))}</div>
                        <div class="print-day-name text-xs sm:text-sm hidden sm:block">{dayNames[getDayOfWeekCode(new Date(dateStr + 'T00:00:00').getDay())]}</div>
                      </div>
                    </td>
                  {/if}

                  <!-- Hour column with rowspan for each hour group -->
                  {#if slotIndex === 0}
                    <td class="px-2 sm:px-3 py-2 sm:py-4 text-base sm:text-lg lg:text-xl xl:text-2xl font-bold text-gray-800 border-r-4 border-gray-800 bg-gray-100 align-top hour-column" rowspan={slots.length}>
                      <div class="print-hour-header">{hora}</div>
                    </td>
                  {/if}

                  <!-- Table column -->
                  <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-xs sm:text-sm md:text-base text-gray-900 border-r-2 border-gray-400 table-column text-center font-medium min-w-[60px] sm:min-w-[100px]" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                    {#if slot.match && slot.match.taula_assignada}
                      <span class="table-number-compact bg-green-100 px-3 py-2 rounded-full text-green-800 font-bold text-lg">B{slot.match.taula_assignada}</span>
                    {:else if slot.match}
                      <span class="table-number-compact bg-orange-100 px-3 py-2 rounded-full text-orange-800 font-bold text-lg">B{slot.taula}</span>
                    {:else}
                      <span class="table-number-compact bg-blue-100 px-3 py-2 rounded-full text-blue-800 font-bold text-lg">B{slot.taula}</span>
                    {/if}
                  </td>

                  <!-- Jugador 1 (hidden on mobile) -->
                  <td class="hidden sm:table-cell px-2 sm:px-3 py-2 sm:py-4 whitespace-nowrap text-base sm:text-lg lg:text-xl xl:text-2xl text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                    {#if slot.match}
                      <span class="font-semibold">{formatPlayerName(slot.match.jugador1)}</span>
                    {/if}
                  </td>

                  <!-- Jugador 2 (hidden on mobile) -->
                  <td class="hidden sm:table-cell px-2 sm:px-3 py-2 sm:py-4 whitespace-nowrap text-base sm:text-lg lg:text-xl xl:text-2xl text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                    {#if slot.match}
                      <span class="font-semibold">{formatPlayerName(slot.match.jugador2)}</span>
                    {/if}
                  </td>

                  <!-- Combined players column (visible only on mobile) -->
                  <td class="sm:hidden px-2 py-2 text-sm text-gray-900 border-r-2 border-gray-400 player-column" class:match-cell={slot.match} class:empty-cell={!slot.match}>
                    {#if slot.match}
                      <div class="flex flex-col">
                        <span class="font-semibold text-sm">{formatPlayerName(slot.match.jugador1)}</span>
                        <span class="text-xs text-gray-500">vs</span>
                        <span class="font-semibold text-sm">{formatPlayerName(slot.match.jugador2)}</span>
                      </div>
                    {/if}
                  </td>

                  <!-- Actions column -->
                  {#if isAdmin}
                    <td class="px-3 py-4 whitespace-nowrap text-sm md:text-base font-medium print-hide">
                      {#if slot.match}
                        <div class="flex flex-col space-y-1">
                          {#if slot.match.estat !== 'jugada' && slot.match.estat !== 'cancel·lada'}
                            <button
                              on:click={() => dispatch('openResult', { match: slot.match })}
                              class="text-green-600 hover:text-green-900 text-sm md:text-base font-semibold"
                              title="Introduir resultat de la partida"
                            >
                              📝 Resultat
                            </button>
                            <button
                              on:click={() => dispatch('openIncompareixenca', { match: slot.match })}
                              class="text-red-600 hover:text-red-900 text-xs md:text-sm font-semibold"
                              title="Marcar incompareixença"
                            >
                              ⚠️ Incompareixença
                            </button>
                          {/if}
                          <button
                            on:click={() => dispatch('startEdit', { match: slot.match })}
                            class="text-blue-600 hover:text-blue-900 text-sm md:text-base font-medium"
                          >
                            Editar
                          </button>
                          {#if slot.match.data_programada}
                            <button
                              on:click={() => dispatch('convertUnprogrammed', { match: slot.match })}
                              class="text-orange-600 hover:text-orange-900 text-xs md:text-sm font-medium"
                              title="Convertir a no programada"
                            >
                              No programar
                            </button>
                          {/if}
                        </div>
                      {:else}
                        <button
                          on:click={() => dispatch('programSlot', { slot })}
                          class="text-green-600 hover:text-green-900 text-sm md:text-base font-semibold"
                          title="Programar partida en aquest slot"
                        >
                          + Programar
                        </button>
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
  /* Estils del calendari cronològic. Originalment estaven a
     SocialLeagueCalendarViewer; s'han mogut aquí amb la subdivisió
     perquè ara és aquí on es renderitza la taula. */

  /* Estructura general */
  .calendar-table {
    border: 2px solid #374151 !important;
  }

  .calendar-table th,
  .calendar-table td {
    border: 1px solid #d1d5db !important;
  }

  .calendar-table tbody tr {
    border-bottom: 1px solid #d1d5db !important;
  }

  .calendar-table tbody tr:where(.border-t-4) {
    border-top: 4px solid #374151 !important;
  }

  .calendar-table tbody tr:where(.border-t-2) {
    border-top: 2px solid #6b7280 !important;
  }

  /* Pantalla: forçar visibilitat de la columna del billar */
  @media screen {
    .table-column {
      min-width: 100px !important;
      width: 100px !important;
      visibility: visible !important;
      display: table-cell !important;
    }

    .table-number-compact {
      display: inline-block !important;
      visibility: visible !important;
    }

    .calendar-table .table-column {
      opacity: 1 !important;
      visibility: visible !important;
      display: table-cell !important;
    }
  }

  /* Mòbil */
  @media (max-width: 768px) {
    .calendar-table {
      font-size: 16px !important;
    }

    .calendar-table th,
    .calendar-table td {
      padding: 8px 6px !important;
      font-size: 14px !important;
      line-height: 1.4 !important;
    }

    .calendar-table .day-column {
      min-width: 80px !important;
    }

    .calendar-table .hour-column {
      min-width: 60px !important;
    }

    .calendar-table .player-column {
      min-width: 100px !important;
    }

    .calendar-table .font-bold {
      font-size: 16px !important;
    }

    .calendar-table .font-semibold {
      font-size: 15px !important;
    }
  }

  /* Tauletes */
  @media (min-width: 769px) and (max-width: 1024px) {
    .calendar-table th,
    .calendar-table td {
      font-size: 15px !important;
      padding: 10px 8px !important;
    }
  }

  /* Print: la taula i els seus estils específics */
  @media print {
    .calendar-main-container {
      border: none !important;
      border-radius: 0 !important;
      box-shadow: none !important;
      margin-top: 140px !important;
      position: relative !important;
    }

    .calendar-main-container .overflow-x-auto {
      overflow: visible !important;
    }

    .calendar-table .day-column {
      width: 80px !important;
      min-width: 80px !important;
      max-width: 80px !important;
      border-right: 4px solid #1f2937 !important;
    }

    .calendar-table .hour-column {
      width: 50px !important;
      min-width: 50px !important;
      max-width: 50px !important;
      border-right: 4px solid #1f2937 !important;
    }

    .calendar-table .table-column {
      width: 60px !important;
      min-width: 60px !important;
      max-width: 60px !important;
      visibility: visible !important;
      display: table-cell !important;
    }

    .calendar-table th:nth-child(3),
    .calendar-table td:nth-child(3) {
      border-right: 2px solid #6b7280 !important;
    }

    .calendar-table th,
    .calendar-table td {
      border-right: 2px solid #666 !important;
    }

    .table-number-compact {
      font-size: 9px !important;
      font-weight: bold !important;
      background-color: #f0f0f0 !important;
      padding: 1px 3px !important;
      border-radius: 2px !important;
    }

    .print-day-header {
      text-align: center !important;
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
      margin: 0 !important;
    }

    .match-cell {
      background-color: #fafafa !important;
      font-weight: bold !important;
      font-size: 14px !important;
    }

    .empty-cell {
      color: #666 !important;
      font-style: italic !important;
    }
  }
</style>

