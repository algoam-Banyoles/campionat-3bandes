<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import { showSuccess, showError } from '$lib/stores/toastStore';
  import { showConfirm } from '$lib/stores/confirmDialogStore';
  import { adminChecked } from '$lib/stores/adminAuth';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import { userId } from '$lib/stores/auth';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  function nomComplet(nom: string | null | undefined, cognoms: string | null | undefined): string {
    const raw = `${nom ?? ''} ${cognoms ?? ''}`.trim();
    return raw ? formatarNomJugador(raw) : '';
  }

  // Guard: només admins en vista admin. Un admin en vista "Jugador" tampoc hi entra.
  $: if ($adminChecked && !$effectiveIsAdmin) {
    goto('/campionats-socials');
  }

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
      // Paral·lelitzem: les dues queries són independents. La de partides ja
      // resol els socis via FK join, així estalviem una tercera RTT i la
      // construcció manual del map de lookup.
      const [inscriptionsRes, matchesRes] = await Promise.all([
        supabase
          .from('inscripcions')
          .select('soci_numero, estat_jugador, eliminat_per_incompareixences')
          .eq('event_id', selectedEvent.id)
          .eq('categoria_assignada_id', selectedCategory.id),
        supabase
          .from('calendari_partides')
          .select(
            '*, soci1:socis!calendari_partides_jugador1_soci_numero_fkey(numero_soci, nom, cognoms), soci2:socis!calendari_partides_jugador2_soci_numero_fkey(numero_soci, nom, cognoms)'
          )
          .eq('event_id', selectedEvent.id)
          .eq('categoria_id', selectedCategory.id)
          .is('match_id', null)
          .is('caramboles_jugador1', null)
          .order('data_programada')
      ]);

      if (inscriptionsRes.error) throw inscriptionsRes.error;
      if (matchesRes.error) throw matchesRes.error;

      const withdrawnNumbers = new Set<number>(
        (inscriptionsRes.data || [])
          .filter((item: any) => item.estat_jugador === 'retirat' || item.eliminat_per_incompareixences)
          .map((item: any) => item.soci_numero)
          .filter((numero: any) => typeof numero === 'number')
      );

      calendarMatches = (matchesRes.data || []).filter((match: any) => {
        if (withdrawnNumbers.size === 0) return true;
        return (
          !withdrawnNumbers.has(match.jugador1_soci_numero) &&
          !withdrawnNumbers.has(match.jugador2_soci_numero)
        );
      });
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

    if (entrades <= 0) {
      error = 'Les entrades han de ser majors que 0';
      return;
    }

    const distancia = selectedCategory?.distancia_caramboles;
    if (distancia != null) {
      if (caramboles_jugador1 > distancia) {
        error = `Les caramboles del jugador 1 (${caramboles_jugador1}) superen la distància de la categoria (${distancia})`;
        return;
      }
      if (caramboles_jugador2 > distancia) {
        error = `Les caramboles del jugador 2 (${caramboles_jugador2}) superen la distància de la categoria (${distancia})`;
        return;
      }
    }

    // Snapshot del que s'està guardant: així alliberem el formulari abans
    // d'esperar la xarxa i l'usuari pot començar el següent resultat.
    const matchToSave = selectedMatch;
    const c1 = caramboles_jugador1;
    const c2 = caramboles_jugador2;
    const ent = entrades;
    const obs = observacions;
    const uid = $userId;

    // Punts segons resultat
    let punts_j1 = 0;
    let punts_j2 = 0;
    if (c1 > c2) {
      punts_j1 = 2;
    } else if (c2 > c1) {
      punts_j2 = 2;
    } else {
      punts_j1 = 1;
      punts_j2 = 1;
    }

    // UI optimista: traiem la partida de la llista i resetejem el formulari
    // immediatament. Si la xarxa falla, fem rollback més avall.
    calendarMatches = calendarMatches.filter((m) => m.id !== matchToSave.id);
    selectedMatch = null;
    caramboles_jugador1 = 0;
    caramboles_jugador2 = 0;
    entrades = 0;
    observacions = '';
    matchesCollapsed = false;
    error = '';

    try {
      const now = new Date().toISOString();
      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update({
          caramboles_jugador1: c1,
          caramboles_jugador2: c2,
          entrades: ent,
          entrades_jugador1: ent,
          entrades_jugador2: ent,
          punts_jugador1: punts_j1,
          punts_jugador2: punts_j2,
          data_joc: now,
          estat: 'jugada',
          validat_per: uid,
          data_validacio: now,
          observacions_junta: obs
        })
        .eq('id', matchToSave.id);

      if (updateError) throw updateError;

      showSuccess('Resultat guardat correctament');
    } catch (e) {
      console.error('Error submitting result:', e);
      // Rollback: tornem la partida a la llista si encara no hi és
      if (!calendarMatches.some((m) => m.id === matchToSave.id)) {
        calendarMatches = [...calendarMatches, matchToSave].sort((a, b) => {
          const da: string = a.data_programada ?? '';
          const db: string = b.data_programada ?? '';
          return da.localeCompare(db);
        });
      }
      const nom1 = nomComplet(matchToSave.soci1?.nom, matchToSave.soci1?.cognoms);
      const nom2 = nomComplet(matchToSave.soci2?.nom, matchToSave.soci2?.cognoms);
      showError(`Error guardant ${nom1} vs ${nom2}. La partida torna a la llista.`, e);
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
    if (loading) return; // evita RPC concurrents
    if (!incompareixencaMatch) return;

    const jugadorNom = jugadorQueFalta === 1
      ? `${nomComplet(incompareixencaMatch.soci1?.nom, incompareixencaMatch.soci1?.cognoms)}`
      : `${nomComplet(incompareixencaMatch.soci2?.nom, incompareixencaMatch.soci2?.cognoms)}`;

    const confirmation = await showConfirm({
      title: 'Marcar incompareixença',
      message:
        `Marcar incompareixença de ${jugadorNom}?\n\n` +
        `Jugador present: 2 punts, 0 entrades\n` +
        `Jugador absent: 0 punts, 50 entrades\n\n` +
        `Amb 2 incompareixences, el jugador serà eliminat del campionat.`,
      severity: 'warning',
      confirmLabel: 'Marcar absent'
    });

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
        showError(
          `${jugadorNom} ha estat desqualificat (${data.incompareixences} incompareixences). Les partides pendents han estat anul·lades.`
        );
      } else {
        showSuccess(
          `Incompareixença registrada — ${jugadorNom} té ${data.incompareixences} incompareixença(es)`
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
  <title>Resultats pendents</title>
</svelte:head>

<div class="rp-root">
  <header class="rp-mast">
    <div class="editorial-eyebrow">Campionats socials · Administració</div>
    <h1 class="rp-title">Resultats pendents</h1>
    <p class="rp-sub">Pujar resultats de partides pendents i marcar incompareixences.</p>
  </header>

  <!-- Active Event Info and Category Selection -->
  {#if selectedEvent}
    <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
      <div class="mb-4">
        <h2 class="text-xl font-semibold text-gray-900 mb-1">
          {({'tres_bandes': '3 Bandes', 'lliure': 'Lliure', 'banda': 'Banda'}[selectedEvent.modalitat] ?? selectedEvent.modalitat)} {selectedEvent.temporada}
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
              • Seleccionada: {nomComplet(selectedMatch.soci1?.nom, selectedMatch.soci1?.cognoms)} vs {nomComplet(selectedMatch.soci2?.nom, selectedMatch.soci2?.cognoms)}
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
                    {nomComplet(match.soci1?.nom, match.soci1?.cognoms)} vs {nomComplet(match.soci2?.nom, match.soci2?.cognoms)}
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
            {nomComplet(selectedMatch.soci1?.nom, selectedMatch.soci1?.cognoms)}
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
            {nomComplet(selectedMatch.soci2?.nom, selectedMatch.soci2?.cognoms)}
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
                ? `${nomComplet(selectedMatch.soci1?.nom, selectedMatch.soci1?.cognoms)}`
                : `${nomComplet(selectedMatch.soci2?.nom, selectedMatch.soci2?.cognoms)}`}
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
                  {nomComplet(incompareixencaMatch.soci1?.nom, incompareixencaMatch.soci1?.cognoms)}
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
                  {nomComplet(incompareixencaMatch.soci2?.nom, incompareixencaMatch.soci2?.cognoms)}
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
</div>

<style>
  .rp-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .rp-mast {
    margin-bottom: 1.75rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .rp-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .rp-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }

  /* Overrides Tailwind dins .rp-root */
  .rp-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .rp-root :global(.bg-gray-50),
  .rp-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .rp-root :global(.bg-gray-500),
  .rp-root :global(.bg-gray-600) {
    background: var(--ink-2, #4a443e) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .rp-root :global(.bg-gray-700),
  .rp-root :global(.bg-gray-800) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .rp-root :global(.bg-blue-50),
  .rp-root :global(.bg-blue-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--blue, #1f4a99) !important; }
  .rp-root :global(.bg-blue-600),
  .rp-root :global(.bg-blue-700) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .rp-root :global(.bg-green-50),
  .rp-root :global(.bg-green-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--green, #1f7a3a) !important; }
  .rp-root :global(.bg-green-600),
  .rp-root :global(.bg-green-700) {
    background: var(--green, #1f7a3a) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .rp-root :global(.bg-red-50),
  .rp-root :global(.bg-red-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--accent, #a30b1e) !important; }
  .rp-root :global(.bg-red-600),
  .rp-root :global(.bg-red-700) {
    background: var(--accent, #a30b1e) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .rp-root :global(.bg-yellow-50),
  .rp-root :global(.bg-yellow-100),
  .rp-root :global(.bg-amber-50) { background: var(--paper, #fbfaf6) !important; border-color: var(--amber, #b8860b) !important; }
  .rp-root :global(.text-gray-400),
  .rp-root :global(.text-gray-500),
  .rp-root :global(.text-gray-600),
  .rp-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
  .rp-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
  .rp-root :global(.text-blue-600),
  .rp-root :global(.text-blue-700),
  .rp-root :global(.text-blue-800) { color: var(--blue, #1f4a99) !important; }
  .rp-root :global(.text-green-600),
  .rp-root :global(.text-green-700),
  .rp-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
  .rp-root :global(.text-red-600),
  .rp-root :global(.text-red-700),
  .rp-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
  .rp-root :global(.text-yellow-700),
  .rp-root :global(.text-yellow-800),
  .rp-root :global(.text-amber-700),
  .rp-root :global(.text-amber-800) { color: var(--amber, #b8860b) !important; }
  .rp-root :global(.border-gray-200),
  .rp-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
  .rp-root :global(.rounded),
  .rp-root :global(.rounded-md),
  .rp-root :global(.rounded-lg),
  .rp-root :global(.rounded-xl),
  .rp-root :global(.rounded-2xl),
  .rp-root :global(.rounded-full) { border-radius: 0 !important; }
  .rp-root :global(.shadow),
  .rp-root :global(.shadow-sm),
  .rp-root :global(.shadow-md),
  .rp-root :global(.shadow-lg) { box-shadow: none !important; }
  .rp-root :global(input),
  .rp-root :global(select),
  .rp-root :global(textarea) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .rp-root :global(input:focus),
  .rp-root :global(select:focus),
  .rp-root :global(textarea:focus) {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
</style>
