<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/stores/auth';
  import { adminChecked } from '$lib/stores/adminAuth';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import { supabase } from '$lib/supabaseClient';
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
      
      if (!$effectiveIsAdmin) {
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
    if ($adminChecked && !$effectiveIsAdmin && $user?.email) {
      error = errText('Només els administradors poden accedir a aquesta pàgina.');
    } else if ($adminChecked && $effectiveIsAdmin) {
      error = null;
    }
  }

  async function loadEvents() {

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
  <title>Events i competicions</title>
</svelte:head>

<div class="ev-root">
  <header class="ev-mast">
    <a href="/admin" class="ev-back">← Tornar a l'administració</a>
    <div class="editorial-eyebrow">Calendari general</div>
    <div class="ev-mast-row">
      <div>
        <h1 class="ev-title">Events i competicions</h1>
        <p class="ev-sub">Cicle de vida de campionats: socials, continu i hàndicap.</p>
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
  </header>

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
      <div class="bg-white shadow overflow-hidden sm:rounded-lg overflow-x-auto">
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

<style>
  .ev-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .ev-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .ev-back {
    display: inline-block;
    color: var(--ink-2, #4a443e);
    text-decoration: none;
    font-size: 0.875rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
  }
  .ev-back:hover { color: var(--ink, #1a1814); }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .ev-mast-row {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 1rem;
    flex-wrap: wrap;
    margin-top: 0.4rem;
  }
  .ev-title {
    margin: 0 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .ev-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }

  .ev-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .ev-root :global(.bg-gray-50),
  .ev-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .ev-root :global(.bg-blue-50),
  .ev-root :global(.bg-blue-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--blue, #1f4a99) !important; }
  .ev-root :global(.bg-green-50),
  .ev-root :global(.bg-green-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--green, #1f7a3a) !important; }
  .ev-root :global(.bg-yellow-50),
  .ev-root :global(.bg-yellow-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--amber, #b8860b) !important; }
  .ev-root :global(.bg-red-50),
  .ev-root :global(.bg-red-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--accent, #a30b1e) !important; }
  .ev-root :global(.bg-blue-600),
  .ev-root :global(.bg-blue-700) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .ev-root :global(.bg-red-600),
  .ev-root :global(.bg-red-700) {
    background: var(--accent, #a30b1e) !important;
    color: var(--paper, #fbfaf6) !important;
  }

  .ev-root :global(.text-gray-500),
  .ev-root :global(.text-gray-600),
  .ev-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
  .ev-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
  .ev-root :global(.text-blue-600),
  .ev-root :global(.text-blue-800) { color: var(--blue, #1f4a99) !important; }
  .ev-root :global(.text-green-600),
  .ev-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
  .ev-root :global(.text-red-600),
  .ev-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
  .ev-root :global(.text-yellow-700),
  .ev-root :global(.text-yellow-800) { color: var(--amber, #b8860b) !important; }
  .ev-root :global(.border-gray-200),
  .ev-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
  .ev-root :global(.rounded),
  .ev-root :global(.rounded-md),
  .ev-root :global(.rounded-lg),
  .ev-root :global(.rounded-xl),
  .ev-root :global(.rounded-2xl),
  .ev-root :global(.rounded-full) { border-radius: 0 !important; }
  .ev-root :global(.shadow),
  .ev-root :global(.shadow-sm),
  .ev-root :global(.shadow-md) { box-shadow: none !important; }
  .ev-root :global(input),
  .ev-root :global(select),
  .ev-root :global(textarea) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .ev-root :global(input:focus),
  .ev-root :global(select:focus),
  .ev-root :global(textarea:focus) {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
  .ev-root :global(table) { font-family: var(--font-sans, sans-serif); }
  .ev-root :global(thead.bg-gray-50) {
    background: var(--paper, #fbfaf6) !important;
    border-bottom: 1px solid var(--ink, #1a1814) !important;
  }
</style>