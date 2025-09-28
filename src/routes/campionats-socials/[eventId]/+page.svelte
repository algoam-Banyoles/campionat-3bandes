<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { getSocialLeagueEventById } from '$lib/api/socialLeagues';
  import ClassificationTable from '$lib/components/campionat-continu/ClassificationTable.svelte';
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
      event = await getSocialLeagueEventById(eventId);
      if (!event) {
        error = 'Event no trobat';
      } else {
        pageTitle = `${modalityNames[event.modalitat]} ${event.temporada} - Lligues Socials`;
      }
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
    {#if event.categories && event.categories.length > 0}
      <div class="space-y-8">
        {#each event.categories as category}
          <div class="bg-white border border-gray-200 rounded-lg">
            <!-- Header de la categoria -->
            <div class="bg-gray-50 px-6 py-4 border-b border-gray-200 rounded-t-lg">
              <div class="flex items-center justify-between">
                <div>
                  <h2 class="text-xl font-semibold text-gray-900">{category.nom}</h2>
                  <p class="text-sm text-gray-600 mt-1">
                    Distància: {category.distancia_caramboles} caramboles
                    {#if category.classificacions.length > 0}
                      • {category.classificacions.length} jugadors
                    {/if}
                  </p>
                </div>

                {#if category.classificacions.length > 0}
                  <div class="text-right">
                    <div class="text-lg font-bold text-green-600">
                      {category.classificacions[0]?.player_nom}
                    </div>
                    <div class="text-sm text-gray-600">Campió</div>
                  </div>
                {/if}
              </div>
            </div>

            <!-- Classificacions -->
            <div class="p-0">
              {#if category.classificacions && category.classificacions.length > 0}
                <ClassificationTable
                  classifications={category.classificacions}
                  title=""
                  showStats={true}
                />
              {:else}
                <div class="p-6 text-center text-gray-500">
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
{/if}