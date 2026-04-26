<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';

  export let match: any | null = null;
  export let saving: boolean = false;

  const dispatch = createEventDispatcher<{
    selectAbsent: { player: 1 | 2 };
    close: void;
  }>();

  function selectPlayer(player: 1 | 2) {
    dispatch('selectAbsent', { player });
  }

  function handleClose() {
    dispatch('close');
  }
</script>

{#if match}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
    <div class="relative bg-white rounded-lg shadow-xl max-w-2xl w-full mx-auto">
      <div class="bg-red-50 border-b border-red-200 px-6 py-4">
        <h3 class="text-xl font-bold text-red-900 flex items-center">
          <span class="mr-2">⚠️</span> Registrar Incompareixença
        </h3>
      </div>

      <div class="p-6">
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
          <p class="text-sm text-yellow-800 font-medium mb-2">
            ℹ️ Informació sobre incompareixences:
          </p>
          <ul class="text-sm text-yellow-800 list-disc list-inside space-y-1">
            <li>El jugador que <strong>no s'ha presentat</strong> rebrà: 0 punts, 50 entrades</li>
            <li>El jugador que <strong>s'ha presentat</strong> rebrà: 2 punts, 0 entrades</li>
            <li>Si un jugador té <strong>2 incompareixences</strong>, serà eliminat automàticament del campionat</li>
            <li>Totes les partides pendents del jugador eliminat quedaran <strong>anul·lades</strong></li>
          </ul>
        </div>

        <div class="mb-6">
          <h4 class="font-medium text-gray-900 mb-4 text-center">Quin jugador NO s'ha presentat?</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <button
              type="button"
              on:click={() => selectPlayer(1)}
              class="p-6 border-2 border-red-300 rounded-lg hover:bg-red-50 hover:border-red-500 transition-colors disabled:opacity-50"
              disabled={saving}
            >
              <div class="text-center">
                <div class="text-3xl mb-2">👤</div>
                <div class="font-bold text-lg text-gray-900 mb-1">Jugador 1</div>
                <div class="text-base text-gray-700">
                  {formatPlayerName(match.jugador1)}
                </div>
                <div class="mt-3 text-sm text-red-600 font-medium">
                  ⚠️ Marcar incompareixença
                </div>
              </div>
            </button>

            <button
              type="button"
              on:click={() => selectPlayer(2)}
              class="p-6 border-2 border-red-300 rounded-lg hover:bg-red-50 hover:border-red-500 transition-colors disabled:opacity-50"
              disabled={saving}
            >
              <div class="text-center">
                <div class="text-3xl mb-2">👤</div>
                <div class="font-bold text-lg text-gray-900 mb-1">Jugador 2</div>
                <div class="text-base text-gray-700">
                  {formatPlayerName(match.jugador2)}
                </div>
                <div class="mt-3 text-sm text-red-600 font-medium">
                  ⚠️ Marcar incompareixença
                </div>
              </div>
            </button>
          </div>
        </div>

        <div class="bg-gray-50 border-t border-gray-200 -mx-6 -mb-6 px-6 py-4 flex justify-end">
          <button
            type="button"
            on:click={handleClose}
            class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 font-medium"
            disabled={saving}
          >
            ❌ Cancel·lar
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
