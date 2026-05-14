<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabaseClient';
  import { adminChecked } from '$lib/stores/adminAuth';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { initAdminPage } from '$lib/utils/adminPage';
  import { showConfirm } from '$lib/stores/confirmDialogStore';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  // Guard: només admins en vista admin (respecta el toggle viewMode).
  $: if ($adminChecked && !$effectiveIsAdmin) {
    goto('/campionat-continu/llista-espera');
  }

  let loading = true;
  let error: string | null = null;
  let events: any[] = [];
  let selectedEventId: string = '';
  let waitingList: any[] = [];
  let statistics: any = null;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const priorityNames = {
    1: 'Normal',
    2: 'Alta'
  };

  const priorityColors = {
    1: 'bg-gray-100 text-gray-800',
    2: 'bg-yellow-100 text-yellow-800'
  };

  onMount(async () => {
    const result = await initAdminPage(loadEvents, { redirectIfNoSession: '/login' });
    loading = result.loading;
    error = result.error;
  });

  async function loadEvents() {
    const { data, error: eventsError } = await supabase
      .from('events')
      .select('*')
      .eq('actiu', true)
      .eq('gestiona_llista_espera', true)
      .order('creat_el', { ascending: false });

    if (eventsError) throw eventsError;
    events = data || [];

    if (events.length > 0 && !selectedEventId) {
      selectedEventId = events[0].id;
      await loadEventData();
    }
  }

  async function loadEventData() {
    if (!selectedEventId) return;

    try {
      loading = true;
      await Promise.all([loadWaitingList(), loadStatistics()]);
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }

  async function loadWaitingList() {
    if (!selectedEventId) return;

    const { data, error: waitingError } = await supabase
      .from('v_llista_espera_detall')
      .select('*')
      .eq('event_id', selectedEventId)
      .order('prioritat', { ascending: false })
      .order('data_entrada');

    if (waitingError) throw waitingError;
    waitingList = data || [];
  }

  async function loadStatistics() {
    if (!selectedEventId) return;

    const { data, error: statsError } = await supabase
      .rpc('get_estadistiques_llista_espera', { p_event_id: selectedEventId })
      .single();

    if (statsError && statsError.code !== 'PGRST116') { // No rows is ok
      throw statsError;
    }

    statistics = data;
  }

  async function promoteFromWaitingList(waitingId: string) {
    try {
      // Trobem el registre de llista d'espera
      const waitingRecord = waitingList.find(w => w.id === waitingId);
      if (!waitingRecord) return;

      // Utilitzem la funció de promoció
      const { data, error } = await supabase
        .rpc('promoure_seguent_llista_espera', {
          p_event_id: selectedEventId,
          p_categoria_id: waitingRecord.categoria_preferida_id
        });

      if (error) throw error;

      if (data) {
        // Reload data
        await loadEventData();
        // Potser enviar notificació
      }
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function removeFromWaitingList(waitingId: string, reason: string = '') {
    const ok = await showConfirm({
      title: 'Eliminar de la llista d\'espera',
      message: 'Estàs segur que vols eliminar aquest jugador de la llista d\'espera?',
      severity: 'danger',
      confirmLabel: 'Eliminar'
    });
    if (!ok) return;

    try {
      const waitingRecord = waitingList.find(w => w.id === waitingId);
      if (!waitingRecord) return;

      // Eliminar de la llista
      const { error: deleteError } = await supabase
        .from('llista_espera')
        .delete()
        .eq('id', waitingId);

      if (deleteError) throw deleteError;

      // Registrar al log
      const { error: logError } = await supabase
        .from('log_llista_espera')
        .insert({
          event_id: selectedEventId,
          soci_id: waitingRecord.soci_id,
          accio: 'eliminat',
          detalls: reason || 'Eliminat manualment per administrador'
        });

      if (logError) console.warn('Could not log waiting list action:', logError);

      // Reload data
      await loadEventData();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function updatePriority(waitingId: string, newPriority: number) {
    try {
      const { error } = await supabase
        .from('llista_espera')
        .update({ prioritat: newPriority })
        .eq('id', waitingId);

      if (error) throw error;

      // Reload data
      await loadEventData();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  function formatWaitTime(dataEntrada: string): string {
    const now = new Date();
    const entryDate = new Date(dataEntrada);
    const diffMs = now.getTime() - entryDate.getTime();
    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (days === 0) return 'Avui';
    if (days === 1) return '1 dia';
    return `${days} dies`;
  }

  $: selectedEvent = events.find(e => e.id === selectedEventId);
</script>

<svelte:head>
  <title>Gestió de llista d'espera</title>
</svelte:head>

<div class="gle-root">
  <header class="gle-mast">
    <div class="editorial-eyebrow">Rànquing continu · Administració</div>
    <h1 class="gle-title">Gestió de llista d'espera</h1>
    <p class="gle-sub">Administra la llista d'espera de l'esdeveniment del rànquing continu en curs.</p>
  </header>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} />
  {:else if events.length === 0}
    <div class="text-center py-12 bg-white rounded-lg shadow">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha esdeveniments amb llista d'espera</h3>
      <p class="mt-1 text-sm text-gray-500">Activa la gestió de llistes d'espera en els esdeveniments per utilitzar aquesta funcionalitat</p>
    </div>
  {:else}
    <!-- Event Selector -->
    <div class="mb-6">
      <label for="event-select" class="block text-sm font-medium text-gray-700 mb-2">
        Selecciona Esdeveniment
      </label>
      <select
        id="event-select"
        bind:value={selectedEventId}
        on:change={loadEventData}
        class="block w-full max-w-md px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
      >
        {#each events as event}
          <option value={event.id}>
            {event.nom} - {event.temporada} ({modalityNames[event.modalitat]})
          </option>
        {/each}
      </select>
    </div>

    {#if selectedEvent}
      <!-- Statistics Cards -->
      {#if statistics}
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div class="bg-white p-4 rounded-lg shadow border">
            <div class="text-2xl font-bold text-gray-900">{statistics.total_esperant || 0}</div>
            <div class="text-sm text-gray-600">Total en Espera</div>
          </div>
          <div class="bg-white p-4 rounded-lg shadow border">
            <div class="text-2xl font-bold text-yellow-600">
              {statistics.per_prioritat?.alta || 0}
            </div>
            <div class="text-sm text-gray-600">Prioritat Alta</div>
          </div>
          <div class="bg-white p-4 rounded-lg shadow border">
            <div class="text-lg font-bold text-blue-600">
              {statistics.temps_espera_mitja ?
                Math.floor(statistics.temps_espera_mitja.split(' ')[0]) + ' dies' :
                'N/A'}
            </div>
            <div class="text-sm text-gray-600">Temps d'Espera Mitjà</div>
          </div>
        </div>
      {/if}

      <!-- Waiting List Table -->
      {#if waitingList.length === 0}
        <div class="text-center py-12 bg-white rounded-lg shadow">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha jugadors en espera</h3>
          <p class="mt-1 text-sm text-gray-500">Aquest esdeveniment no té cap jugador a la llista d'espera</p>
        </div>
      {:else}
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Posició
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Jugador
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Prioritat
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Temps d'Espera
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Categoria Preferida
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Preferències
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Accions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each waitingList as waiting}
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div class="flex-shrink-0 h-8 w-8">
                          <div class="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center">
                            <span class="text-sm font-medium text-blue-800">{waiting.posicio_llista}</span>
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900">
                        {formatarNomJugador(`${waiting.nom ?? ''} ${waiting.cognoms ?? ''}`.trim())}
                      </div>
                      <div class="text-sm text-gray-500">
                        {waiting.email}
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <select
                        value={waiting.prioritat}
                        on:change={(e) => updatePriority(waiting.id, parseInt(e.target.value))}
                        class="text-sm border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 {priorityColors[waiting.prioritat]}"
                      >
                        <option value="1">Normal</option>
                        <option value="2">Alta</option>
                      </select>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <div>{formatWaitTime(waiting.data_entrada)}</div>
                      <div class="text-xs text-gray-400">
                        {new Date(waiting.data_entrada).toLocaleDateString('ca-ES')}
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {waiting.categoria_preferida_nom || 'Qualsevol'}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <div class="space-y-1">
                        {#if waiting.preferencies_dies?.length}
                          <div>Dies: {waiting.preferencies_dies.join(', ')}</div>
                        {/if}
                        {#if waiting.preferencies_hores?.length}
                          <div>Hores: {waiting.preferencies_hores.join(', ')}</div>
                        {/if}
                        {#if waiting.restriccions_especials}
                          <div class="text-red-600">⚠ {waiting.restriccions_especials}</div>
                        {/if}
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                      <button
                        on:click={() => promoteFromWaitingList(waiting.id)}
                        class="text-green-600 hover:text-green-900 bg-green-50 hover:bg-green-100 px-3 py-1 rounded-md transition-colors"
                      >
                        Promoure
                      </button>
                      <button
                        on:click={() => removeFromWaitingList(waiting.id)}
                        class="text-red-600 hover:text-red-900 bg-red-50 hover:bg-red-100 px-3 py-1 rounded-md transition-colors"
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
      {/if}
    {/if}
  {/if}
</div>

<style>
  .gle-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .gle-mast {
    margin-bottom: 1.5rem;
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
  .gle-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .gle-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }

  .gle-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .gle-root :global(.bg-gray-50),
  .gle-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .gle-root :global(.bg-blue-50),
  .gle-root :global(.bg-blue-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--blue, #1f4a99) !important; }
  .gle-root :global(.bg-green-50),
  .gle-root :global(.bg-green-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--green, #1f7a3a) !important; }
  .gle-root :global(.bg-yellow-50),
  .gle-root :global(.bg-yellow-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--amber, #b8860b) !important; }
  .gle-root :global(.bg-red-50),
  .gle-root :global(.bg-red-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--accent, #a30b1e) !important; }
  .gle-root :global(.bg-blue-600),
  .gle-root :global(.bg-blue-700) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .gle-root :global(.bg-red-600),
  .gle-root :global(.bg-red-700) {
    background: var(--accent, #a30b1e) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .gle-root :global(.bg-green-600),
  .gle-root :global(.bg-green-700) {
    background: var(--green, #1f7a3a) !important;
    color: var(--paper, #fbfaf6) !important;
  }

  .gle-root :global(.text-gray-500),
  .gle-root :global(.text-gray-600),
  .gle-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
  .gle-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
  .gle-root :global(.text-blue-600),
  .gle-root :global(.text-blue-700),
  .gle-root :global(.text-blue-800) { color: var(--blue, #1f4a99) !important; }
  .gle-root :global(.text-green-600),
  .gle-root :global(.text-green-700),
  .gle-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
  .gle-root :global(.text-red-600),
  .gle-root :global(.text-red-700),
  .gle-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
  .gle-root :global(.text-yellow-700),
  .gle-root :global(.text-yellow-800) { color: var(--amber, #b8860b) !important; }

  .gle-root :global(.border-gray-200),
  .gle-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
  .gle-root :global(.rounded),
  .gle-root :global(.rounded-md),
  .gle-root :global(.rounded-lg),
  .gle-root :global(.rounded-xl),
  .gle-root :global(.rounded-2xl),
  .gle-root :global(.rounded-full) { border-radius: 0 !important; }
  .gle-root :global(.shadow),
  .gle-root :global(.shadow-sm),
  .gle-root :global(.shadow-md) { box-shadow: none !important; }
  .gle-root :global(input),
  .gle-root :global(select) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .gle-root :global(table) { font-family: var(--font-sans, sans-serif); }
  .gle-root :global(thead.bg-gray-50) {
    background: var(--paper, #fbfaf6) !important;
    border-bottom: 1px solid var(--ink, #1a1814) !important;
  }
</style>