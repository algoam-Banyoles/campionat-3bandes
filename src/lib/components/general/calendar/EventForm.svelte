<!-- src/lib/components/calendar/EventForm.svelte -->
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { refreshCalendarData } from '$lib/stores/calendar';

  export let isOpen = false;
  export let editingEvent: any = null;

  const dispatch = createEventDispatcher<{
    close: void;
    success: void;
  }>();

  let form = {
    titol: '',
    descripcio: '',
    data_inici: '',
    hora_inici: '',
    data_fi: '',
    hora_fi: '',
    tipus: 'general',
    visible_per_tots: true
  };

  let loading = false;
  let error: string | null = null;

  // Tipus d'esdeveniments disponibles
  const tipusOpcions = [
    { value: 'general', label: 'General' },
    { value: 'torneig', label: 'Torneig' },
    { value: 'social', label: 'Social' },
    { value: 'manteniment', label: 'Manteniment' }
  ];

  // Quan s'obre el modal, inicialitzar el formulari
  $: if (isOpen) {
    if (editingEvent) {
      // Mode edició
      const startDate = new Date(editingEvent.data_inici);
      const endDate = editingEvent.data_fi ? new Date(editingEvent.data_fi) : null;
      
      form = {
        titol: editingEvent.titol,
        descripcio: editingEvent.descripcio || '',
        data_inici: startDate.toISOString().split('T')[0],
        hora_inici: startDate.toTimeString().slice(0, 5),
        data_fi: endDate ? endDate.toISOString().split('T')[0] : '',
        hora_fi: endDate ? endDate.toTimeString().slice(0, 5) : '',
        tipus: editingEvent.tipus,
        visible_per_tots: editingEvent.visible_per_tots
      };
    } else {
      // Mode creació
      const now = new Date();
      form = {
        titol: '',
        descripcio: '',
        data_inici: now.toISOString().split('T')[0],
        hora_inici: '10:00',
        data_fi: '',
        hora_fi: '',
        tipus: 'general',
        visible_per_tots: true
      };
    }
    error = null;
  }

  async function handleSubmit() {
    loading = true;
    error = null;

    try {
      // Validacions
      if (!form.titol.trim()) {
        throw new Error('El títol és obligatori');
      }
      if (!form.data_inici) {
        throw new Error('La data d\'inici és obligatòria');
      }

      // Construir dates
      const dataInici = new Date(`${form.data_inici}T${form.hora_inici || '00:00'}:00`);
      let dataFi = null;
      
      if (form.data_fi && form.hora_fi) {
        dataFi = new Date(`${form.data_fi}T${form.hora_fi}:00`);
        
        if (dataFi <= dataInici) {
          throw new Error('La data de fi ha de ser posterior a la d\'inici');
        }
      }

      const eventData = {
        titol: form.titol.trim(),
        descripcio: form.descripcio.trim() || null,
        data_inici: dataInici.toISOString(),
        data_fi: dataFi?.toISOString() || null,
        tipus: form.tipus,
        visible_per_tots: form.visible_per_tots
      };

      if (editingEvent) {
        // Actualitzar esdeveniment existent
        const { error: updateError } = await supabase
          .from('esdeveniments_club')
          .update(eventData)
          .eq('id', editingEvent.id);
        
        if (updateError) throw updateError;
      } else {
        // Crear nou esdeveniment
        const { error: insertError } = await supabase
          .from('esdeveniments_club')
          .insert([eventData]);
        
        if (insertError) throw insertError;
      }

      // Refresh calendar data
      await refreshCalendarData();
      
      dispatch('success');
      dispatch('close');
    } catch (err: any) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  function handleClose() {
    dispatch('close');
  }
</script>

{#if isOpen}
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto p-4 sm:p-6">
      <div class="flex justify-between items-start mb-4 sm:mb-6">
        <h3 class="text-base sm:text-lg font-semibold">
          {editingEvent ? 'Editar Esdeveniment' : 'Nou Esdeveniment'}
        </h3>
        <button 
          on:click={handleClose}
          class="text-slate-400 hover:text-slate-600"
          disabled={loading}
          aria-label="Tancar formulari"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      {#if error}
        <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {error}
        </div>
      {/if}

      <form on:submit|preventDefault={handleSubmit} class="space-y-4">
        <!-- Títol -->
        <div>
          <label for="titol" class="block text-sm font-medium text-slate-700 mb-1">
            Títol *
          </label>
          <input
            id="titol"
            type="text"
            bind:value={form.titol}
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            required
            disabled={loading}
          />
        </div>

        <!-- Descripció -->
        <div>
          <label for="descripcio" class="block text-sm font-medium text-slate-700 mb-1">
            Descripció
          </label>
          <textarea
            id="descripcio"
            bind:value={form.descripcio}
            rows="3"
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          ></textarea>
        </div>

        <!-- Data i hora d'inici -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label for="data_inici" class="block text-sm font-medium text-slate-700 mb-1">
              Data d'inici *
            </label>
            <input
              id="data_inici"
              type="date"
              bind:value={form.data_inici}
              class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
              disabled={loading}
            />
          </div>
          <div>
            <label for="hora_inici" class="block text-sm font-medium text-slate-700 mb-1">
              Hora d'inici
            </label>
            <input
              id="hora_inici"
              type="time"
              bind:value={form.hora_inici}
              class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              disabled={loading}
            />
          </div>
        </div>

        <!-- Data i hora de fi -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label for="data_fi" class="block text-sm font-medium text-slate-700 mb-1">
              Data de fi
            </label>
            <input
              id="data_fi"
              type="date"
              bind:value={form.data_fi}
              class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              disabled={loading}
            />
          </div>
          <div>
            <label for="hora_fi" class="block text-sm font-medium text-slate-700 mb-1">
              Hora de fi
            </label>
            <input
              id="hora_fi"
              type="time"
              bind:value={form.hora_fi}
              class="w-full px-3 py-2 text-sm border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              disabled={loading}
            />
          </div>
        </div>

        <!-- Tipus -->
        <div>
          <label for="tipus" class="block text-sm font-medium text-slate-700 mb-1">
            Tipus
          </label>
          <select
            id="tipus"
            bind:value={form.tipus}
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={loading}
          >
            {#each tipusOpcions as opcio}
              <option value={opcio.value}>{opcio.label}</option>
            {/each}
          </select>
        </div>

        <!-- Visible per tots -->
        <div class="flex items-center">
          <input
            id="visible_per_tots"
            type="checkbox"
            bind:checked={form.visible_per_tots}
            class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-slate-300 rounded"
            disabled={loading}
          />
          <label for="visible_per_tots" class="ml-2 text-sm text-slate-700">
            Visible per tots els usuaris
          </label>
        </div>

        <!-- Botons -->
        <div class="flex flex-col sm:flex-row justify-end gap-3 pt-4 sm:pt-6">
          <button
            type="button"
            on:click={handleClose}
            class="w-full sm:w-auto px-4 py-2 text-slate-600 border border-slate-300 rounded-md hover:bg-slate-50 transition-colors order-2 sm:order-1"
            disabled={loading}
          >
            Cancel·lar
          </button>
          <button
            type="submit"
            class="w-full sm:w-auto px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed order-1 sm:order-2"
            disabled={loading}
          >
            {#if loading}
              <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white inline" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            {/if}
            {editingEvent ? 'Actualitzar' : 'Crear'} Esdeveniment
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}