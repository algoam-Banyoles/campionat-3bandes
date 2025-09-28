<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError } from '$lib/ui/alerts';

  const dispatch = createEventDispatcher();

  export let inscription: any = null;
  export let isOpen = false;

  let preferencies_dies = [];
  let preferencies_hores = [];
  let restriccions_especials = '';
  let saving = false;

  // Inicialitzar valors quan s'obre el modal
  $: if (inscription && isOpen) {
    preferencies_dies = inscription.preferencies_dies || [];
    preferencies_hores = inscription.preferencies_hores || [];
    restriccions_especials = inscription.restriccions_especials || '';
  }

  async function saveRestrictions() {
    if (!inscription) return;

    saving = true;

    try {
      const { error } = await supabase
        .from('inscripcions')
        .update({
          preferencies_dies,
          preferencies_hores,
          restriccions_especials: restriccions_especials.trim() || null
        })
        .eq('id', inscription.id);

      if (error) throw error;

      dispatch('updated', {
        id: inscription.id,
        preferencies_dies,
        preferencies_hores,
        restriccions_especials
      });

      closeModal();

    } catch (error) {
      console.error('Error actualitzant restriccions:', error);
      dispatch('error', { message: formatSupabaseError(error) });
    } finally {
      saving = false;
    }
  }

  function closeModal() {
    isOpen = false;
    dispatch('close');
  }

  function handleKeydown(event) {
    if (event.key === 'Escape') {
      closeModal();
    }
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if isOpen && inscription}
  <!-- Modal backdrop -->
  <div
    class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
    on:click={closeModal}
  >
    <!-- Modal content -->
    <div
      class="relative top-20 mx-auto p-5 border w-11/12 md:w-3/5 lg:w-1/2 shadow-lg rounded-md bg-white"
      on:click|stopPropagation
    >
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">
          Restriccions de {inscription.socis.nom} {inscription.socis.cognoms}
        </h3>
        <button
          on:click={closeModal}
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>

      <!-- Form -->
      <form on:submit|preventDefault={saveRestrictions}>
        <!-- Dies preferits -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-3">
            Dies preferits de la setmana
          </label>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
            {#each [
              { code: 'dl', name: 'Dilluns' },
              { code: 'dt', name: 'Dimarts' },
              { code: 'dc', name: 'Dimecres' },
              { code: 'dj', name: 'Dijous' },
              { code: 'dv', name: 'Divendres' },
              { code: 'ds', name: 'Dissabte' },
              { code: 'dg', name: 'Diumenge' }
            ] as day}
              <label class="flex items-center">
                <input
                  type="checkbox"
                  bind:group={preferencies_dies}
                  value={day.code}
                  class="mr-2 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <span class="text-sm text-gray-700">{day.name}</span>
              </label>
            {/each}
          </div>
          <p class="mt-1 text-xs text-gray-500">
            Si no selecciones cap dia, s'assumeix que tots els dies estan bé
          </p>
        </div>

        <!-- Hores preferides -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-3">
            Hores preferides
          </label>
          <div class="grid grid-cols-3 md:grid-cols-3 gap-2">
            {#each ['18:00', '19:00', '17:30', '18:30', '19:30', '20:00'] as hora}
              <label class="flex items-center">
                <input
                  type="checkbox"
                  bind:group={preferencies_hores}
                  value={hora}
                  class="mr-2 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <span class="text-sm text-gray-700">{hora}</span>
              </label>
            {/each}
          </div>
          <p class="mt-1 text-xs text-gray-500">
            Horaris habituals: 18:00 i 19:00. Si no selecciones cap hora, s'assumeix que totes estan bé.
          </p>
        </div>

        <!-- Restriccions especials -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Restriccions especials o observacions
          </label>
          <textarea
            bind:value={restriccions_especials}
            rows="3"
            placeholder="Exemple: No disponible del 15 al 22 de desembre, o prefereixo no jugar els dimarts..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
          ></textarea>
          <p class="mt-1 text-xs text-gray-500">
            Escriu aquí qualsevol altra restricció o preferència especial
          </p>
        </div>

        <!-- Botons -->
        <div class="flex items-center justify-end space-x-3">
          <button
            type="button"
            on:click={closeModal}
            class="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
          >
            Cancel·lar
          </button>
          <button
            type="submit"
            disabled={saving}
            class="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400"
          >
            {saving ? 'Desant...' : 'Desar Restriccions'}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}