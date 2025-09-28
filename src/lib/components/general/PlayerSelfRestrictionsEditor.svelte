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

  // Horaris i dies REALS del club - NOMÉS aquestes opcions
  const CLUB_DAYS = [
    { code: 'dl', name: 'Dilluns' },
    { code: 'dt', name: 'Dimarts' },
    { code: 'dc', name: 'Dimecres' },
    { code: 'dj', name: 'Dijous' },
    { code: 'dv', name: 'Divendres' }
  ];

  const CLUB_HOURS = ['18:00', '19:00'];

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
          Restriccions de {inscription.socis?.nom || 'Jugador'} {inscription.socis?.cognoms || ''}
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

      <!-- Form content -->

  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
    <h4 class="font-medium text-blue-900 mb-2">ℹ️ Informació Important</h4>
    <div class="text-sm text-blue-800 space-y-1">
      <p><strong>Horaris del club:</strong> Només es juguen partits de dilluns a divendres a les 18:00h i 19:00h</p>
      <p><strong>Opcional:</strong> Si no marques res, s'assumeix que tots els dies i hores et van bé</p>
      <p><strong>Disponibilitat:</strong> Marca els dies/hores que SÍ pots i vols jugar</p>
    </div>
  </div>

  <form on:submit|preventDefault={saveRestrictions}>
    <!-- Dies que SÍ pots jugar -->
    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 mb-3">
        Dies que SÍ pots jugar
      </label>
      <p class="text-sm text-gray-500 mb-3">Selecciona els dies que pots i vols jugar. Si no selecciones cap dia, podràs jugar qualsevol dia.</p>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        {#each CLUB_DAYS as day}
          <label class="flex items-center p-3 border rounded-lg hover:bg-gray-50 cursor-pointer">
            <input
              type="checkbox"
              bind:group={preferencies_dies}
              value={day.code}
              class="mr-3 h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300 rounded"
            />
            <span class="text-sm font-medium text-gray-900">{day.name}</span>
          </label>
        {/each}
      </div>
      <p class="mt-2 text-xs text-gray-600">
        ✅ Marca els dies que pots jugar. Si no marques res, tots els dies estan bé.
      </p>
    </div>

    <!-- Hores que SÍ pots jugar -->
    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 mb-3">
        Hores que SÍ pots jugar
      </label>
      <p class="text-sm text-gray-500 mb-3">Selecciona les hores que pots i vols jugar. Si no selecciones cap hora, podràs jugar a qualsevol hora disponible.</p>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        {#each CLUB_HOURS as hora}
          <label class="flex items-center p-3 border rounded-lg hover:bg-gray-50 cursor-pointer">
            <input
              type="checkbox"
              bind:group={preferencies_hores}
              value={hora}
              class="mr-3 h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300 rounded"
            />
            <span class="text-sm font-medium text-gray-900">{hora}</span>
          </label>
        {/each}
      </div>
      <p class="mt-2 text-xs text-gray-600">
        ✅ Marca les hores que pots jugar. Si no marques res, totes les hores estan bé.
      </p>
    </div>

    <!-- Restriccions especials -->
    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        Observacions o períodes especials
      </label>
      <textarea
        bind:value={restriccions_especials}
        rows="4"
        placeholder="Exemple: Del 20 al 27 de desembre no puc jugar per vacances. O prefereixo no jugar els dilluns al matí..."
        class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
      ></textarea>
      <p class="mt-1 text-xs text-gray-600">
        Escriu aquí qualsevol període específic que no puguis jugar o altres observacions
      </p>
    </div>

    <!-- Resum actual -->
    {#if preferencies_dies.length > 0 || preferencies_hores.length > 0 || restriccions_especials}
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
        <h4 class="font-medium text-yellow-900 mb-2">📋 Resum de les teves restriccions:</h4>
        <div class="text-sm text-yellow-800 space-y-1">
          {#if preferencies_dies.length > 0}
            <p><strong>Dies disponibles:</strong> {preferencies_dies.map(d => CLUB_DAYS.find(day => day.code === d)?.name).join(', ')}</p>
          {/if}
          {#if preferencies_hores.length > 0}
            <p><strong>Hores disponibles:</strong> {preferencies_hores.join(', ')}</p>
          {/if}
          {#if restriccions_especials}
            <p><strong>Observacions:</strong> {restriccions_especials}</p>
          {/if}
          {#if preferencies_dies.length === 0 && preferencies_hores.length === 0 && !restriccions_especials}
            <p><strong>✅ Cap restricció:</strong> Tots els dies i hores van bé</p>
          {/if}
        </div>
      </div>
    {/if}

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