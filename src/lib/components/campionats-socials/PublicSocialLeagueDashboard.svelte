<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { getSocialLeagueEventById } from '$lib/api/socialLeagues';
  import SocialLeagueCalendarViewer from './SocialLeagueCalendarViewer.svelte';
  import SocialLeaguePlayersGrid from './SocialLeaguePlayersGrid.svelte';
  import SocialLeagueClassifications from './SocialLeagueClassifications.svelte';
  import SocialLeagueMatchResults from './SocialLeagueMatchResults.svelte';
  import UserMatchesWidget from './UserMatchesWidget.svelte';

  const dispatch = createEventDispatcher();

  export let event: any = null;
  export let isLoggedIn: boolean = false;
  export let currentUserEmail: string = '';
  export let showMyMatches: boolean = true;

  let activeTab: 'players' | 'calendar' | 'results' | 'classifications' = 'players';
  let loading = false;
  let error: string | null = null;
  let fullEventData: any = null;

  // Carregar dades completes de l'event quan canvia
  $: if (event?.id) {
    loadFullEventData();
  }

  async function loadFullEventData() {
    if (!event?.id) return;

    loading = true;
    error = null;

    try {
      fullEventData = await getSocialLeagueEventById(event.id);
      console.log('🔍 PublicSocialLeagueDashboard - fullEventData loaded:', fullEventData);
      console.log('   - ID:', fullEventData?.id);
      console.log('   - Categories:', fullEventData?.categories?.length);
    } catch (e) {
      console.error('❌ Error loading full event data:', e);
      error = 'Error carregant les dades del campionat';
    } finally {
      loading = false;
    }
  }

  function handleTabChange(newTab: 'players' | 'calendar' | 'results' | 'classifications') {
    activeTab = newTab;
  }
</script>

<div class="space-y-6">
  <!-- Header del campionat -->
  <div class="bg-gradient-to-r from-green-600 to-blue-600 text-white rounded-lg p-6">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold">
          {event.nom}
        </h1>
        <p class="text-green-100 mt-1">
          Temporada {event.temporada} •
          {event.modalitat === 'tres_bandes' ? '3 Bandes' :
           event.modalitat === 'lliure' ? 'Lliure' : 'Banda'}
        </p>

        <div class="flex items-center space-x-4 mt-3">
          <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
            🏆 En Curs
          </span>

          {#if event.data_inici}
            <span class="text-green-100 text-sm">
              📅 Inici: {new Date(event.data_inici).toLocaleDateString('ca-ES')}
            </span>
          {/if}
        </div>
      </div>

      <div class="text-right">
        <div class="text-3xl font-bold text-white">
          {fullEventData?.categories?.length || event.categories?.length || 0}
        </div>
        <div class="text-green-100 text-sm">Categories</div>
      </div>
    </div>
  </div>

  <!-- Widget "Les meves partides" (només per usuaris logats) -->
  {#if isLoggedIn && showMyMatches && currentUserEmail}
    <UserMatchesWidget
      eventId={event.id}
      userEmail={currentUserEmail}
      eventName={event.nom}
    />
  {/if}

  <!-- Navegació per pestanyes -->
  <div class="border-b border-gray-200">
    <nav class="-mb-px flex space-x-4 md:space-x-8">
      <button
        on:click={() => handleTabChange('players')}
        class="py-2 px-1 border-b-2 font-medium text-2xl md:text-base"
        class:border-blue-500={activeTab === 'players'}
        class:text-blue-600={activeTab === 'players'}
        class:border-transparent={activeTab !== 'players'}
        class:text-gray-500={activeTab !== 'players'}
        class:hover:text-gray-700={activeTab !== 'players'}
        class:hover:border-gray-300={activeTab !== 'players'}
        title="Jugadors per Categories"
      >
        <span class="md:hidden">👥</span>
        <span class="hidden md:inline">👥 Jugadors per Categories</span>
      </button>

      <button
        on:click={() => handleTabChange('calendar')}
        class="py-2 px-1 border-b-2 font-medium text-2xl md:text-base"
        class:border-blue-500={activeTab === 'calendar'}
        class:text-blue-600={activeTab === 'calendar'}
        class:border-transparent={activeTab !== 'calendar'}
        class:text-gray-500={activeTab !== 'calendar'}
        class:hover:text-gray-700={activeTab !== 'calendar'}
        class:hover:border-gray-300={activeTab !== 'calendar'}
        title="Calendari"
      >
        <span class="md:hidden">📅</span>
        <span class="hidden md:inline">📅 Calendari</span>
      </button>

      <button
        on:click={() => handleTabChange('results')}
        class="py-2 px-1 border-b-2 font-medium text-2xl md:text-base"
        class:border-blue-500={activeTab === 'results'}
        class:text-blue-600={activeTab === 'results'}
        class:border-transparent={activeTab !== 'results'}
        class:text-gray-500={activeTab !== 'results'}
        class:hover:text-gray-700={activeTab !== 'results'}
        class:hover:border-gray-300={activeTab !== 'results'}
        title="Resultats"
      >
        <span class="md:hidden">⚡</span>
        <span class="hidden md:inline">⚡ Resultats</span>
      </button>

      <button
        on:click={() => handleTabChange('classifications')}
        class="py-2 px-1 border-b-2 font-medium text-2xl md:text-base"
        class:border-blue-500={activeTab === 'classifications'}
        class:text-blue-600={activeTab === 'classifications'}
        class:border-transparent={activeTab !== 'classifications'}
        class:text-gray-500={activeTab !== 'classifications'}
        class:hover:text-gray-700={activeTab !== 'classifications'}
        class:hover:border-gray-300={activeTab !== 'classifications'}
        title="Classificacions"
      >
        <span class="md:hidden">🏆</span>
        <span class="hidden md:inline">🏆 Classificacions</span>
      </button>
    </nav>
  </div>

  <!-- Contingut de les pestanyes -->
  {#if loading}
    <div class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant dades...</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-red-800 mb-2">Error</h3>
      <p class="text-red-600">{error}</p>
    </div>
  {:else if fullEventData}
    <!-- Jugadors per Categories -->
    {#if activeTab === 'players'}
      <SocialLeaguePlayersGrid
        eventId={event.id}
        categories={fullEventData.categories || []}
      />

    <!-- Calendari -->
    {:else if activeTab === 'calendar'}
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <SocialLeagueCalendarViewer
            eventId={event.id}
            categories={fullEventData.categories || []}
            isAdmin={false}
            eventData={fullEventData}
            defaultMode="timeline"
            editMode={false}
          />
        </div>
      </div>

    <!-- Resultats -->
    {:else if activeTab === 'results'}
      <SocialLeagueMatchResults
        eventId={event.id}
        categories={fullEventData.categories || []}
      />

    <!-- Classificacions -->
    {:else if activeTab === 'classifications'}
      {#if fullEventData?.id}
        <SocialLeagueClassifications
          event={fullEventData}
          showDetails={true}
        />
      {:else}
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
          <p class="text-yellow-800">⚠️ DEBUG: fullEventData no té ID</p>
          <pre class="text-xs mt-2">{JSON.stringify(fullEventData, null, 2)}</pre>
        </div>
      {/if}
    {/if}
  {/if}
</div>