<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabaseClient';
  import type { SocialLeagueEvent } from '$lib/types';

  let event: SocialLeagueEvent | null = null;
  let loading = true;
  let error: string | null = null;
  let pageTitle = 'Event - Lligues Socials';

  const eventId = $page.params.eventId;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  onMount(async () => {
    if (!eventId) {
      error = 'ID de l\'event no trobat';
      loading = false;
      return;
    }

    try {
      // Get basic event data using RPC for anonymous access
      const { data: eventResult, error: eventError } = await supabase
        .rpc('get_event_public', { p_event_id: eventId });

      const eventData = eventResult?.[0];

      if (eventError) throw eventError;

      if (!eventData) {
        error = 'Event no trobat';
        loading = false;
        return;
      }

      // Get categories using RPC
      const { data: categoriesData, error: categoriesError } = await supabase
        .rpc('get_categories_for_event', { p_event_id: eventId });

      if (categoriesError) throw categoriesError;

      // Get classifications using RPC
      const { data: classificationsData, error: classificationsError } = await supabase
        .rpc('get_classifications_public', { 
          event_id_param: eventId,
          category_ids: null 
        });

      if (classificationsError) throw classificationsError;

      // Group classifications by category
      const classificationsByCategory = {};
      if (classificationsData) {
        classificationsData.forEach(cl => {
          if (!classificationsByCategory[cl.categoria_id]) {
            classificationsByCategory[cl.categoria_id] = [];
          }
          classificationsByCategory[cl.categoria_id].push({
            id: cl.id,
            posicio: cl.posicio,
            player_id: cl.player_id,
            player_nom: cl.soci_nom || '',
            player_cognom: cl.soci_cognoms || '',
            partides_jugades: cl.partides_jugades,
            partides_guanyades: cl.partides_guanyades,
            partides_perdudes: cl.partides_perdudes,
            partides_empat: cl.partides_empat,
            punts: cl.punts,
            caramboles_favor: cl.caramboles_favor,
            caramboles_contra: cl.caramboles_contra,
            mitjana_particular: cl.mitjana_particular
          });
        });
      }

      // Combine data
      event = {
        ...eventData,
        categories: (categoriesData || []).map(cat => ({
          ...cat,
          classificacions: classificationsByCategory[cat.id] || []
        }))
      };

      pageTitle = `${modalityNames[event.modalitat]} ${event.temporada} - Lligues Socials`;
    } catch (e) {
      error = 'Error carregant l\'event';
      console.error(e);
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>{pageTitle}</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center min-h-64">
    <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
  </div>
{:else if error}
  <div class="bg-red-50 border border-red-200 rounded-lg p-6">
    <h3 class="text-lg font-medium text-red-800 mb-2">Error</h3>
    <p class="text-red-600">{error}</p>
    <a href="/campionats-socials" class="mt-4 inline-block text-blue-600 hover:text-blue-800">
      ← Tornar a lligues socials
    </a>
  </div>
{:else if event}
  <div class="space-y-6">
    <!-- Header -->
    <div class="bg-white border border-gray-200 rounded-lg p-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">
            {modalityNames[event.modalitat]} {event.temporada}
          </h1>
          <p class="text-gray-600 mt-1">{event.nom}</p>

          <div class="flex items-center space-x-4 mt-3">
            <span class={`px-3 py-1 rounded-full text-sm font-medium ${
              event.actiu
                ? 'bg-green-100 text-green-800'
                : 'bg-gray-100 text-gray-600'
            }`}>
              {event.actiu ? 'Actiu' : 'Finalitzat'}
            </span>

            {#if event.data_inici && event.data_fi}
              <span class="text-sm text-gray-500">
                {new Date(event.data_inici).toLocaleDateString('ca-ES')} -
                {new Date(event.data_fi).toLocaleDateString('ca-ES')}
              </span>
            {/if}
          </div>
        </div>

        <div class="text-right">
          <div class="mb-3">
            <a
              href="/campionats-socials/{eventId}/classificacio"
              class="inline-flex items-center px-4 py-2 border border-blue-300 rounded-md text-sm font-medium text-blue-700 bg-blue-50 hover:bg-blue-100"
            >
              📊 Classificació
            </a>
          </div>
          <div class="text-2xl font-bold text-blue-600">{event.categories.length}</div>
          <div class="text-sm text-gray-600">Categories</div>
        </div>
      </div>
    </div>

    <!-- Categories i Classificacions -->
    <div class="space-y-6">
      <h2 class="text-2xl font-bold text-gray-900">Classificacions per Categories</h2>
      
      {#if event.categories && event.categories.length > 0}
        <div class="space-y-8">
          {#each event.categories as category}
            <div class="bg-white border border-gray-200 rounded-lg">
              <!-- Header de la categoria -->
              <div class="bg-gray-50 px-6 py-4 border-b border-gray-200 rounded-t-lg">
                <h3 class="text-xl font-semibold text-gray-900">{category.nom}</h3>
                <p class="text-sm text-gray-600 mt-1">
                  Distància: {category.distancia_caramboles} caramboles
                </p>
              </div>

              <!-- Classificacions -->
              <div class="p-6">
                {#if category.classificacions && category.classificacions.length > 0}
                  <div class="overflow-x-auto">
                    <table class="min-w-full divide-y divide-gray-200">
                      <thead class="bg-gray-50">
                        <tr>
                          <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Pos
                          </th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Jugador
                          </th>
                          <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                            PJ
                          </th>
                          <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                            PG
                          </th>
                          <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                            PP
                          </th>
                          <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Punts
                          </th>
                          <th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Mitjana
                          </th>
                        </tr>
                      </thead>
                      <tbody class="bg-white divide-y divide-gray-200">
                        {#each category.classificacions as player, index}
                          <tr class="hover:bg-gray-50">
                            <td class="px-3 py-4 whitespace-nowrap text-sm font-medium text-gray-900 text-center">
                              {index + 1}
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <div class="text-sm font-medium text-gray-900">{player.player_nom}</div>
                            </td>
                            <td class="px-3 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
                              {player.partides_jugades || 0}
                            </td>
                            <td class="px-3 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
                              {player.partides_guanyades || 0}
                            </td>
                            <td class="px-3 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
                              {player.partides_perdudes || 0}
                            </td>
                            <td class="px-3 py-4 whitespace-nowrap text-sm font-medium text-gray-900 text-center">
                              {player.punts || 0}
                            </td>
                            <td class="px-3 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
                              {player.mitjana ? player.mitjana.toFixed(3) : '0.000'}
                            </td>
                          </tr>
                        {/each}
                      </tbody>
                    </table>
                  </div>
                {:else}
                  <div class="text-center text-gray-500 py-8">
                    <p>No hi ha classificacions disponibles per aquesta categoria</p>
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      {:else}
        <div class="bg-white border border-gray-200 rounded-lg p-6">
          <p class="text-center text-gray-500">No hi ha categories disponibles per aquest event</p>
        </div>
      {/if}
    </div>
  </div>
{/if}