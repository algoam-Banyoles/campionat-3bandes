<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/stores/auth';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import PlayerSearcher from '$lib/components/general/UnifiedPlayerSearcher.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';

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
    'lliga_social': 'Lliga Social',
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
    if (!confirm('Estàs segur que vols eliminar aquesta inscripció?')) return;

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

      // Get player's best average from the last two seasons
      const currentYear = new Date().getFullYear();
      const lastTwoSeasons = [
        `${currentYear-1}-${currentYear}`,
        `${currentYear-2}-${currentYear-1}`
      ];

      const { data: mitjanesList } = await supabase
        .from('mitjanes_historiques')
        .select('mitjana, temporada')
        .eq('numero_soci', selectedPlayer.numero_soci)
        .in('temporada', lastTwoSeasons);

      const bestMitjana = mitjanesList?.length > 0
        ? Math.max(...mitjanesList.map(m => m.mitjana))
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
  <title>Gestió d'Inscripcions - Admin</title>
</svelte:head>

<div class="max-w-7xl mx-auto p-4">
  <div class="mb-6">
    <h1 class="text-2xl font-semibold text-gray-900">Gestió d'Inscripcions</h1>
    <p class="text-gray-600 mt-1">Administra les inscripcions dels esdeveniments</p>
  </div>

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
                  <strong>{selectedPlayer.nom} {selectedPlayer.cognoms}</strong>
                  (Soci #{selectedPlayer.numero_soci})
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
                            {inscription.socis.nom} {inscription.socis.cognoms}
                          </div>
                          <div class="text-sm text-gray-500">
                            Soci #{inscription.socis.numero_soci} • {inscription.socis.email}
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