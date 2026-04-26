<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';
  import { formatDate } from '$lib/services/calendarTimelineService';

  export let match: any | null = null;
  export let categoryName: string = '';
  export let saving: boolean = false;

  const dispatch = createEventDispatcher<{
    save: {
      caramboles_jugador1: number;
      caramboles_jugador2: number;
      entrades: number;
      observacions: string;
    };
    close: void;
  }>();

  let form = {
    caramboles_jugador1: 0,
    caramboles_jugador2: 0,
    entrades: 0,
    observacions: ''
  };

  // Reset cada cop que es mostra una nova partida.
  $: if (match) {
    form = {
      caramboles_jugador1: match.caramboles_jugador1 ?? 0,
      caramboles_jugador2: match.caramboles_jugador2 ?? 0,
      entrades: match.entrades ?? 0,
      observacions: match.observacions ?? ''
    };
  }

  function handleSubmit() {
    dispatch('save', { ...form });
  }

  function handleClose() {
    dispatch('close');
  }
</script>

{#if match}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
    <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-medium text-gray-900">
            📝 Introduir Resultat de la Partida
          </h3>
          <button
            type="button"
            on:click={handleClose}
            class="text-gray-400 hover:text-gray-600"
            aria-label="Tancar modal de resultat"
          >
            <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <div class="px-6 py-4">
        <!-- Info partida -->
        <div class="bg-gray-50 rounded-lg p-4 mb-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <div class="text-sm text-gray-600">Jugador 1</div>
              <div class="text-lg font-semibold text-gray-900">
                {formatPlayerName(match.jugador1)}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-600">Jugador 2</div>
              <div class="text-lg font-semibold text-gray-900">
                {formatPlayerName(match.jugador2)}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-600">Data</div>
              <div class="font-medium">
                {match.data_programada ? formatDate(new Date(match.data_programada)) : '-'}
                {#if match.hora_inici}
                  · {match.hora_inici}
                {/if}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-600">Categoria</div>
              <div class="font-medium">{match.categoria_nom || categoryName || '-'}</div>
            </div>
          </div>
        </div>

        <form on:submit|preventDefault={handleSubmit} class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label for="result-car1" class="block text-sm font-medium text-gray-700 mb-2">
                Caramboles {formatPlayerName(match.jugador1)}
              </label>
              <input
                id="result-car1"
                type="number"
                min="0"
                bind:value={form.caramboles_jugador1}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-lg font-semibold text-center"
                required
              />
            </div>

            <div>
              <label for="result-car2" class="block text-sm font-medium text-gray-700 mb-2">
                Caramboles {formatPlayerName(match.jugador2)}
              </label>
              <input
                id="result-car2"
                type="number"
                min="0"
                bind:value={form.caramboles_jugador2}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-lg font-semibold text-center"
                required
              />
            </div>

            <div>
              <label for="result-entrades" class="block text-sm font-medium text-gray-700 mb-2">
                Entrades
              </label>
              <input
                id="result-entrades"
                type="number"
                min="0"
                bind:value={form.entrades}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-lg font-semibold text-center"
                required
              />
            </div>
          </div>

          <!-- Guanyador calculat -->
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div class="text-sm font-medium text-blue-900">
              🏆 Guanyador:
              {#if form.caramboles_jugador1 > form.caramboles_jugador2}
                <span class="font-bold">{formatPlayerName(match.jugador1)}</span>
              {:else if form.caramboles_jugador2 > form.caramboles_jugador1}
                <span class="font-bold">{formatPlayerName(match.jugador2)}</span>
              {:else}
                <span class="text-gray-600">Empat (introdueix més caramboles)</span>
              {/if}
            </div>
          </div>

          <div>
            <label for="result-obs" class="block text-sm font-medium text-gray-700 mb-2">
              Observacions (opcional)
            </label>
            <textarea
              id="result-obs"
              bind:value={form.observacions}
              rows="3"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Incidències, comentaris..."
            ></textarea>
          </div>

          <div class="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              on:click={handleClose}
              class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400 font-medium"
              disabled={saving}
            >
              Cancel·lar
            </button>
            <button
              type="submit"
              class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 font-medium flex items-center gap-2"
              disabled={saving}
            >
              {#if saving}
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                Guardant...
              {:else}
                💾 Guardar Resultat
              {/if}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
{/if}
