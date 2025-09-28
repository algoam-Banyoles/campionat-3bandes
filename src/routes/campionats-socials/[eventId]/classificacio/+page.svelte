<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import Banner from '$lib/components/general/Banner.svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import { formatSupabaseError } from '$lib/ui/alerts';

  let loading = true;
  let error: string | null = null;
  let event: any = null;
  let classificacio: any[] = [];
  let categories: any[] = [];

  const eventId = $page.params.eventId;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  const competitionTypes = {
    'lliga_social': 'Lliga Social',
    'eliminatories': 'Eliminatòries'
  };

  onMount(async () => {
    try {
      loading = true;
      await Promise.all([loadEvent(), loadClassification()]);
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  });

  async function loadEvent() {
    const { supabase } = await import('$lib/supabaseClient');

    const { data, error: eventError } = await supabase
      .from('events')
      .select(`
        *,
        categories (
          id,
          nom,
          distancia_caramboles,
          ordre_categoria
        )
      `)
      .eq('id', eventId)
      .single();

    if (eventError) throw eventError;

    event = data;
    categories = data.categories || [];

    // Check if event is a social league
    if (!['lliga_social', 'eliminatories'].includes(event.tipus_competicio)) {
      error = 'Aquest event no és una lliga social o eliminatòria';
      return;
    }
  }

  async function loadClassification() {
    const { supabase } = await import('$lib/supabaseClient');

    // For social leagues, classification comes from inscriptions and results
    // For now, we'll show inscriptions grouped by category
    const { data: inscriptionsData, error: inscriptionsError } = await supabase
      .from('inscripcions')
      .select(`
        *,
        socis (
          numero_soci,
          nom,
          cognoms
        ),
        categoria_assignada:categories (
          id,
          nom,
          ordre_categoria,
          distancia_caramboles
        )
      `)
      .eq('event_id', eventId)
      .eq('confirmat', true)
      .order('data_inscripcio', { ascending: true });

    if (inscriptionsError) throw inscriptionsError;

    // Group by category and add position within category
    const groupedByCategory = {};

    inscriptionsData?.forEach(inscription => {
      const categoryId = inscription.categoria_assignada_id || 'sense_categoria';
      const categoryName = inscription.categoria_assignada?.nom || 'Sense categoria';

      if (!groupedByCategory[categoryId]) {
        groupedByCategory[categoryId] = {
          category: inscription.categoria_assignada || { nom: 'Sense categoria', ordre_categoria: 999 },
          participants: []
        };
      }

      groupedByCategory[categoryId].participants.push({
        ...inscription,
        posicio: groupedByCategory[categoryId].participants.length + 1
      });
    });

    // Convert to array and sort by category order
    classificacio = Object.values(groupedByCategory).sort((a: any, b: any) =>
      (a.category.ordre_categoria || 999) - (b.category.ordre_categoria || 999)
    );
  }

  function getPlayerAverage(inscription: any) {
    // Try to extract average from observacions
    const observacions = inscription.observacions || '';
    const avgMatch = observacions.match(/Mitjana històrica: ([\d.]+)/);
    return avgMatch ? parseFloat(avgMatch[1]).toFixed(2) : '-';
  }
</script>

<svelte:head>
  <title>Classificació - {event?.nom || 'Lliga Social'}</title>
</svelte:head>

<div class="max-w-6xl mx-auto p-4">
  <div class="mb-6">
    <div class="flex items-center space-x-4 mb-2">
      <a
        href="/campionats-socials/{eventId}"
        class="text-gray-600 hover:text-gray-900"
      >
        ← Tornar a l'event
      </a>
    </div>

    {#if event}
      <h1 class="text-2xl font-semibold text-gray-900">Classificació</h1>
      <div class="flex items-center space-x-4 text-sm text-gray-600 mt-1">
        <span>{event.nom}</span>
        <span>•</span>
        <span>{modalityNames[event.modalitat]}</span>
        <span>•</span>
        <span>{event.temporada}</span>
        <span>•</span>
        <span>{competitionTypes[event.tipus_competicio]}</span>
      </div>
    {/if}
  </div>

  {#if loading}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} />
  {:else if event}
    {#if classificacio.length === 0}
      <div class="text-center py-12 bg-white rounded-lg shadow">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha participants</h3>
        <p class="mt-1 text-sm text-gray-500">Aquest event encara no té participants confirmats</p>
      </div>
    {:else}
      <!-- Classification by Categories -->
      <div class="space-y-8">
        {#each classificacio as categoryGroup}
          <div class="bg-white shadow rounded-lg overflow-hidden">
            <div class="bg-gray-50 px-6 py-3 border-b">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-medium text-gray-900">
                  {categoryGroup.category.nom}
                </h3>
                {#if categoryGroup.category.distancia_caramboles}
                  <span class="text-sm text-gray-500">
                    {categoryGroup.category.distancia_caramboles} caramboles
                  </span>
                {/if}
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Pos.
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Jugador
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Mitjana Històrica
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Data Inscripció
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Estat
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  {#each categoryGroup.participants as participant, i}
                    <tr class="hover:bg-gray-50">
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        {i + 1}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="flex items-center">
                          <div>
                            <div class="text-sm font-medium text-gray-900">
                              {participant.socis.nom} {participant.socis.cognoms}
                            </div>
                            <div class="text-sm text-gray-500">
                              Soci #{participant.socis.numero_soci}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {getPlayerAverage(participant)}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {new Date(participant.data_inscripcio).toLocaleDateString('ca-ES')}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="flex space-x-2">
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {participant.confirmat ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'}">
                            {participant.confirmat ? 'Confirmat' : 'Pendent'}
                          </span>
                          {#if event.quota_inscripcio > 0}
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {participant.pagat ? 'bg-blue-100 text-blue-800' : 'bg-red-100 text-red-800'}">
                              {participant.pagat ? 'Pagat' : 'Pendent pagament'}
                            </span>
                          {/if}
                        </div>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>

            <!-- Category summary -->
            <div class="bg-gray-50 px-6 py-3 border-t">
              <p class="text-sm text-gray-600">
                <strong>{categoryGroup.participants.length}</strong> participant{categoryGroup.participants.length !== 1 ? 's' : ''}
                {#if categoryGroup.category.distancia_caramboles}
                  • Distància: {categoryGroup.category.distancia_caramboles} caramboles
                {/if}
              </p>
            </div>
          </div>
        {/each}
      </div>

      <!-- Event summary -->
      <div class="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <h3 class="text-lg font-medium text-blue-900 mb-2">Resum de l'Event</h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <div>
            <span class="font-medium text-blue-800">Total participants:</span>
            <span class="text-blue-700">{classificacio.reduce((sum, cat) => sum + cat.participants.length, 0)}</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Categories:</span>
            <span class="text-blue-700">{classificacio.length}</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Modalitat:</span>
            <span class="text-blue-700">{modalityNames[event.modalitat]}</span>
          </div>
        </div>
      </div>
    {/if}
  {/if}
</div>