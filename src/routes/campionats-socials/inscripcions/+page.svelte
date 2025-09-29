<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { user } from '$lib/stores/auth';
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

  onMount(async () => {
    const u = $user;
    if (!u?.email) {
      goto('/login');
      return;
    }

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
  <title>Inscripcions - Campionat 3 Bandes</title>
</svelte:head>

<div class="max-w-6xl mx-auto p-4">
  <div class="mb-6">
    <h1 class="text-2xl font-semibold text-gray-900">Inscripcions</h1>
    <p class="text-gray-600 mt-1">Inscriu-te als campionats i competicions obertes</p>
  </div>

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
                      href="/inscripcions/{event.id}"
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