<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/stores/auth';
  import { adminChecked } from '$lib/stores/adminAuth';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import Banner from '$lib/components/general/Banner.svelte';

  // Guard: només admins en vista admin (respecta el toggle viewMode).
  $: if ($adminChecked && !$effectiveIsAdmin) {
    goto('/campionat-continu/ranking');
  }
  import Loader from '$lib/components/general/Loader.svelte';
  import PlayerSearcher from '$lib/components/general/UnifiedPlayerSearcher.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { showConfirm } from '$lib/stores/confirmDialogStore';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  let loading = true;
  let error: string | null = null;
  let events: any[] = [];
  let selectedEventId: string = '';
  let inscriptions: any[] = [];
  let categories: any[] = [];
  let showAddPlayer = false;
  let selectedPlayer: any = null;
  let addingInscription = false;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const competitionTypes = {
    'lliga_social': 'Campionat Social',
    'handicap': 'Hàndicap',
    'eliminatories': 'Eliminatòries',
    'ranking_continu': 'Ranking Continu'
  };

  const statusNames = {
    'inscripcions': 'Inscripcions Obertes',
    'pendent_validacio': 'Pendent Validació',
    'validat': 'Validat',
    'en_curs': 'En Curs',
    'finalitzat': 'Finalitzat'
  };

  onMount(async () => {
    const u = $user;
    if (!u?.email) {
      goto('/login');
      return;
    }

    try {
      loading = true;
      await loadEvents();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadEvents() {
    const { supabase } = await import('$lib/supabaseClient');

    const { data, error: eventsError } = await supabase
      .from('events')
      .select('*')
      .eq('actiu', true)
      .eq('tipus_competicio', 'ranking_continu')
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
      await Promise.all([loadInscriptions(), loadCategories()]);
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }

  async function loadInscriptions() {
    if (!selectedEventId) return;

    const { supabase } = await import('$lib/supabaseClient');

    const { data, error: inscriptionsError } = await supabase
      .from('inscripcions')
      .select(`
        *,
        socis (
          nom,
          cognoms,
          numero_soci,
          email
        ),
        categoria_assignada:categories (
          nom,
          ordre_categoria
        )
      `)
      .eq('event_id', selectedEventId)
      .order('data_inscripcio', { ascending: false });

    if (inscriptionsError) throw inscriptionsError;
    inscriptions = data || [];
  }

  async function loadCategories() {
    if (!selectedEventId) return;

    const { supabase } = await import('$lib/supabaseClient');

    const { data, error: categoriesError } = await supabase
      .from('categories')
      .select('*')
      .eq('event_id', selectedEventId)
      .order('ordre_categoria');

    if (categoriesError) throw categoriesError;
    categories = data || [];
  }

  async function updateInscriptionStatus(inscriptionId: string, field: 'confirmat' | 'pagat', value: boolean) {
    try {
      const { supabase } = await import('$lib/supabaseClient');

      const { error } = await supabase
        .from('inscripcions')
        .update({ [field]: value })
        .eq('id', inscriptionId);

      if (error) throw error;

      // Reload inscriptions
      await loadInscriptions();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function assignCategory(inscriptionId: string, categoryId: string | null) {
    try {
      const { supabase } = await import('$lib/supabaseClient');

      const { error } = await supabase
        .from('inscripcions')
        .update({ categoria_assignada_id: categoryId })
        .eq('id', inscriptionId);

      if (error) throw error;

      // Reload inscriptions
      await loadInscriptions();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function deleteInscription(inscriptionId: string) {
    const ok = await showConfirm({
      title: 'Eliminar inscripció',
      message: 'Estàs segur que vols eliminar aquesta inscripció?',
      severity: 'danger',
      confirmLabel: 'Eliminar'
    });
    if (!ok) return;

    try {
      const { supabase } = await import('$lib/supabaseClient');

      const { error } = await supabase
        .from('inscripcions')
        .delete()
        .eq('id', inscriptionId);

      if (error) throw error;

      // Reload inscriptions
      await loadInscriptions();
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  function getInscriptionSummary() {
    const total = inscriptions.length;
    const confirmed = inscriptions.filter(i => i.confirmat).length;
    const paid = inscriptions.filter(i => i.pagat).length;
    const assigned = inscriptions.filter(i => i.categoria_assignada_id).length;

    return { total, confirmed, paid, assigned };
  }

  async function addPlayerInscription() {
    if (!selectedPlayer || !selectedEventId) return;

    try {
      addingInscription = true;
      const { supabase } = await import('$lib/supabaseClient');

      // Get player's best average from the last two years (mitjanes_historiques uses soci_id/year/modalitat)
      const currentYear = new Date().getFullYear();
      const lastTwoYears = [currentYear, currentYear - 1];

      const { data: mitjanesList, error: mitjanesErr } = await supabase
        .from('mitjanes_historiques')
        .select('mitjana, year')
        .eq('soci_id', selectedPlayer.numero_soci)
        .eq('modalitat', '3 BANDES')
        .in('year', lastTwoYears);

      if (mitjanesErr) console.warn('Error carregant mitjanes:', mitjanesErr.message);

      const bestMitjana = (mitjanesList?.length ?? 0) > 0
        ? Math.max(...(mitjanesList ?? []).map(m => m.mitjana))
        : null;

      const inscriptionData = {
        event_id: selectedEventId,
        soci_numero: selectedPlayer.numero_soci,
        preferencies_dies: [],
        preferencies_hores: [],
        restriccions_especials: null,
        observacions: bestMitjana ? `Mitjana històrica: ${bestMitjana}` : 'Sense mitjana històrica',
        confirmat: true, // Admin inscription is auto-confirmed
        pagat: false
      };

      const { error: inscriptionError } = await supabase
        .from('inscripcions')
        .insert([inscriptionData]);

      if (inscriptionError) throw inscriptionError;

      // Reset form
      selectedPlayer = null;
      showAddPlayer = false;

      // Reload inscriptions
      await loadInscriptions();

    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      addingInscription = false;
    }
  }

  $: selectedEvent = events.find(e => e.id === selectedEventId);
  $: summary = getInscriptionSummary();
</script>

<svelte:head>
  <title>Gestió d'inscripcions — rànquing continu</title>
</svelte:head>

<div class="gi-root">
  <header class="gi-mast">
    <div class="editorial-eyebrow">Rànquing continu · Administració</div>
    <h1>Gestió d'inscripcions</h1>
    <p class="gi-sub">Administrar inscripcions als esdeveniments del rànquing continu.</p>
  </header>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} />
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
      <!-- Event Info -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
        <h3 class="text-lg font-medium text-blue-900 mb-2">{selectedEvent.nom}</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <span class="font-medium text-blue-800">Modalitat:</span>
            <span class="text-blue-700">{modalityNames[selectedEvent.modalitat]}</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Tipus:</span>
            <span class="text-blue-700">{competitionTypes[selectedEvent.tipus_competicio]}</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Estat:</span>
            <span class="text-blue-700">{statusNames[selectedEvent.estat_competicio]}</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Quota:</span>
            <span class="text-blue-700">{selectedEvent.quota_inscripcio || 0}€</span>
          </div>
        </div>
      </div>

      <!-- Add Player Section -->
      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-medium text-gray-900">Afegir Jugador</h3>
          <button
            on:click={() => showAddPlayer = !showAddPlayer}
            class="px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700"
          >
            {showAddPlayer ? 'Cancel·lar' : 'Afegir Jugador'}
          </button>
        </div>

        {#if showAddPlayer}
          <div class="space-y-4">
            <div>
              <PlayerSearcher
                searchType="active_players"
                title="Selecciona Jugador"
                description="Cerca jugador per nom o número de soci"
                placeholder="Cerca jugador per nom o número de soci..."
                allowSelection={true}
                on:playerSelected={(event) => selectedPlayer = event.detail}
              />
            </div>

            {#if selectedPlayer}
              <div class="bg-gray-50 p-4 rounded-lg">
                <h4 class="font-medium text-gray-900 mb-2">Jugador Seleccionat:</h4>
                <p class="text-sm text-gray-600">
                  <strong>{formatarNomJugador(`${selectedPlayer.nom ?? ''} ${selectedPlayer.cognoms ?? ''}`.trim())}</strong>
                </p>
                {#if selectedPlayer.email}
                  <p class="text-sm text-gray-500">{selectedPlayer.email}</p>
                {/if}
              </div>

              <div class="flex space-x-3">
                <button
                  on:click={addPlayerInscription}
                  disabled={addingInscription}
                  class="px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 disabled:bg-gray-400"
                >
                  {addingInscription ? 'Inscrivint...' : 'Inscriure Jugador'}
                </button>
                <button
                  on:click={() => { selectedPlayer = null; showAddPlayer = false; }}
                  class="px-4 py-2 bg-gray-300 text-gray-700 text-sm rounded hover:bg-gray-400"
                >
                  Cancel·lar
                </button>
              </div>
            {/if}
          </div>
        {/if}
      </div>

      <!-- Summary Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div class="bg-white p-4 rounded-lg shadow border">
          <div class="text-2xl font-bold text-gray-900">{summary.total}</div>
          <div class="text-sm text-gray-600">Total Inscripcions</div>
        </div>
        <div class="bg-white p-4 rounded-lg shadow border">
          <div class="text-2xl font-bold text-green-600">{summary.confirmed}</div>
          <div class="text-sm text-gray-600">Confirmades</div>
        </div>
        <div class="bg-white p-4 rounded-lg shadow border">
          <div class="text-2xl font-bold text-blue-600">{summary.paid}</div>
          <div class="text-sm text-gray-600">Pagades</div>
        </div>
        <div class="bg-white p-4 rounded-lg shadow border">
          <div class="text-2xl font-bold text-purple-600">{summary.assigned}</div>
          <div class="text-sm text-gray-600">Assignades</div>
        </div>
      </div>

      <!-- Inscriptions Table -->
      {#if inscriptions.length === 0}
        <div class="text-center py-12 bg-white rounded-lg shadow">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha inscripcions</h3>
          <p class="mt-1 text-sm text-gray-500">Aquest esdeveniment no té cap inscripció encara</p>
        </div>
      {:else}
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Jugador
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Data
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Categoria
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Preferències
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Estat
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Accions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each inscriptions as inscription}
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div>
                          <div class="text-sm font-medium text-gray-900">
                            {formatarNomJugador(`${inscription.socis.nom ?? ''} ${inscription.socis.cognoms ?? ''}`.trim())}
                          </div>
                          <div class="text-sm text-gray-500">
                            {inscription.socis.email}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {new Date(inscription.data_inscripcio).toLocaleDateString('ca-ES')}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <select
                        value={inscription.categoria_assignada_id || ''}
                        on:change={(e) => assignCategory(inscription.id, e.target.value || null)}
                        class="text-sm border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
                      >
                        <option value="">No assignada</option>
                        {#each categories as category}
                          <option value={category.id}>{category.nom}</option>
                        {/each}
                      </select>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <div class="space-y-1">
                        {#if inscription.preferencies_dies?.length}
                          <div>Dies: {inscription.preferencies_dies.join(', ')}</div>
                        {/if}
                        {#if inscription.preferencies_hores?.length}
                          <div>Hores: {inscription.preferencies_hores.join(', ')}</div>
                        {/if}
                        {#if inscription.restriccions_especials}
                          <div class="text-red-600">⚠ {inscription.restriccions_especials}</div>
                        {/if}
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="space-y-2">
                        <label class="flex items-center">
                          <input
                            type="checkbox"
                            checked={inscription.confirmat}
                            on:change={(e) => updateInscriptionStatus(inscription.id, 'confirmat', e.target.checked)}
                            class="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
                          />
                          <span class="ml-2 text-sm text-gray-700">Confirmat</span>
                        </label>
                        {#if selectedEvent.quota_inscripcio > 0}
                          <label class="flex items-center">
                            <input
                              type="checkbox"
                              checked={inscription.pagat}
                              on:change={(e) => updateInscriptionStatus(inscription.id, 'pagat', e.target.checked)}
                              class="rounded border-gray-300 text-green-600 shadow-sm focus:border-green-300 focus:ring focus:ring-green-200 focus:ring-opacity-50"
                            />
                            <span class="ml-2 text-sm text-gray-700">Pagat</span>
                          </label>
                        {/if}
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button
                        on:click={() => deleteInscription(inscription.id)}
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
      {/if}
    {/if}
  {/if}
</div>

<style>
  .gi-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .gi-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .gi-mast .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .gi-mast h1 {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .gi-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }

  .gi-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .gi-root :global(.bg-gray-50),
  .gi-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .gi-root :global(.bg-blue-50),
  .gi-root :global(.bg-blue-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--blue, #1f4a99) !important; }
  .gi-root :global(.bg-green-50),
  .gi-root :global(.bg-green-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--green, #1f7a3a) !important; }
  .gi-root :global(.bg-yellow-50),
  .gi-root :global(.bg-yellow-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--amber, #b8860b) !important; }
  .gi-root :global(.bg-red-50),
  .gi-root :global(.bg-red-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--accent, #a30b1e) !important; }
  .gi-root :global(.bg-blue-600),
  .gi-root :global(.bg-blue-700) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .gi-root :global(.bg-red-600),
  .gi-root :global(.bg-red-700) {
    background: var(--accent, #a30b1e) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .gi-root :global(.text-gray-500),
  .gi-root :global(.text-gray-600),
  .gi-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
  .gi-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
  .gi-root :global(.text-blue-600),
  .gi-root :global(.text-blue-700),
  .gi-root :global(.text-blue-800) { color: var(--blue, #1f4a99) !important; }
  .gi-root :global(.text-green-600),
  .gi-root :global(.text-green-700),
  .gi-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
  .gi-root :global(.text-yellow-700),
  .gi-root :global(.text-yellow-800) { color: var(--amber, #b8860b) !important; }
  .gi-root :global(.text-red-600),
  .gi-root :global(.text-red-700),
  .gi-root :global(.text-red-800),
  .gi-root :global(.text-red-900) { color: var(--accent, #a30b1e) !important; }
  .gi-root :global(.border-gray-200),
  .gi-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
  .gi-root :global(.rounded),
  .gi-root :global(.rounded-md),
  .gi-root :global(.rounded-lg),
  .gi-root :global(.rounded-xl),
  .gi-root :global(.rounded-2xl),
  .gi-root :global(.rounded-full) { border-radius: 0 !important; }
  .gi-root :global(.shadow),
  .gi-root :global(.shadow-sm),
  .gi-root :global(.shadow-md) { box-shadow: none !important; }
  .gi-root :global(input),
  .gi-root :global(select),
  .gi-root :global(textarea) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .gi-root :global(input:focus),
  .gi-root :global(select:focus),
  .gi-root :global(textarea:focus) {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
  .gi-root :global(table) { font-family: var(--font-sans, sans-serif); }
  .gi-root :global(thead.bg-gray-50) {
    background: var(--paper, #fbfaf6) !important;
    border-bottom: 1px solid var(--ink, #1a1814) !important;
  }
</style>