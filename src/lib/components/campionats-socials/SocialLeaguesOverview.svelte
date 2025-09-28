<script lang="ts">
  import { onMount } from 'svelte';
  import { getSocialLeagueStats, getSocialLeagueEventsBySeasonAndModality } from '$lib/api/socialLeagues';
  import type { SocialLeagueEvent } from '$lib/types';

  let stats: any = null;
  let eventsBySeason: { [temporada: string]: { [modalitat: string]: SocialLeagueEvent } } = {};
  let loading = true;
  let error: string | null = null;

  const modalityNames = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };

  onMount(async () => {
    try {
      const [statsData, eventsData] = await Promise.all([
        getSocialLeagueStats(),
        getSocialLeagueEventsBySeasonAndModality()
      ]);
      stats = statsData;
      eventsBySeason = eventsData;
    } catch (e) {
      error = 'Error carregant les dades de les lligues socials';
      console.error(e);
    } finally {
      loading = false;
    }
  });
</script>

<div class="space-y-6">
  <!-- Estadístiques Generals -->
  {#if loading}
    <div class="animate-pulse space-y-4">
      <div class="h-32 bg-gray-200 rounded-lg"></div>
      <div class="h-32 bg-gray-200 rounded-lg"></div>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-4">
      <p class="text-red-700">{error}</p>
    </div>
  {:else if stats}
    <!-- Cards Estadístiques -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-blue-900 mb-2">Events Històrics</h3>
        <p class="text-3xl font-bold text-blue-600">{stats.total_events}</p>
        <p class="text-sm text-blue-700 mt-1">Lligues socials registrades</p>
      </div>

      <div class="bg-green-50 border border-green-200 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-green-900 mb-2">Categories</h3>
        <p class="text-3xl font-bold text-green-600">{stats.total_categories}</p>
        <p class="text-sm text-green-700 mt-1">Categories creades</p>
      </div>

      <div class="bg-purple-50 border border-purple-200 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-purple-900 mb-2">Classificacions</h3>
        <p class="text-3xl font-bold text-purple-600">{stats.total_classifications}</p>
        <p class="text-sm text-purple-700 mt-1">Posicions registrades</p>
      </div>
    </div>

    <!-- Events per Temporada -->
    <div class="bg-white border border-gray-200 rounded-lg">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Lligues per Temporada</h3>
      </div>
      <div class="p-6">
        <div class="space-y-6">
          {#each Object.entries(eventsBySeason).sort(([a], [b]) => b.localeCompare(a)) as [temporada, modalitats]}
            <div>
              <h4 class="text-md font-medium text-gray-800 mb-3">Temporada {temporada}</h4>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                {#each Object.entries(modalitats) as [modalitat, event]}
                  <a
                    href="/campionats-socials/{event.id}"
                    class="block border border-gray-200 rounded-lg p-4 hover:bg-gray-50 hover:border-blue-300 transition-all duration-200 group"
                  >
                    <div class="flex items-center justify-between mb-2">
                      <h5 class="font-medium text-gray-900 group-hover:text-blue-700">{modalityNames[modalitat]}</h5>
                      <span class={`px-2 py-1 rounded-full text-xs font-medium ${
                        event.actiu
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-600'
                      }`}>
                        {event.actiu ? 'Actiu' : 'Finalitzat'}
                      </span>
                    </div>
                    <p class="text-sm text-gray-600 mb-2">{event.categories.length} categories</p>
                    <div class="flex flex-wrap gap-1">
                      {#each event.categories.slice(0, 3) as category}
                        <span class="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded">
                          {category.nom}
                        </span>
                      {/each}
                      {#if event.categories.length > 3}
                        <span class="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded">
                          +{event.categories.length - 3} més
                        </span>
                      {/if}
                    </div>

                    {#if event.data_inici && event.data_fi}
                      <p class="text-xs text-gray-500 mt-2">
                        {new Date(event.data_inici).toLocaleDateString('ca-ES')} -
                        {new Date(event.data_fi).toLocaleDateString('ca-ES')}
                      </p>
                    {/if}

                    <div class="flex items-center justify-end mt-3 text-blue-600 group-hover:text-blue-700">
                      <span class="text-xs font-medium">Veure detalls</span>
                      <svg class="ml-1 h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                      </svg>
                    </div>
                  </a>
                {/each}
              </div>
            </div>
          {/each}
        </div>
      </div>
    </div>

    <!-- Distribució per Modalitat -->
    <div class="bg-white border border-gray-200 rounded-lg">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Distribució per Modalitat</h3>
      </div>
      <div class="p-6">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          {#each Object.entries(stats.events_per_modality) as [modalitat, count]}
            <div class="text-center">
              <div class="text-2xl font-bold text-gray-900">{count}</div>
              <div class="text-sm text-gray-600">{modalityNames[modalitat]}</div>
              <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
                <div
                  class="bg-blue-600 h-2 rounded-full"
                  style="width: {(count / stats.total_events) * 100}%"
                ></div>
              </div>
            </div>
          {/each}
        </div>
      </div>
    </div>
  {/if}
</div>