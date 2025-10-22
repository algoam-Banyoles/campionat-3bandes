<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import HeadToHeadGrid from '$lib/components/campionats-socials/HeadToHeadGrid.svelte';

  let selectedEvent: any = null;
  let categories: any[] = [];
  let selectedCategory: any = null;
  let loading = false;
  let error = '';

  onMount(async () => {
    await loadActiveEvent();
  });

  async function loadActiveEvent() {
    try {
      loading = true;
      // Load the single active social league event
      const { data: eventData, error: eventError } = await supabase
        .from('events')
        .select('*')
        .eq('actiu', true)
        .eq('estat_competicio', 'en_curs')
        .eq('tipus_competicio', 'lliga_social')
        .order('temporada', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (eventError) throw eventError;

      if (!eventData) {
        error = 'No hi ha cap campionat social actiu i en curs';
        loading = false;
        return;
      }

      selectedEvent = eventData;

      // Load categories for the active event
      const { data: categoriesData, error: categoriesError } = await supabase
        .from('categories')
        .select('*')
        .eq('event_id', selectedEvent.id)
        .order('ordre_categoria');

      if (categoriesError) throw categoriesError;
      categories = categoriesData || [];

      // Auto-select first category if available
      if (categories.length > 0) {
        selectedCategory = categories[0];
      }

    } catch (e) {
      console.error('Error loading active event:', e);
      error = 'Error carregant el campionat actiu';
    } finally {
      loading = false;
    }
  }

  function selectCategory(category: any) {
    selectedCategory = category;
  }

  const modalityNames: Record<string, string> = {
    'tres_bandes': '3 Bandes',
    'lliure': 'Lliure',
    'banda': 'Banda'
  };
</script>

<svelte:head>
  <title>Graella de Resultats - Administració</title>
</svelte:head>

<div class="container mx-auto px-4 py-8 max-w-7xl">
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900 mb-2">Graella de Resultats Creuats</h1>
    <p class="text-gray-600">Visualitza la matriu de resultats entre jugadors d'una categoria</p>
  </div>

  {#if loading}
    <div class="flex items-center justify-center min-h-64">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-red-800 mb-2">Error</h3>
      <p class="text-red-600">{error}</p>
      <button
        on:click={loadActiveEvent}
        class="mt-4 inline-block px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
      >
        Tornar a intentar
      </button>
    </div>
  {:else if selectedEvent}
    <div class="space-y-6">
      <!-- Event Info -->
      <div class="bg-white border border-gray-200 rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-xl font-bold text-gray-900">
              {modalityNames[selectedEvent.modalitat] || selectedEvent.modalitat} {selectedEvent.temporada}
            </h2>
            <p class="text-gray-600 mt-1">{selectedEvent.nom}</p>
            <span class="inline-block mt-2 px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
              En curs
            </span>
          </div>
          <div class="text-right">
            <div class="text-2xl font-bold text-blue-600">{categories.length}</div>
            <div class="text-sm text-gray-600">Categories</div>
          </div>
        </div>
      </div>

      <!-- Category Selection -->
      {#if categories.length > 0}
        <div class="bg-white border border-gray-200 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Selecciona una categoria</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {#each categories as category}
              <button
                on:click={() => selectCategory(category)}
                class="p-4 border-2 rounded-lg text-left transition-all {
                  selectedCategory?.id === category.id
                    ? 'border-blue-500 bg-blue-50'
                    : 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'
                }"
              >
                <div class="font-semibold text-gray-900">{category.nom}</div>
                <div class="text-sm text-gray-600 mt-1">
                  Distància: {category.distancia_caramboles} caramboles
                </div>
                <div class="text-sm text-gray-600">
                  Max. entrades: {category.max_entrades}
                </div>
              </button>
            {/each}
          </div>
        </div>

        <!-- Head-to-Head Grid -->
        {#if selectedCategory}
          <div class="bg-white border border-gray-200 rounded-lg p-6">
            <HeadToHeadGrid
              eventId={selectedEvent.id}
              categoriaId={selectedCategory.id}
              categoriaNom={selectedCategory.nom}
            />
          </div>
        {/if}
      {:else}
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
          <p class="text-yellow-800">No hi ha categories configurades per aquest campionat.</p>
        </div>
      {/if}
    </div>
  {:else}
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
      <p class="text-yellow-800">No hi ha cap campionat social actiu i en curs.</p>
    </div>
  {/if}
</div>

<style>
  :global(body) {
    background-color: #f9fafb;
  }
</style>
