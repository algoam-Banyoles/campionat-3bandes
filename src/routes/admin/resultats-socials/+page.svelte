<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  let events: any[] = [];
  let selectedEvent: any = null;
  let categories: any[] = [];
  let selectedCategory: any = null;
  let players: any[] = [];
  let calendarMatches: any[] = [];

  // Form data
  let selectedMatch: any = null;
  let caramboles_jugador1 = 0;
  let caramboles_jugador2 = 0;
  let entrades = 0;
  let observacions = '';
  let loading = false;
  let success = false;
  let error = '';
  let matchesCollapsed = false;

  onMount(async () => {
    await loadActiveEvents();
  });

  async function loadActiveEvents() {
    try {
      const { data, error } = await supabase
        .from('events')
        .select('*')
        .eq('actiu', true)
        .eq('tipus_competicio', 'lliga_social')
        .order('temporada', { ascending: false });

      if (error) throw error;
      events = data || [];
    } catch (e) {
      console.error('Error loading events:', e);
      error = 'Error carregant els campionats';
    }
  }

  async function onEventSelected() {
    if (!selectedEvent) return;

    try {
      // Load categories for selected event
      const { data: categoriesData, error: categoriesError } = await supabase
        .from('categories')
        .select('*')
        .eq('event_id', selectedEvent.id)
        .order('nom');

      if (categoriesError) throw categoriesError;
      categories = categoriesData || [];

      // Reset dependent selections
      selectedCategory = null;
      players = [];
      calendarMatches = [];
      selectedMatch = null;
    } catch (e) {
      console.error('Error loading categories:', e);
      error = 'Error carregant les categories';
    }
  }

  async function onCategorySelected() {
    if (!selectedCategory) return;

    try {
      // Load calendar matches for selected category that are not yet played
      const { data: matchesData, error: matchesError } = await supabase
        .from('calendari_partides')
        .select(`
          *,
          jugador1:players!calendari_partides_jugador1_id_fkey(id, numero_soci),
          jugador2:players!calendari_partides_jugador2_id_fkey(id, numero_soci)
        `)
        .eq('event_id', selectedEvent.id)
        .eq('categoria_id', selectedCategory.id)
        .is('match_id', null)
        .order('data_programada');

      if (matchesError) throw matchesError;

      // Get soci names for each match
      const matchesWithSocis = await Promise.all(
        (matchesData || []).map(async (match) => {
          const [soci1Result, soci2Result] = await Promise.all([
            supabase.from('socis').select('nom, cognoms').eq('numero_soci', match.jugador1?.numero_soci).single(),
            supabase.from('socis').select('nom, cognoms').eq('numero_soci', match.jugador2?.numero_soci).single()
          ]);

          return {
            ...match,
            soci1: soci1Result.data,
            soci2: soci2Result.data
          };
        })
      );

      calendarMatches = matchesWithSocis;
    } catch (e) {
      console.error('Error loading matches:', e);
      error = 'Error carregant les partides';
    }
  }

  async function submitResult() {
    if (!selectedMatch) {
      error = 'Selecciona una partida';
      return;
    }

    if (caramboles_jugador1 === caramboles_jugador2) {
      error = 'No es poden empatar en una partida de campionat social';
      return;
    }

    loading = true;
    error = '';

    try {
      // For social league matches, store results directly in calendari_partides
      // This keeps social leagues separate from ranking championship
      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          caramboles_jugador1: caramboles_jugador1,
          caramboles_jugador2: caramboles_jugador2,
          entrades: entrades,
          data_joc: new Date().toISOString(),
          estat: 'validat',
          validat_per: (await supabase.auth.getUser()).data.user?.id,
          data_validacio: new Date().toISOString(),
          observacions_junta: observacions
        })
        .eq('id', selectedMatch.id);

      if (updateError) throw updateError;

      success = true;

      // Reset form
      selectedMatch = null;
      caramboles_jugador1 = 0;
      caramboles_jugador2 = 0;
      entrades = 0;
      observacions = '';

      // Reload matches
      await onCategorySelected();

      setTimeout(() => {
        success = false;
      }, 3000);

    } catch (e) {
      console.error('Error submitting result:', e);
      error = 'Error guardant el resultat';
    } finally {
      loading = false;
    }
  }

  function resetForm() {
    selectedMatch = null;
    caramboles_jugador1 = 0;
    caramboles_jugador2 = 0;
    entrades = 0;
    observacions = '';
    error = '';
    success = false;
    matchesCollapsed = false;
  }

  function selectMatch(match: any) {
    selectedMatch = match;
    matchesCollapsed = true;
  }

  function toggleMatchesCollapsed() {
    matchesCollapsed = !matchesCollapsed;
  }
</script>

<svelte:head>
  <title>Resultats Campionats Socials - Admin</title>
</svelte:head>

<div class="container mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold text-gray-900 mb-8">Pujar Resultats - Campionats Socials</h1>

  <!-- Event Selection -->
  <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
    <h2 class="text-xl font-semibold text-gray-900 mb-4">Selecciona Campionat</h2>
    
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <label for="event" class="block text-sm font-medium text-gray-700 mb-2">
          Campionat Actiu
        </label>
        <select 
          id="event"
          bind:value={selectedEvent}
          on:change={onEventSelected}
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
        >
          <option value={null}>Selecciona un campionat...</option>
          {#each events as event}
            <option value={event}>
              {event.modalitat?.toUpperCase()} {event.temporada} - {event.nom}
            </option>
          {/each}
        </select>
      </div>

      {#if selectedEvent}
        <div>
          <label for="category" class="block text-sm font-medium text-gray-700 mb-2">
            Categoria
          </label>
          <select 
            id="category"
            bind:value={selectedCategory}
            on:change={onCategorySelected}
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
          >
            <option value={null}>Selecciona una categoria...</option>
            {#each categories as category}
              <option value={category}>
                {category.nom} ({category.distancia_caramboles} caramboles)
              </option>
            {/each}
          </select>
        </div>
      {/if}
    </div>
  </div>

  <!-- Match Selection -->
  {#if selectedCategory && calendarMatches.length > 0}
    <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xl font-semibold text-gray-900">
          Partides Pendents
          <span class="text-sm font-normal text-gray-600 ml-2">
            • Total partides: {calendarMatches.length}
          </span>
          {#if selectedMatch}
            <span class="text-sm font-normal text-gray-600 ml-2">
              • Seleccionada: {selectedMatch.soci1?.nom} {selectedMatch.soci1?.cognoms} vs {selectedMatch.soci2?.nom} {selectedMatch.soci2?.cognoms}
            </span>
          {/if}
        </h2>
        
        {#if selectedMatch}
          <button 
            type="button"
            on:click={toggleMatchesCollapsed}
            class="flex items-center px-3 py-1 text-sm text-gray-600 hover:text-gray-800 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            {#if matchesCollapsed}
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
              Mostrar llista
            {:else}
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
              </svg>
              Amagar llista
            {/if}
          </button>
        {/if}
      </div>
      
      {#if !matchesCollapsed}
        <div class="space-y-3">
          {#each calendarMatches as match}
            <div 
              class="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50 transition-colors {selectedMatch?.id === match.id ? 'bg-blue-50 border-blue-300' : ''}"
              on:click={() => selectMatch(match)}
              on:keydown={(e) => e.key === 'Enter' && selectMatch(match)}
              role="button"
              tabindex="0"
            >
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <input 
                  type="radio" 
                  name="match" 
                  checked={selectedMatch?.id === match.id}
                  class="h-4 w-4 text-blue-600"
                />
                <div>
                  <div class="font-medium text-gray-900">
                    {match.soci1?.nom} {match.soci1?.cognoms} vs {match.soci2?.nom} {match.soci2?.cognoms}
                  </div>
                  {#if match.data_programada}
                    <div class="text-sm text-gray-500">
                      Programada: {new Date(match.data_programada).toLocaleDateString('ca-ES')}
                    </div>
                  {/if}
                </div>
              </div>
              {#if match.taula_assignada}
                <span class="px-2 py-1 bg-gray-100 text-gray-700 text-sm rounded">
                  Taula {match.taula_assignada}
                </span>
              {/if}
            </div>
          </div>
        {/each}
        </div>
      {:else}
        <div class="text-center py-4">
          <p class="text-sm text-gray-500">Llista de partides col·lapsada</p>
        </div>
      {/if}
    </div>
  {:else if selectedCategory && calendarMatches.length === 0}
    <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
      <p class="text-center text-gray-500">No hi ha partides pendents per aquesta categoria</p>
    </div>
  {/if}

  <!-- Result Form -->
  {#if selectedMatch}
    <div class="bg-white border border-gray-200 rounded-lg p-6">
      <h2 class="text-xl font-semibold text-gray-900 mb-4">Resultat de la Partida</h2>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
        <!-- Jugador 1 -->
        <div class="bg-gray-50 rounded-lg p-4">
          <h3 class="font-semibold text-gray-900 mb-3">
            {selectedMatch.soci1?.nom} {selectedMatch.soci1?.cognoms}
          </h3>
          <div>
            <label for="caramboles_j1" class="block text-sm font-medium text-gray-700 mb-1">
              Caramboles
            </label>
            <input
              id="caramboles_j1"
              type="number"
              bind:value={caramboles_jugador1}
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>

        <!-- Jugador 2 -->
        <div class="bg-gray-50 rounded-lg p-4">
          <h3 class="font-semibold text-gray-900 mb-3">
            {selectedMatch.soci2?.nom} {selectedMatch.soci2?.cognoms}
          </h3>
          <div>
            <label for="caramboles_j2" class="block text-sm font-medium text-gray-700 mb-1">
              Caramboles
            </label>
            <input
              id="caramboles_j2"
              type="number"
              bind:value={caramboles_jugador2}
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>
      </div>

      <!-- Additional Fields -->
      <div class="mb-6">
        <label for="entrades" class="block text-sm font-medium text-gray-700 mb-1">
          Entrades
        </label>
        <input
          id="entrades"
          type="number"
          bind:value={entrades}
          min="0"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
        />
      </div>

      <div class="mb-6">
        <label for="observacions" class="block text-sm font-medium text-gray-700 mb-1">
          Observacions
        </label>
        <textarea 
          id="observacions"
          bind:value={observacions}
          rows="3"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
          placeholder="Observacions opcionals sobre la partida..."
        ></textarea>
      </div>

      <!-- Winner Preview -->
      {#if caramboles_jugador1 !== caramboles_jugador2 && (caramboles_jugador1 > 0 || caramboles_jugador2 > 0)}
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <h4 class="font-medium text-blue-900 mb-2">Guanyador:</h4>
          <p class="text-blue-800">
            {caramboles_jugador1 > caramboles_jugador2 
              ? `${selectedMatch.soci1?.nom} ${selectedMatch.soci1?.cognoms}` 
              : `${selectedMatch.soci2?.nom} ${selectedMatch.soci2?.cognoms}`}
          </p>
          <p class="text-sm text-blue-700">
            Resultat: {caramboles_jugador1} - {caramboles_jugador2}
          </p>
        </div>
      {/if}

      <!-- Submit Button -->
      <div class="flex justify-between items-center">
        <div class="flex space-x-3">
          {#if selectedMatch}
            <button 
              type="button"
              on:click={() => { selectedMatch = null; matchesCollapsed = false; }}
              class="px-4 py-2 text-blue-700 bg-blue-100 border border-blue-300 rounded-md hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              Canviar Partida
            </button>
          {/if}
          
          <button 
            type="button"
            on:click={resetForm}
            class="px-4 py-2 text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            Cancel·lar
          </button>
        </div>
        
        <button 
          type="button"
          on:click={submitResult}
          disabled={loading || !selectedMatch || caramboles_jugador1 === caramboles_jugador2}
          class="px-6 py-2 bg-blue-600 text-white font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {#if loading}
            <span class="inline-flex items-center">
              <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Guardant...
            </span>
          {:else}
            Guardar Resultat
          {/if}
        </button>
      </div>
    </div>
  {/if}

  <!-- Messages -->
  {#if success}
    <div class="mt-4 bg-green-50 border border-green-200 rounded-lg p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-green-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-green-800">
            Resultat guardat correctament!
          </h3>
        </div>
      </div>
    </div>
  {/if}

  {#if error}
    <div class="mt-4 bg-red-50 border border-red-200 rounded-lg p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-red-800">
            {error}
          </h3>
        </div>
      </div>
    </div>
  {/if}
</div>