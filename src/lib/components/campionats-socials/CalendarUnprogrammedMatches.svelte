<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';

  export let matches: any[] = [];
  export let isAdmin: boolean = false;
  export let categoryNames: Record<string, string> = {};
  export let estatOptions: Array<{ value: string; label: string }> = [];

  const dispatch = createEventDispatcher<{
    program: { match: any };
  }>();

  function getCategoryName(categoryId: string): string {
    return categoryNames[categoryId] ?? 'Desconeguda';
  }

  function getEstatLabel(estat: string): string {
    return estatOptions.find(opt => opt.value === estat)?.label ?? 'Pendent programar';
  }
</script>

{#if matches.length > 0}
  <div class="bg-white border border-orange-300 rounded-lg p-6 mt-6">
    <h3 class="text-lg font-medium text-orange-900 mb-4 flex items-center">
      <span class="mr-2">⏳</span> Partides Pendents de Programar ({matches.length})
    </h3>

    <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-4">
      <p class="text-sm text-orange-800">
        <strong>ℹ️ Informació:</strong> Aquestes partides no s'han pogut programar automàticament dins el període establert del campionat.
        Caldrà programar-les manualment o ampliar el període del campionat.
      </p>
    </div>

    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-orange-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Categoria</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Jugador 1</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Jugador 2</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Estat</th>
            {#if isAdmin}
              <th class="px-6 py-3 text-left text-xs font-medium text-orange-700 uppercase">Accions</th>
            {/if}
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          {#each matches as match (match.id)}
            <tr class="hover:bg-orange-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {match.categoria_nom || getCategoryName(match.categoria_id)}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <span class="font-medium">{formatPlayerName(match.jugador1)}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <span class="font-medium">{formatPlayerName(match.jugador2)}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-800">
                  {getEstatLabel(match.estat)}
                </span>
              </td>
              {#if isAdmin}
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button
                    on:click={() => dispatch('program', { match })}
                    class="text-orange-600 hover:text-orange-900"
                  >
                    Programar
                  </button>
                </td>
              {/if}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </div>
{/if}
