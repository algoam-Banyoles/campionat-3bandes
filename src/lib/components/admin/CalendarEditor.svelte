<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError } from '$lib/ui/alerts';

  const dispatch = createEventDispatcher();

  export let eventId: string = '';
  export let categories: any[] = [];

  let matches: any[] = [];
  let loading = true;
  let error: string | null = null;
  let successMessage: string | null = null;

  // Filtres
  let selectedCategory = '';
  let selectedEstat = '';
  let selectedDate = '';

  // Edició
  let editingMatch: any = null;
  let editForm = {
    data_programada: '',
    hora_inici: '',
    taula_assignada: null,
    estat: 'generat',
    observacions_junta: ''
  };

  // Estats disponibles
  const estatOptions = [
    { value: 'generat', label: 'Generat', color: 'bg-gray-100 text-gray-800' },
    { value: 'validat', label: 'Validat', color: 'bg-blue-100 text-blue-800' },
    { value: 'reprogramada', label: 'Reprogramada', color: 'bg-yellow-100 text-yellow-800' },
    { value: 'jugada', label: 'Jugada', color: 'bg-green-100 text-green-800' },
    { value: 'cancel·lada', label: 'Cancel·lada', color: 'bg-red-100 text-red-800' },
    { value: 'pendent_programar', label: 'Pendent programar', color: 'bg-orange-100 text-orange-800' }
  ];

  // Carregar partits quan canvia l'event
  $: if (eventId) {
    loadMatches();
  }

  // Filtrar partits
  $: filteredMatches = matches.filter(match => {
    if (selectedCategory && match.categoria_id !== selectedCategory) return false;
    if (selectedEstat && match.estat !== selectedEstat) return false;
    if (selectedDate) {
      const matchDate = new Date(match.data_programada).toISOString().split('T')[0];
      if (matchDate !== selectedDate) return false;
    }
    return true;
  });

  // Agrupar per categoria
  $: matchesByCategory = groupByCategory(filteredMatches);

  async function loadMatches() {
    if (!eventId) return;

    loading = true;
    error = null;

    try {
      const { data, error: matchError } = await supabase
        .from('calendari_partides')
        .select(`
          *,
          categories!inner (
            nom,
            ordre_categoria
          ),
          jugador1:players!calendari_partides_jugador1_id_fkey (
            nom,
            numero_soci,
            socis!players_numero_soci_fkey (
              nom,
              cognoms
            )
          ),
          jugador2:players!calendari_partides_jugador2_id_fkey (
            nom,
            numero_soci,
            socis!players_numero_soci_fkey (
              nom,
              cognoms
            )
          )
        `)
        .eq('event_id', eventId)
        .order('data_programada', { ascending: true });

      if (matchError) throw matchError;

      matches = data || [];
      console.log('Loaded matches:', matches.length);

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }

  function groupByCategory(matches: any[]) {
    const groups = new Map();

    matches.forEach(match => {
      const categoryId = match.categoria_id;
      if (!groups.has(categoryId)) {
        groups.set(categoryId, []);
      }
      groups.get(categoryId).push(match);
    });

    // Ordenar per ordre de categoria
    const sortedEntries = Array.from(groups.entries()).sort(([aId], [bId]) => {
      const aCategory = categories.find(c => c.id === aId);
      const bCategory = categories.find(c => c.id === bId);
      return (aCategory?.ordre_categoria || 0) - (bCategory?.ordre_categoria || 0);
    });

    return new Map(sortedEntries);
  }

  function getCategoryName(categoryId: string) {
    const category = categories.find(c => c.id === categoryId);
    return category?.nom || 'Categoria desconeguda';
  }

  function getEstatStyle(estat: string) {
    const option = estatOptions.find(opt => opt.value === estat);
    return option?.color || 'bg-gray-100 text-gray-800';
  }

  function formatDate(dateString: string) {
    if (!dateString) return 'No programada';
    try {
      return new Date(dateString).toLocaleDateString('ca-ES', {
        weekday: 'short',
        day: 'numeric',
        month: 'short'
      });
    } catch (e) {
      return 'Data invàlida';
    }
  }

  function formatTime(timeString: string) {
    if (!timeString) return '';
    return timeString.substring(0, 5); // HH:MM
  }

  async function startEditing(match: any) {
    editingMatch = match;

    // Preparar formulari
    editForm = {
      data_programada: match.data_programada ?
        new Date(match.data_programada).toISOString().split('T')[0] : '',
      hora_inici: match.hora_inici || '',
      taula_assignada: match.taula_assignada,
      estat: match.estat,
      observacions_junta: match.observacions_junta || ''
    };
  }

  function cancelEditing() {
    editingMatch = null;
    editForm = {
      data_programada: '',
      hora_inici: '',
      taula_assignada: null,
      estat: 'generat',
      observacions_junta: ''
    };
  }

  async function saveMatch() {
    if (!editingMatch) return;

    try {
      const updates: any = {
        estat: editForm.estat,
        taula_assignada: editForm.taula_assignada,
        observacions_junta: editForm.observacions_junta || null
      };

      // Només actualitzar data/hora si estan plenes
      if (editForm.data_programada && editForm.hora_inici) {
        updates.data_programada = editForm.data_programada + 'T' + editForm.hora_inici + ':00';
        updates.hora_inici = editForm.hora_inici;
      } else if (editForm.data_programada || editForm.hora_inici) {
        // Si només un dels camps està ple, netejar tots dos
        updates.data_programada = null;
        updates.hora_inici = null;
      }

      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update(updates)
        .eq('id', editingMatch.id);

      if (updateError) throw updateError;

      successMessage = 'Partit actualitzat correctament';
      setTimeout(() => successMessage = null, 3000);

      // Recarregar dades
      await loadMatches();
      cancelEditing();

    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function deleteMatch(matchId: string) {
    if (!confirm('Estàs segur que vols eliminar aquest partit?')) return;

    try {
      const { error: deleteError } = await supabase
        .from('calendari_partides')
        .delete()
        .eq('id', matchId);

      if (deleteError) throw deleteError;

      successMessage = 'Partit eliminat correctament';
      setTimeout(() => successMessage = null, 3000);

      await loadMatches();

    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function regenerateCalendar() {
    if (!confirm('Això eliminarà tots els partits existents i generarà un nou calendari. Continuar?')) return;

    dispatch('regenerateCalendar');
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="flex justify-between items-center mb-4">
      <h3 class="text-lg font-medium text-gray-900 flex items-center">
        <span class="mr-2">📅</span> Editor de Calendari
      </h3>
      <button
        on:click={regenerateCalendar}
        class="px-4 py-2 bg-red-600 text-white text-sm rounded hover:bg-red-700"
      >
        Regenerar Calendari
      </button>
    </div>

    <!-- Filtres -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Categoria</label>
        <select
          bind:value={selectedCategory}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">Totes les categories</option>
          {#each categories.sort((a, b) => a.ordre_categoria - b.ordre_categoria) as category}
            <option value={category.id}>{category.nom}</option>
          {/each}
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Estat</label>
        <select
          bind:value={selectedEstat}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">Tots els estats</option>
          {#each estatOptions as option}
            <option value={option.value}>{option.label}</option>
          {/each}
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Data</label>
        <input
          type="date"
          bind:value={selectedDate}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div class="flex items-end">
        <button
          on:click={() => { selectedCategory = ''; selectedEstat = ''; selectedDate = ''; }}
          class="px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700"
        >
          Netejar Filtres
        </button>
      </div>
    </div>
  </div>

  <!-- Missatges -->
  {#if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4">
      <div class="text-red-800">{error}</div>
    </div>
  {/if}

  {#if successMessage}
    <div class="bg-green-50 border border-green-200 rounded-lg p-4">
      <div class="text-green-800">{successMessage}</div>
    </div>
  {/if}

  <!-- Loading -->
  {#if loading}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant calendari...</p>
    </div>
  {:else if matches.length === 0}
    <div class="bg-white border border-gray-200 rounded-lg p-8 text-center">
      <div class="text-gray-500">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
        </svg>
        <p class="mt-2">No hi ha partits programats</p>
        <p class="text-sm">Genera un calendari primer</p>
      </div>
    </div>
  {:else}
    <!-- Resum -->
    <div class="bg-white border border-gray-200 rounded-lg p-4">
      <div class="grid grid-cols-2 md:grid-cols-6 gap-4 text-center">
        <div>
          <div class="text-2xl font-bold text-gray-900">{filteredMatches.length}</div>
          <div class="text-sm text-gray-600">Total</div>
        </div>
        {#each estatOptions as option}
          {@const count = filteredMatches.filter(m => m.estat === option.value).length}
          {#if count > 0}
            <div>
              <div class="text-2xl font-bold text-gray-900">{count}</div>
              <div class="text-sm text-gray-600">{option.label}</div>
            </div>
          {/if}
        {/each}
      </div>
    </div>

    <!-- Calendari per categories -->
    {#each Array.from(matchesByCategory.entries()) as [categoryId, categoryMatches]}
      <div class="bg-white border border-gray-200 rounded-lg p-6">
        <h4 class="text-lg font-medium text-gray-900 mb-4">
          {getCategoryName(categoryId)} ({categoryMatches.length} partits)
        </h4>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Data</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Hora</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Taula</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Enfrontament</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estat</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Accions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              {#each categoryMatches as match}
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {formatDate(match.data_programada)}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {formatTime(match.hora_inici)}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {match.taula_assignada ? `Taula ${match.taula_assignada}` : 'No assignada'}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <div class="flex flex-col">
                      <span class="font-medium">
                        {match.jugador1?.socis?.nom || match.jugador1?.nom || 'Jugador 1'}
                        {match.jugador1?.socis?.cognoms || ''}
                      </span>
                      <span class="text-xs text-gray-500">vs</span>
                      <span class="font-medium">
                        {match.jugador2?.socis?.nom || match.jugador2?.nom || 'Jugador 2'}
                        {match.jugador2?.socis?.cognoms || ''}
                      </span>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getEstatStyle(match.estat)}">
                      {estatOptions.find(opt => opt.value === match.estat)?.label || match.estat}
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                    <button
                      on:click={() => startEditing(match)}
                      class="text-blue-600 hover:text-blue-900"
                    >
                      Editar
                    </button>
                    <button
                      on:click={() => deleteMatch(match.id)}
                      class="text-red-600 hover:text-red-900"
                    >
                      Eliminar
                    </button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/each}
  {/if}
</div>

<!-- Modal d'edició -->
{#if editingMatch}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <h3 class="text-lg font-medium text-gray-900 mb-4">
        Editar Partit
      </h3>

      <form on:submit|preventDefault={saveMatch} class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Data</label>
          <input
            type="date"
            bind:value={editForm.data_programada}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Hora</label>
          <input
            type="time"
            bind:value={editForm.hora_inici}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Taula</label>
          <input
            type="number"
            min="1"
            max="10"
            bind:value={editForm.taula_assignada}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Estat</label>
          <select
            bind:value={editForm.estat}
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            {#each estatOptions as option}
              <option value={option.value}>{option.label}</option>
            {/each}
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Observacions de la Junta</label>
          <textarea
            bind:value={editForm.observacions_junta}
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Observacions opcionals..."
          ></textarea>
        </div>

        <div class="flex justify-end space-x-3 pt-4">
          <button
            type="button"
            on:click={cancelEditing}
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
          {editingMatch.jugador1?.socis?.nom || editingMatch.jugador1?.nom} {editingMatch.jugador1?.socis?.cognoms || ''} vs {editingMatch.jugador2?.socis?.nom || editingMatch.jugador2?.nom} {editingMatch.jugador2?.socis?.cognoms || ''}
        </div>
      </div>
    </div>
  </div>
{/if}