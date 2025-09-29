<script lang="ts">
  import type { Classification } from '$lib/types';

  export let classifications: Classification[] = [];
  export let title: string = 'Classificació';
  export let showStats: boolean = true;

  function formatAverage(avg: number | null): string {
    if (avg === null || avg === undefined) return '-';
    return avg.toFixed(3);
  }

  function getPositionClass(position: number): string {
    if (position === 1) return 'text-yellow-600 font-bold';
    if (position === 2) return 'text-gray-500 font-bold';
    if (position === 3) return 'text-amber-600 font-bold';
    return 'text-gray-900';
  }

  function getPositionBadge(position: number): string {
    if (position === 1) return '🥇';
    if (position === 2) return '🥈';
    if (position === 3) return '🥉';
    return '';
  }
</script>

<div class="bg-white border border-gray-200 rounded-lg">
  <div class="px-6 py-4 border-b border-gray-200">
    <h3 class="text-lg font-semibold text-gray-900">{title}</h3>
    {#if classifications.length > 0}
      <p class="text-sm text-gray-600">{classifications.length} jugadors classificats</p>
    {/if}
  </div>

  {#if classifications.length === 0}
    <div class="p-6 text-center text-gray-500">
      <p>No hi ha classificacions disponibles</p>
    </div>
  {:else}
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              <span class="hidden sm:inline">Posició</span>
              <span class="sm:hidden">Pos.</span>
            </th>
            <th class="px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Jugador
            </th>
            <th class="px-2 sm:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider hidden sm:table-cell">
              PJ
            </th>
            <th class="px-2 sm:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider hidden sm:table-cell">
              PG
            </th>
            <th class="px-2 sm:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider hidden sm:table-cell">
              PP
            </th>
            {#if classifications.some(c => c.partides_empat > 0)}
              <th class="px-2 sm:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider hidden sm:table-cell">
                PE
              </th>
            {/if}
            <th class="px-3 sm:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
              Punts
            </th>
            {#if showStats}
              <th class="px-2 sm:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider hidden md:table-cell">
                CF
              </th>
              <th class="px-2 sm:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider hidden md:table-cell">
                CC
              </th>
              <th class="px-2 sm:px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider hidden lg:table-cell">
                Mitjana
              </th>
            {/if}
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          {#each classifications as classification, index}
            <tr class={index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
              <td class="px-3 sm:px-6 py-4 whitespace-nowrap text-sm font-medium">
                <div class="flex items-center space-x-2">
                  <span class={getPositionClass(classification.posicio)}>
                    {classification.posicio}
                  </span>
                  <span class="text-lg">
                    {getPositionBadge(classification.posicio)}
                  </span>
                </div>
              </td>
              <td class="px-3 sm:px-6 py-4">
                <div class="text-sm font-medium text-gray-900">
                  {classification.player_nom}
                  {#if classification.player_cognom}
                    {classification.player_cognom}
                  {/if}
                </div>
                <!-- Mobile stats shown under name -->
                <div class="sm:hidden text-xs text-gray-500 mt-1">
                  {classification.partides_jugades}PJ • {classification.partides_guanyades}PG • {classification.partides_perdudes}PP
                  {#if classification.partides_empat > 0}
                    • {classification.partides_empat}PE
                  {/if}
                </div>
              </td>
              <td class="px-2 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-center hidden sm:table-cell">
                {classification.partides_jugades}
              </td>
              <td class="px-2 sm:px-6 py-4 whitespace-nowrap text-sm text-green-600 text-center font-medium hidden sm:table-cell">
                {classification.partides_guanyades}
              </td>
              <td class="px-2 sm:px-6 py-4 whitespace-nowrap text-sm text-red-600 text-center font-medium hidden sm:table-cell">
                {classification.partides_perdudes}
              </td>
              {#if classifications.some(c => c.partides_empat > 0)}
                <td class="px-2 sm:px-6 py-4 whitespace-nowrap text-sm text-yellow-600 text-center font-medium hidden sm:table-cell">
                  {classification.partides_empat}
                </td>
              {/if}
              <td class="px-3 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-center font-bold">
                {classification.punts}
              </td>
              {#if showStats}
                <td class="px-2 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-center hidden md:table-cell">
                  {classification.caramboles_favor}
                </td>
                <td class="px-2 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-center hidden md:table-cell">
                  {classification.caramboles_contra}
                </td>
                <td class="px-2 sm:px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-center font-medium hidden lg:table-cell">
                  {formatAverage(classification.mitjana_particular)}
                </td>
              {/if}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <!-- Llegenda -->
    <div class="px-6 py-4 bg-gray-50 border-t border-gray-200">
      <div class="text-xs text-gray-500 space-y-1">
        <p><strong>PJ:</strong> Partides Jugades | <strong>PG:</strong> Partides Guanyades | <strong>PP:</strong> Partides Perdudes</p>
        {#if classifications.some(c => c.partides_empat > 0)}
          <p><strong>PE:</strong> Partides Empat</p>
        {/if}
        {#if showStats}
          <p><strong>CF:</strong> Caramboles Favor | <strong>CC:</strong> Caramboles Contra | <strong>Mitjana:</strong> CF/CC</p>
        {/if}
      </div>
    </div>
  {/if}
</div>