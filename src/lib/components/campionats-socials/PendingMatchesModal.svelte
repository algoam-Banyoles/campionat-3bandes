<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  const dispatch = createEventDispatcher();

  export let eventId: string;
  export let slot: any;
  export let categories: any[] = [];

  let loading = true;
  let pendingMatches: any[] = [];
  let selectedMatch: any = null;
  let error = '';

  $: if (eventId) {
    loadPendingMatches();
  }

  async function loadPendingMatches() {
    try {
      loading = true;
      error = '';

      const { data, error: fetchError } = await supabase
        .from('calendari_partides')
        .select(`
          id,
          jugador1_id,
          jugador2_id,
          categoria_id,
          estat,
          data_programada,
          hora_inici,
          jugador1:socis!calendari_partides_jugador1_id_fkey(nom, cognoms),
          jugador2:socis!calendari_partides_jugador2_id_fkey(nom, cognoms),
          categoria:categories(nom)
        `)
        .eq('event_id', eventId)
        .or('estat.eq.pendent,estat.eq.no_programada')
        .is('data_programada', null)
        .order('categoria_id');

      if (fetchError) throw fetchError;

      pendingMatches = data || [];
    } catch (e: any) {
      console.error('Error loading pending matches:', e);
      error = e.message || 'Error carregant partides pendents';
    } finally {
      loading = false;
    }
  }

  function getPlayerName(player: any): string {
    if (!player) return 'Desconegut';
    return `${player.nom} ${player.cognoms || ''}`.trim();
  }

  function getCategoryName(match: any): string {
    return match.categoria?.nom || 'Sense categoria';
  }

  function selectMatch(match: any) {
    selectedMatch = match;
  }

  async function confirmSelection() {
    if (!selectedMatch) return;

    try {
      loading = true;
      error = '';

      // Programar la partida en el slot seleccionat
      const updates = {
        data_programada: slot.dateStr + 'T' + slot.hora + ':00',
        hora_inici: slot.hora,
        taula_assignada: slot.taula,
        estat: 'validada'
      };

      const { error: updateError } = await supabase
        .from('calendari_partides')
        .update(updates)
        .eq('id', selectedMatch.id);

      if (updateError) throw updateError;

      dispatch('matchProgrammed', { matchId: selectedMatch.id });
      dispatch('close');
    } catch (e: any) {
      console.error('Error programming match:', e);
      error = e.message || 'Error programant la partida';
      loading = false;
    }
  }

  function close() {
    dispatch('close');
  }
</script>

<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
  <div class="bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
    <!-- Header -->
    <div class="px-6 py-4 border-b border-gray-200 bg-gray-50">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-xl font-bold text-gray-900">Partides Pendents de Programar</h3>
          <p class="text-sm text-gray-600 mt-1">
            Slot: {slot.dateStr} · {slot.hora} · Billar {slot.taula}
          </p>
        </div>
        <button
          on:click={close}
          class="text-gray-400 hover:text-gray-600 transition-colors"
          title="Tancar"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    </div>

    <!-- Content -->
    <div class="flex-1 overflow-y-auto p-6">
      {#if loading}
        <div class="flex items-center justify-center py-12">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      {:else if error}
        <div class="bg-red-50 border border-red-200 rounded-lg p-4">
          <p class="text-red-800">{error}</p>
        </div>
      {:else if pendingMatches.length === 0}
        <div class="text-center py-12">
          <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
          </svg>
          <p class="text-gray-600 text-lg">No hi ha partides pendents de programar</p>
        </div>
      {:else}
        <div class="space-y-2">
          {#each pendingMatches as match}
            <button
              on:click={() => selectMatch(match)}
              class="w-full text-left p-4 border-2 rounded-lg transition-all {
                selectedMatch?.id === match.id
                  ? 'border-blue-500 bg-blue-50'
                  : 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'
              }"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-3">
                    <span class="px-2 py-1 bg-purple-100 text-purple-800 text-xs font-semibold rounded">
                      {getCategoryName(match)}
                    </span>
                    <div class="font-semibold text-gray-900">
                      {getPlayerName(match.jugador1)} vs {getPlayerName(match.jugador2)}
                    </div>
                  </div>
                </div>
                {#if selectedMatch?.id === match.id}
                  <svg class="w-6 h-6 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                  </svg>
                {/if}
              </div>
            </button>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Footer -->
    <div class="px-6 py-4 border-t border-gray-200 bg-gray-50 flex items-center justify-between">
      <div class="text-sm text-gray-600">
        {#if pendingMatches.length > 0}
          {pendingMatches.length} {pendingMatches.length === 1 ? 'partida pendent' : 'partides pendents'}
        {/if}
      </div>
      <div class="flex gap-3">
        <button
          on:click={close}
          class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-100 transition-colors"
        >
          Cancel·lar
        </button>
        <button
          on:click={confirmSelection}
          disabled={!selectedMatch || loading}
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {loading ? 'Programant...' : 'Programar Partida'}
        </button>
      </div>
    </div>
  </div>
</div>
