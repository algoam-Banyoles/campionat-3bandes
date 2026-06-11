<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user, isLoading } from '$lib/stores/auth';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import InscriptionStatus from '$lib/components/general/InscriptionStatus.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';

  let loading = true;
  let error: string | null = null;
  let openEvents: any[] = [];
  let myInscriptions: any[] = [];

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const competitionTypes = {
    'lliga_social': 'Campionat Social',
    'handicap': 'Hàndicap',
    'eliminatories': 'Eliminatòries'
  };

  const statusNames = {
    'inscripcions': 'Inscripcions Obertes',
    'pendent_validacio': 'Pendent Validació',
    'validat': 'Validat'
  };

  const statusColors = {
    'inscripcions': 'bg-green-100 text-green-800',
    'pendent_validacio': 'bg-yellow-100 text-yellow-800',
    'validat': 'bg-blue-100 text-blue-800'
  };

  // Redirigir a login només quan auth ha resolt (no durant 'loading').
  $: if (!$isLoading && !$user) {
    goto('/login');
  }

  onMount(async () => {
    try {
      loading = true;
      await Promise.all([loadOpenEvents(), loadMyInscriptions()]);
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadOpenEvents() {
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
          min_jugadors,
          max_jugadors
        )
      `)
      .eq('actiu', true)
      .in('estat_competicio', ['inscripcions', 'pendent_validacio'])
      .order('creat_el', { ascending: false });

    if (eventsError) throw eventsError;
    openEvents = data || [];
  }

  async function loadMyInscriptions() {
    if (!$user?.email) return;

    const { supabase } = await import('$lib/supabaseClient');

    // Get soci info directly
    const { data: soci, error: sociError } = await supabase
      .from('socis')
      .select('numero_soci')
      .eq('email', $user.email)
      .single();

    if (sociError || !soci) return; // User might not be a member

    const { data, error: inscriptionsError } = await supabase
      .from('inscripcions')
      .select(`
        *,
        events (
          nom,
          temporada,
          modalitat,
          tipus_competicio,
          estat_competicio
        ),
        categoria_assignada:categories (
          nom,
          ordre_categoria
        )
      `)
      .eq('soci_numero', soci.numero_soci);

    if (inscriptionsError) throw inscriptionsError;
    myInscriptions = data || [];
  }

  function getEventInscriptionStatus(eventId: string) {
    const inscription = myInscriptions.find(i => i.event_id === eventId);
    if (!inscription) return null;

    return {
      ...inscription,
      statusText: inscription.confirmat ? 'Confirmat' : 'Pendent confirmació',
      statusColor: inscription.confirmat ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800',
      paymentText: inscription.pagat ? 'Pagat' : 'Pendent pagament',
      paymentColor: inscription.pagat ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
    };
  }

  function canInscribe(event: any) {
    return event.estat_competicio === 'inscripcions' && !getEventInscriptionStatus(event.id);
  }

  function getEventDescription(event: any) {
    const parts = [];
    if (event.data_inici && event.data_fi) {
      parts.push(`${new Date(event.data_inici).toLocaleDateString('ca-ES')} - ${new Date(event.data_fi).toLocaleDateString('ca-ES')}`);
    }
    if (event.quota_inscripcio) {
      parts.push(`${event.quota_inscripcio}€`);
    }
    if (event.max_participants) {
      parts.push(`Max: ${event.max_participants} jugadors`);
    }
    return parts.join(' • ');
  }
</script>

<svelte:head>
  <title>Inscripcions a campionats socials</title>
</svelte:head>

<div class="ins-root">
  <header class="ins-mast">
    <div class="editorial-eyebrow">Campionats socials</div>
    <h1 class="ins-title">Inscripcions</h1>
    <p class="ins-sub">Inscriu-te als campionats i competicions obertes.</p>
  </header>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} />
  {:else}
    <!-- My Inscriptions -->
    {#if myInscriptions.length > 0}
      <div class="mb-8">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Les Meves Inscripcions</h2>
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <ul class="divide-y divide-gray-200">
            {#each myInscriptions as inscription}
              <li class="px-6 py-4">
                <div class="flex items-center justify-between">
                  <div class="flex-1">
                    <div class="flex items-center">
                      <div>
                        <p class="text-sm font-medium text-gray-900">
                          {inscription.events.nom}
                        </p>
                        <p class="text-sm text-gray-500">
                          {modalityNames[inscription.events.modalitat]} • {inscription.events.temporada}
                        </p>
                        {#if inscription.categoria_assignada}
                          <p class="text-xs text-blue-600 mt-1">
                            Categoria: {inscription.categoria_assignada.nom}
                          </p>
                        {/if}
                      </div>
                    </div>
                  </div>
                  <div class="flex items-center space-x-4">
                    <div class="text-right">
                      <InscriptionStatus
                        confirmed={inscription.confirmat}
                        paid={inscription.pagat}
                        hasQuota={inscription.events.quota_inscripcio > 0}
                        size="sm"
                      />
                    </div>
                  </div>
                </div>
              </li>
            {/each}
          </ul>
        </div>
      </div>
    {/if}

    <!-- Open Events -->
    <div class="mb-8">
      <h2 class="text-lg font-medium text-gray-900 mb-4">Competicions Obertes</h2>

      {#if openEvents.length === 0}
        <div class="text-center py-12 bg-white rounded-lg shadow">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha inscripcions obertes</h3>
          <p class="mt-1 text-sm text-gray-500">
            Actualment no hi ha cap competició amb inscripcions obertes
          </p>
        </div>
      {:else}
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {#each openEvents as event}
            {@const inscriptionStatus = getEventInscriptionStatus(event.id)}
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="p-6">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <div class="flex items-center justify-center h-10 w-10 rounded-md bg-blue-500 text-white">
                      <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                      </svg>
                    </div>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="text-sm font-medium text-gray-900 truncate">
                        {event.nom}
                      </dt>
                      <dd class="text-sm text-gray-500">
                        {modalityNames[event.modalitat]} • {event.temporada}
                      </dd>
                    </dl>
                  </div>
                </div>

                <div class="mt-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {statusColors[event.estat_competicio]}">
                      {statusNames[event.estat_competicio]}
                    </span>
                    <span class="text-xs text-gray-500">
                      {competitionTypes[event.tipus_competicio]}
                    </span>
                  </div>

                  {#if event.categories && event.categories.length > 0}
                    <div class="text-sm text-gray-600 mb-2">
                      <strong>{event.categories.length}</strong> categories disponibles
                    </div>
                  {/if}

                  {#if getEventDescription(event)}
                    <p class="text-xs text-gray-500 mb-4">{getEventDescription(event)}</p>
                  {/if}
                </div>

                <div class="mt-6">
                  {#if inscriptionStatus}
                    <div class="text-center">
                      <InscriptionStatus
                        confirmed={inscriptionStatus.confirmat}
                        paid={inscriptionStatus.pagat}
                        hasQuota={event.quota_inscripcio > 0}
                      />
                    </div>
                  {:else if canInscribe(event)}
                    <a
                      href="/campionats-socials/inscripcions/{event.id}"
                      class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                    >
                      Inscriure's
                    </a>
                  {:else}
                    <div class="text-center">
                      <span class="text-sm text-gray-500">Inscripcions tancades</span>
                    </div>
                  {/if}
                </div>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Help Section -->
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-blue-900 mb-2">Com funcionen les inscripcions?</h3>
      <div class="text-sm text-blue-800 space-y-2">
        <p><strong>1. Inscripció:</strong> Omple el formulari amb les teves preferències horàries</p>
        <p><strong>2. Assignació:</strong> La junta assignarà la categoria segons la teva mitjana històrica</p>
        <p><strong>3. Pagament:</strong> Si hi ha quota, paga l'import indicat per confirmar la inscripció</p>
        <p><strong>4. Calendari:</strong> Un cop validat, rebràs el calendari de partides</p>
      </div>
      <div class="mt-4">
        <p class="text-xs text-blue-600">
          <strong>Nota:</strong> Les inscripcions estan obertes normalment 15 dies abans de l'inici del campionat
        </p>
      </div>
    </div>
  {/if}
</div>

<style>
  .ins-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .ins-mast {
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
  .ins-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .ins-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }

  .ins-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .ins-root :global(.bg-gray-50),
  .ins-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .ins-root :global(.bg-blue-50),
  .ins-root :global(.bg-blue-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--blue, #1f4a99) !important; }
  .ins-root :global(.bg-green-50),
  .ins-root :global(.bg-green-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--green, #1f7a3a) !important; }
  .ins-root :global(.bg-yellow-50),
  .ins-root :global(.bg-yellow-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--amber, #b8860b) !important; }
  .ins-root :global(.bg-red-50),
  .ins-root :global(.bg-red-100) { background: var(--paper, #fbfaf6) !important; border-color: var(--accent, #a30b1e) !important; }
  .ins-root :global(.bg-blue-600),
  .ins-root :global(.bg-blue-700) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .ins-root :global(.bg-green-600),
  .ins-root :global(.bg-green-700) {
    background: var(--green, #1f7a3a) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .ins-root :global(.text-gray-500),
  .ins-root :global(.text-gray-600),
  .ins-root :global(.text-gray-700) { color: var(--ink-2, #4a443e) !important; }
  .ins-root :global(.text-gray-900) { color: var(--ink, #1a1814) !important; }
  .ins-root :global(.text-blue-600),
  .ins-root :global(.text-blue-700),
  .ins-root :global(.text-blue-800),
  .ins-root :global(.text-blue-900) { color: var(--blue, #1f4a99) !important; }
  .ins-root :global(.text-green-600),
  .ins-root :global(.text-green-700),
  .ins-root :global(.text-green-800) { color: var(--green, #1f7a3a) !important; }
  .ins-root :global(.text-red-600),
  .ins-root :global(.text-red-700),
  .ins-root :global(.text-red-800) { color: var(--accent, #a30b1e) !important; }
  .ins-root :global(.text-yellow-700),
  .ins-root :global(.text-yellow-800) { color: var(--amber, #b8860b) !important; }
  .ins-root :global(.border-gray-200),
  .ins-root :global(.border-gray-300) { border-color: var(--rule, #e6e3dc) !important; }
  .ins-root :global(.rounded),
  .ins-root :global(.rounded-md),
  .ins-root :global(.rounded-lg),
  .ins-root :global(.rounded-xl),
  .ins-root :global(.rounded-2xl),
  .ins-root :global(.rounded-full) { border-radius: 0 !important; }
  .ins-root :global(.shadow),
  .ins-root :global(.shadow-sm),
  .ins-root :global(.shadow-md) { box-shadow: none !important; }
  .ins-root :global(input),
  .ins-root :global(select),
  .ins-root :global(textarea) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .ins-root :global(input:focus),
  .ins-root :global(select:focus),
  .ins-root :global(textarea:focus) {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
</style>