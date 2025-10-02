<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/stores/auth';
  import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import { formatSupabaseError, err as errText } from '$lib/ui/alerts';

  let loading = true;
  let error: string | null = null;
  let events: any[] = [];
  let successMessage: string | null = null;

  type EventStatus = 'planificacio' | 'inscripcions' | 'pendent_validacio' | 'validat' | 'en_curs' | 'finalitzat';

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const competitionTypes = {
    'ranking_continu': 'Rànquing Continu',
    'lliga_social': 'Campionat Social',
    'handicap': 'Hàndicap',
    'eliminatories': 'Eliminatòries'
  };

  const statusNames = {
    'planificacio': 'Planificació',
    'inscripcions': 'Inscripcions Obertes',
    'pendent_validacio': 'Pendent Validació',
    'validat': 'Validat',
    'en_curs': 'En Curs',
    'finalitzat': 'Finalitzat'
  };

  const statusColors = {
    'planificacio': 'bg-gray-100 text-gray-800',
    'inscripcions': 'bg-blue-100 text-blue-800',
    'pendent_validacio': 'bg-yellow-100 text-yellow-800',
    'validat': 'bg-green-100 text-green-800',
    'en_curs': 'bg-indigo-100 text-indigo-800',
    'finalitzat': 'bg-gray-100 text-gray-600'
  };

  onMount(async () => {
    try {
      loading = true;
      error = null;

      const u = $user;
      if (!u?.email) {
        goto('/login');
        return;
      }

      // Use reactive admin check instead of async function
      if (!$adminChecked) {
        loading = false;
        return;
      }
      
      if (!$isAdmin) {
        error = errText('Només els administradors poden accedir a aquesta pàgina.');
        return;
      }

      await loadEvents();
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  // Reactively check admin status
  $: {
    if ($adminChecked && !$isAdmin && $user?.email) {
      error = errText('Només els administradors poden accedir a aquesta pàgina.');
    } else if ($adminChecked && $isAdmin) {
      error = null;
    }
  }

  async function loadEvents() {
    const { supabase } = await import('$lib/supabaseClient');
    const { data, error: eventsError } = await supabase
      .from('events')
      .select(`
        *,
        categories (
          id,
          nom,
          distancia_caramboles,
          ordre_categoria,
          promig_minim
        )
      `)
      .order('creat_el', { ascending: false });

    if (eventsError) throw eventsError;
    events = data || [];
  }

  async function updateEventStatus(eventId: string, newStatus: EventStatus) {
    try {
      const { supabase } = await import('$lib/supabaseClient');
      const { error: updateError } = await supabase
        .from('events')
        .update({ estat_competicio: newStatus })
        .eq('id', eventId);

      if (updateError) throw updateError;

      successMessage = 'Estat actualitzat correctament';
      await loadEvents();

      // Clear success message after 3 seconds
      setTimeout(() => successMessage = null, 3000);
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  async function toggleEventActive(eventId: string, currentActive: boolean) {
    try {
      const { supabase } = await import('$lib/supabaseClient');
      const { error: updateError } = await supabase
        .from('events')
        .update({ actiu: !currentActive })
        .eq('id', eventId);

      if (updateError) throw updateError;

      successMessage = currentActive ? 'Event desactivat' : 'Event activat';
      await loadEvents();

      setTimeout(() => successMessage = null, 3000);
    } catch (e) {
      error = formatSupabaseError(e);
    }
  }

  function getEventStats(event: any) {
    const totalCategories = event.categories?.length || 0;
    const categoriesWithPromig = event.categories?.filter((c: any) => c.promig_minim !== null).length || 0;

    return {
      totalCategories,
      categoriesWithPromig,
      hasPromotions: categoriesWithPromig > 0
    };
  }
</script>

<svelte:head>
  <title>Gestió d'Events - Administració</title>
</svelte:head>

<div class="max-w-7xl mx-auto p-4">
  <div class="flex justify-between items-center mb-6">
    <div>
      <h1 class="text-2xl font-semibold text-gray-900">Gestió d'Events</h1>
      <p class="text-gray-600 mt-1">Administra tots els campionats i competicions</p>
    </div>
    <div class="flex space-x-3">
      <a
        href="/admin/events/nou"
        class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
      >
        <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Nou Event
      </a>
    </div>
  </div>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} />
  {:else}
    {#if successMessage}
      <Banner type="success" message={successMessage} class="mb-4" />
    {/if}

    {#if events.length === 0}
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha events</h3>
        <p class="mt-1 text-sm text-gray-500">Comença creant el teu primer event de competició</p>
        <div class="mt-6">
          <a
            href="/admin/events/nou"
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
          >
            Crear Primer Event
          </a>
        </div>
      </div>
    {:else}
      <!-- Taula d'events -->
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Event</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Tipus</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Categories</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Estat</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Dates</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Accions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            {#each events as event}
              {@const stats = getEventStats(event)}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4">
                  <div class="flex items-center">
                    <div>
                      <div class="text-sm font-medium text-gray-900">
                        <a href="/admin/events/{event.id}" class="hover:text-blue-600">
                          {event.nom}
                        </a>
                      </div>
                      <div class="text-sm text-gray-500">
                        {event.modalitat ? modalityNames[event.modalitat] : 'N/A'} • {event.temporada}
                      </div>
                      {#if !event.actiu}
                        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800 mt-1">
                          Inactiu
                        </span>
                      {/if}
                    </div>
                  </div>
                </td>

                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    {event.tipus_competicio ? competitionTypes[event.tipus_competicio] : 'N/A'}
                  </span>
                </td>

                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">{stats.totalCategories} categories</div>
                  {#if stats.hasPromotions}
                    <div class="text-xs text-green-600">✨ {stats.categoriesWithPromig} amb promocions</div>
                  {/if}
                </td>

                <td class="px-6 py-4 whitespace-nowrap">
                  <select
                    value={event.estat_competicio || 'planificacio'}
                    on:change={(e) => updateEventStatus(event.id, e.target.value)}
                    class="text-xs rounded-full px-3 py-1 font-medium border-0 focus:ring-2 focus:ring-blue-500 {statusColors[event.estat_competicio || 'planificacio']}"
                  >
                    {#each Object.entries(statusNames) as [value, label]}
                      <option {value}>{label}</option>
                    {/each}
                  </select>
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {#if event.data_inici && event.data_fi}
                    <div>{new Date(event.data_inici).toLocaleDateString('ca-ES')}</div>
                    <div class="text-xs">{new Date(event.data_fi).toLocaleDateString('ca-ES')}</div>
                  {:else}
                    <span class="text-gray-400">Sense dates</span>
                  {/if}
                </td>

                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-2">
                  <a
                    href="/admin/events/{event.id}"
                    class="text-blue-600 hover:text-blue-900"
                  >
                    Editar
                  </a>

                  <button
                    on:click={() => toggleEventActive(event.id, event.actiu)}
                    class={event.actiu ? 'text-red-600 hover:text-red-900' : 'text-green-600 hover:text-green-900'}
                  >
                    {event.actiu ? 'Desactivar' : 'Activar'}
                  </button>

                  <a
                    href="/campionats-socials/{event.id}"
                    class="text-gray-600 hover:text-gray-900"
                    target="_blank"
                  >
                    Veure
                  </a>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- Estadístiques resum -->
      <div class="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012 2v2M7 7h10"/>
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Events</dt>
                  <dd class="text-lg font-medium text-gray-900">{events.length}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Events Actius</dt>
                  <dd class="text-lg font-medium text-gray-900">{events.filter(e => e.actiu).length}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">En Curs</dt>
                  <dd class="text-lg font-medium text-gray-900">{events.filter(e => e.estat_competicio === 'en_curs').length}</dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Categories</dt>
                  <dd class="text-lg font-medium text-gray-900">
                    {events.reduce((total, event) => total + (event.categories?.length || 0), 0)}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>
    {/if}
  {/if}
</div>