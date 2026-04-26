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

<div class="print-category-hide">
  {#if totalMatches === 0}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center">
      <div class="text-gray-500">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
        </svg>
        <p class="mt-2">No hi ha partits programats</p>
      </div>
    </div>
  {:else}
    {#each Array.from(matchesByCategory.entries()) as [categoryId, categoryMatches] (categoryId)}
      <div class="bg-white border border-gray-200 rounded-lg p-6">
        <h4 class="text-lg font-medium text-gray-900 mb-4">
          {getCategoryName(categoryId)} ({categoryMatches.length} partits)
        </h4>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                {#if isAdmin && swapMode}
                  <th class="px-2 sm:px-6 py-2 sm:py-3 text-center text-xs font-medium text-gray-500 uppercase print-hide">Sel.</th>
                {/if}
                <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">Data</th>
                <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">Hora</th>
                <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase hidden sm:table-cell">Billar</th>
                <th class="px-2 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">Enfrontament</th>
                {#if isAdmin}
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase print-hide">Accions</th>
                {/if}
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              {#each categoryMatches as match (match.id)}
                <tr class="hover:bg-gray-50" class:bg-blue-50={swapMode && selectedMatches.has(match.id)}>
                  {#if isAdmin && swapMode}
                    <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-center print-hide">
                      <input
                        type="checkbox"
                        checked={selectedMatches.has(match.id)}
                        on:change={() => dispatch('toggleMatch', { matchId: match.id })}
                        class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                        disabled={!match.data_programada || !match.hora_inici}
                      />
                    </td>
                  {/if}
                  <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-sm sm:text-base text-gray-900">
                    <div class="flex flex-col">
                      <span>{match.data_programada ? formatDate(new Date(match.data_programada)) : 'No programada'}</span>
                      <span class="text-xs text-gray-500 sm:hidden">
                        {match.hora_inici || '-'}
                        {#if match.taula_assignada}• B{match.taula_assignada}{/if}
                      </span>
                    </div>
                  </td>
                  <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-sm sm:text-base text-gray-900">
                    {match.hora_inici || '-'}
                  </td>
                  <td class="hidden sm:table-cell px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-sm sm:text-base text-gray-900">
                    {match.taula_assignada ? `B${match.taula_assignada}` : 'No assignada'}
                  </td>
                  <td class="px-2 sm:px-6 py-2 sm:py-4 whitespace-nowrap text-sm sm:text-base text-gray-900">
                    <div class="flex flex-col">
                      <span class="font-medium">
                        {formatPlayerName(match.jugador1)}
                      </span>
                      <span class="text-xs text-gray-500">vs</span>
                      <span class="font-medium">
                        {formatPlayerName(match.jugador2)}
                      </span>
                    </div>
                  </td>
                  {#if isAdmin}
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium print-hide">
                      <div class="flex flex-col space-y-1">
                        {#if match.estat !== 'jugada' && match.estat !== 'validat'}
                          <button
                            on:click={() => dispatch('openResult', { match })}
                            class="text-green-600 hover:text-green-900 font-medium"
                            title="Introduir resultat de la partida"
                          >
                            📝 Resultat
                          </button>
                          <button
                            on:click={() => dispatch('openIncompareixenca', { match })}
                            class="text-red-600 hover:text-red-900 font-medium text-xs"
                            title="Marcar incompareixença"
                          >
                            ⚠️ Incompareixença
                          </button>
                        {/if}
                        <button
                          on:click={() => dispatch('startEdit', { match })}
                          class="text-blue-600 hover:text-blue-900"
                        >
                          Editar
                        </button>
                        {#if match.data_programada}
                          <button
                            on:click={() => dispatch('convertUnprogrammed', { match })}
                            class="text-orange-600 hover:text-orange-900 text-xs"
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
      </div>
    {/each}
  {/if}
</div>
