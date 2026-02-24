<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';


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

  // Variables per al modal d'incompareixences
  let showIncompareixencaModal = false;
  let incompareixencaMatch: any = null;

  onMount(async () => {
    await loadActiveEvent();
  });

  async function loadActiveEvent() {
    try {
      // Load the single active social league event
      const { data: eventData, error: eventError } = await supabase
        .from('events')
        .select('*')
        .eq('actiu', true)
        .eq('tipus_competicio', 'lliga_social')
        .order('temporada', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (eventError) throw eventError;

      if (!eventData) {
        error = 'No hi ha cap campionat social actiu';
        return;
      }

      selectedEvent = eventData;

      // Load categories for the active event
      const { data: categoriesData, error: categoriesError } = await supabase
        .from('categories')
        .select('*')
        .eq('event_id', selectedEvent.id)
        .order('ordre_categoria');

      if (categoriesError) throw categoriesError;
      categories = categoriesData || [];

    } catch (e) {
      console.error('Error loading active event:', e);
      error = 'Error carregant el campionat actiu';
    }
  }

  async function selectCategory(category: any) {
    selectedCategory = category;

    // Reset dependent selections
    selectedMatch = null;
    calendarMatches = [];
    error = '';
    loading = true;

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
        .is('caramboles_jugador1', null)
        .order('data_programada');

      if (matchesError) throw matchesError;

      // Get all unique numero_soci values from matches
      const allNumerosSoci = new Set<number>();
      (matchesData || []).forEach(match => {
        if (match.jugador1?.numero_soci) allNumerosSoci.add(match.jugador1.numero_soci);
        if (match.jugador2?.numero_soci) allNumerosSoci.add(match.jugador2.numero_soci);
      });

      // Fetch all socis in ONE query instead of N queries
      const { data: socisData, error: socisError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .in('numero_soci', Array.from(allNumerosSoci));

      if (socisError) {
        console.warn('Error loading socis:', socisError);
      }

      // Create a lookup map for fast access
      const socisMap = new Map();
      (socisData || []).forEach(soci => {
        socisMap.set(soci.numero_soci, soci);
      });

      // Map matches with soci data using the lookup map (no async needed)
      const matchesWithSocis = (matchesData || []).map(match => ({
        ...match,
        soci1: socisMap.get(match.jugador1?.numero_soci) || null,
        soci2: socisMap.get(match.jugador2?.numero_soci) || null
      }));

      calendarMatches = matchesWithSocis;
    } catch (e) {
      console.error('Error loading matches:', e);
      error = 'Error carregant les partides';
    } finally {
      loading = false;
    }
  }

  async function submitResult() {
    if (!selectedMatch) {
      error = 'Selecciona una partida';
      return;
    }

    // Empats permesos: 1 punt per cada jugador
    if (caramboles_jugador1 === 0 && caramboles_jugador2 === 0) {
      error = 'Introdueix les caramboles per ambdós jugadors';
      return;
    }

    loading = true;
    error = '';
    success = false;

    try {
      // For social league matches, store results directly in calendari_partides
      // This keeps social leagues separate from ranking championship
      console.log('🔍 Guardant resultat:', {
        match_id: selectedMatch.id,
        caramboles_j1: caramboles_jugador1,
        caramboles_j2: caramboles_jugador2,
        entrades: entrades
      });

      // Calcular punts segons el resultat
      let punts_j1 = 0;
      let punts_j2 = 0;

      if (caramboles_jugador1 > caramboles_jugador2) {
        punts_j1 = 2;  // Jugador 1 guanya
        punts_j2 = 0;
      } else if (caramboles_jugador2 > caramboles_jugador1) {
        punts_j1 = 0;
        punts_j2 = 2;  // Jugador 2 guanya
      } else {
        punts_j1 = 1;  // Empat
        punts_j2 = 1;
      }

      const { data: updateData, error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          caramboles_jugador1: caramboles_jugador1,
          caramboles_jugador2: caramboles_jugador2,
          entrades: entrades,  // Mantingut per compatibilitat
          entrades_jugador1: entrades,  // Ambdós jugadors tenen les mateixes entrades en partides normals
          entrades_jugador2: entrades,
          punts_jugador1: punts_j1,  // Punts calculats segons resultat
          punts_jugador2: punts_j2,
          data_joc: new Date().toISOString(),
          estat: 'jugada',
          validat_per: (await supabase.auth.getUser()).data.user?.id,
          data_validacio: new Date().toISOString(),
          observacions_junta: observacions
        })
        .eq('id', selectedMatch.id)
        .select();

      if (updateError) {
        console.error('❌ Error guardant a calendari_partides:', updateError);
        throw updateError;
      }

      console.log('✅ Resultat guardat correctament:', updateData);

      // Remove the match from the list instead of reloading everything
      // This is much faster and doesn't block the UI
      calendarMatches = calendarMatches.filter(m => m.id !== selectedMatch.id);

      // Reset form
      selectedMatch = null;
      caramboles_jugador1 = 0;
      caramboles_jugador2 = 0;
      entrades = 0;
      observacions = '';
      matchesCollapsed = false;

      success = true;

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

  function openIncompareixencaModal(match: any) {
    incompareixencaMatch = match;
    showIncompareixencaModal = true;
  }

  function closeIncompareixencaModal() {
    showIncompareixencaModal = false;
    incompareixencaMatch = null;
  }

  async function marcarIncompareixenca(jugadorQueFalta: 1 | 2) {
    if (!incompareixencaMatch) return;

    const jugadorNom = jugadorQueFalta === 1
      ? `${incompareixencaMatch.soci1?.nom} ${incompareixencaMatch.soci1?.cognoms}`
      : `${incompareixencaMatch.soci2?.nom} ${incompareixencaMatch.soci2?.cognoms}`;

    const confirmation = confirm(
      `Estàs segur que vols marcar incompareixença de ${jugadorNom}?\n\n` +
      `Això assignarà:\n` +
      `- Jugador present: 2 punts, 0 entrades\n` +
      `- Jugador absent: 0 punts, 50 entrades\n\n` +
      `Si el jugador té 2 incompareixences, serà eliminat del campionat.`
    );

    if (!confirmation) return;

    try {
      loading = true;
      error = '';
      success = false;

      const { data, error: rpcError } = await supabase
        .rpc('registrar_incompareixenca', {
          p_partida_id: incompareixencaMatch.id,
          p_jugador_que_falta: jugadorQueFalta
        });

      if (rpcError) throw rpcError;

      closeIncompareixencaModal();

      // Reload matches
      const categoryToReload = selectedCategory;
      if (categoryToReload) {
        await selectCategory(categoryToReload);
      }

      // Show different messages based on result
      if (data.jugador_eliminat) {
        alert(
          `⚠️ INCOMPAREIXENÇA REGISTRADA\n\n` +
          `El jugador ${jugadorNom} té ${data.incompareixences} incompareixences.\n` +
          `HA ESTAT ELIMINAT DEL CAMPIONAT.\n\n` +
          `Totes les seves partides pendents han estat anul·lades.`
        );
      } else {
        alert(
          `✅ INCOMPAREIXENÇA REGISTRADA\n\n` +
          `El jugador ${jugadorNom} té ${data.incompareixences} incompareixença(es).\n` +
          `Partida registrada amb els punts corresponents.`
        );
      }

      success = true;
      setTimeout(() => {
        success = false;
      }, 3000);

    } catch (err) {
      console.error('Error registrant incompareixença:', err);
      error = 'Error registrant la incompareixença: ' + (err as any)?.message;
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Resultats Campionats Socials - Admin</title>
</svelte:head>

<div class="container mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold text-gray-900 mb-8">Pujar Resultats - Campionats Socials</h1>

  <!-- Active Event Info and Category Selection -->
  {#if selectedEvent}
    <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
      <div class="mb-4">
        <h2 class="text-xl font-semibold text-gray-900 mb-1">
          {selectedEvent.modalitat?.toUpperCase()} {selectedEvent.temporada}
        </h2>
        <p class="text-sm text-gray-600">{selectedEvent.nom}</p>
      </div>

      {#if categories.length > 0}
        <div>
          <div class="block text-sm font-medium text-gray-700 mb-3">
            Selecciona Categoria
          </div>
          <div class="flex gap-2 flex-wrap">
            {#each categories as category}
              <button
                type="button"
                on:click={() => selectCategory(category)}
                class="px-4 py-2 rounded-lg transition-colors font-medium"
                class:bg-blue-600={selectedCategory?.id === category.id}
                class:text-white={selectedCategory?.id === category.id}
                class:shadow-lg={selectedCategory?.id === category.id}
                class:bg-gray-100={selectedCategory?.id !== category.id}
                class:text-gray-700={selectedCategory?.id !== category.id}
                class:hover:bg-gray-200={selectedCategory?.id !== category.id}
              >
                {category.nom}
                <span class="text-xs ml-1 opacity-75">
                  ({category.distancia_caramboles})
                </span>
              </button>
            {/each}
          </div>
        </div>
      {/if}
    </div>
  {:else if error}
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6 mb-6">
      <p class="text-yellow-800">{error}</p>
    </div>
  {/if}

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
              <div class="flex items-center space-x-4 flex-1">
                <input
                  type="radio"
                  name="match"
                  checked={selectedMatch?.id === match.id}
                  class="h-4 w-4 text-blue-600"
                />
                <div class="flex-1">
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
              <div class="flex items-center gap-2">
                {#if match.taula_assignada}
                  <span class="px-2 py-1 bg-gray-100 text-gray-700 text-sm rounded">
                    Taula {match.taula_assignada}
                  </span>
                {/if}
                <button
                  on:click|stopPropagation={() => openIncompareixencaModal(match)}
                  class="px-3 py-1 text-red-600 hover:text-red-900 hover:bg-red-50 text-sm font-medium border border-red-300 rounded transition-colors"
                  title="Marcar incompareixença"
                >
                  ⚠️ Incompareixença
                </button>
              </div>
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

      <!-- Result Preview -->
      {#if caramboles_jugador1 > 0 || caramboles_jugador2 > 0}
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          {#if caramboles_jugador1 === caramboles_jugador2}
            <h4 class="font-medium text-yellow-900 mb-2">⚖️ Empat!</h4>
            <p class="text-yellow-800">
              Ambdós jugadors obtenen 1 punt
            </p>
          {:else}
            <h4 class="font-medium text-blue-900 mb-2">🏆 Guanyador:</h4>
            <p class="text-blue-800">
              {caramboles_jugador1 > caramboles_jugador2
                ? `${selectedMatch.soci1?.nom} ${selectedMatch.soci1?.cognoms}`
                : `${selectedMatch.soci2?.nom} ${selectedMatch.soci2?.cognoms}`}
            </p>
            <p class="text-sm text-blue-700">
              Guanyador: 2 punts • Perdedor: 0 punts
            </p>
          {/if}
          <p class="text-sm text-blue-700 mt-2">
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
          disabled={loading || !selectedMatch || (caramboles_jugador1 === 0 && caramboles_jugador2 === 0)}
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

<!-- Modal d'Incompareixença -->
{#if showIncompareixencaModal && incompareixencaMatch}
  <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex items-center justify-center p-4">
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
            <!-- Jugador 1 -->
            <button
              on:click={() => marcarIncompareixenca(1)}
              class="p-6 border-2 border-red-300 rounded-lg hover:bg-red-50 hover:border-red-500 transition-colors"
              disabled={loading}
            >
              <div class="text-center">
                <div class="text-3xl mb-2">👤</div>
                <div class="font-bold text-lg text-gray-900 mb-1">Jugador 1</div>
                <div class="text-base text-gray-700">
                  {incompareixencaMatch.soci1?.nom} {incompareixencaMatch.soci1?.cognoms}
                </div>
                <div class="mt-3 text-sm text-red-600 font-medium">
                  ⚠️ Marcar incompareixença
                </div>
              </div>
            </button>

            <!-- Jugador 2 -->
            <button
              on:click={() => marcarIncompareixenca(2)}
              class="p-6 border-2 border-red-300 rounded-lg hover:bg-red-50 hover:border-red-500 transition-colors"
              disabled={loading}
            >
              <div class="text-center">
                <div class="text-3xl mb-2">👤</div>
                <div class="font-bold text-lg text-gray-900 mb-1">Jugador 2</div>
                <div class="text-base text-gray-700">
                  {incompareixencaMatch.soci2?.nom} {incompareixencaMatch.soci2?.cognoms}
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
            on:click={closeIncompareixencaModal}
            class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 font-medium"
            disabled={loading}
          >
            ❌ Cancel·lar
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
