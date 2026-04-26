<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';
  import { toLocalDateStr } from '$lib/services/calendarTimelineService';

  export let match: any | null = null;
  export let estatOptions: Array<{ value: string; label: string; color?: string }> = [];

  const dispatch = createEventDispatcher<{
    save: {
      data_programada: string;
      hora_inici: string;
      taula_assignada: number | null;
      estat: string;
      observacions_junta: string;
    };
    cancel: void;
  }>();

  let form = createEmptyForm();

  function createEmptyForm() {
    return {
      data_programada: '',
      hora_inici: '',
      taula_assignada: null as number | null,
      estat: 'generat',
      observacions_junta: ''
    };
  }

  // Re-inicialitza el formulari cada cop que canvia la partida.
  $: if (match) {
    form = {
      data_programada: match.data_programada
        ? toLocalDateStr(new Date(match.data_programada))
        : '',
      hora_inici: match.hora_inici || '',
      taula_assignada: match.taula_assignada,
      estat: match.estat || 'generat',
      observacions_junta: match.observacions_junta || ''
    };
  }

  function handleSubmit() {
    dispatch('save', { ...form });
  }

  function handleCancel() {
    dispatch('cancel');
  }
</script>

{#if match}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" role="dialog" aria-modal="true">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <h3 class="text-lg font-medium text-gray-900 mb-4">
        Editar Partit
      </h3>

      <form on:submit|preventDefault={handleSubmit} class="space-y-4">
        <div>
          <label for="edit-date" class="block text-sm font-medium text-gray-700 mb-1">Data</label>
          <input
            id="edit-date"
            type="date"
            bind:value={form.data_programada}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label for="edit-time" class="block text-sm font-medium text-gray-700 mb-1">Hora</label>
          <input
            id="edit-time"
            type="time"
            bind:value={form.hora_inici}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label for="edit-table-input" class="block text-sm font-medium text-gray-700 mb-1">Billar</label>
          <input
            id="edit-table-input"
            type="number"
            min="1"
            max="10"
            bind:value={form.taula_assignada}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label for="edit-status" class="block text-sm font-medium text-gray-700 mb-1">Estat</label>
          <select
            id="edit-status"
            bind:value={form.estat}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            {#each estatOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>

        <div>
          <label for="edit-observations" class="block text-sm font-medium text-gray-700 mb-1">Observacions</label>
          <textarea
            id="edit-observations"
            bind:value={form.observacions_junta}
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Observacions opcionals..."
          ></textarea>
        </div>

        <div class="flex justify-end space-x-3 pt-4">
          <button
            type="button"
            on:click={handleCancel}
            class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400"
          >
            Cancel·lar
          </button>
          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            Desar
          </button>
        </div>
      </form>

      <div class="mt-4 pt-4 border-t border-gray-200">
        <div class="text-sm text-gray-600">
          <strong>Jugadors:</strong><br>
          {formatPlayerName(match.jugador1)} vs {formatPlayerName(match.jugador2)}
        </div>
      </div>
    </div>
  </div>
{/if}
