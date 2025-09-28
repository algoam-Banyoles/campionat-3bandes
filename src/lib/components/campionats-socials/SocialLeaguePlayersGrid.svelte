<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  export let eventId: string = '';
  export let categories: any[] = [];

  let inscriptions: any[] = [];
  let loadedCategories: any[] = [];
  let loading = false;
  let error: string | null = null;

  onMount(() => {
    if (eventId && eventId.trim() !== '') {
      loadInscriptions();
    }
  });

  $: if (eventId && eventId.trim() !== '') {
    loadInscriptions();
  } else if (eventId === '') {
    inscriptions = [];
  }



  async function loadInscriptions() {
    loading = true;
    error = null;

    try {
      console.log('🔍 SocialLeaguePlayersGrid: Loading inscriptions with RPC function for event:', eventId);
      
      // Carregar categories de l'esdeveniment si no es passen per prop
      if (categories.length === 0) {
        console.log('🔍 Loading categories for event with RPC:', eventId);
        const { data: categoriesData, error: categoriesError } = await supabase
          .rpc('get_categories_for_event', {
            p_event_id: eventId
          });
        
        if (categoriesError) {
          console.error('❌ Error loading categories with RPC:', categoriesError);
        } else if (categoriesData) {
          loadedCategories = categoriesData;
          console.log('✅ Loaded categories with RPC:', loadedCategories.length, loadedCategories.map(c => c.nom));
        } else {
          console.log('⚠️ No categories found');
        }
      } else {
        loadedCategories = categories;
        console.log('✅ Using categories from props:', loadedCategories.length);
      }
      
      // Utilitzar la funció RPC que permet accés públic (anònim i autenticat)
      const { data: inscriptionsData, error: inscriptionsError } = await supabase
        .rpc('get_inscripcions_with_socis', {
          p_event_id: eventId
        });

      if (inscriptionsError) {
        console.error('❌ Error loading inscriptions with RPC:', inscriptionsError);
        throw inscriptionsError;
      }

      console.log('✅ Loaded inscriptions:', inscriptionsData?.length || 0);

      if (!inscriptionsData || inscriptionsData.length === 0) {
        inscriptions = [];
        console.log('ℹ️ No inscriptions found for event');
        return;
      }

      // Les dades ja inclouen informació dels socis gràcies a la funció RPC
      inscriptions = inscriptionsData.map(item => ({
        id: item.id,
        soci_numero: item.soci_numero,
        categoria_assignada_id: item.categoria_assignada_id,
        data_inscripcio: item.data_inscripcio,
        pagat: item.pagat,
        confirmat: item.confirmat,
        created_at: item.created_at,
        socis: {
          numero_soci: item.soci_numero,
          nom: item.nom,
          cognoms: item.cognoms,
          email: item.email,
          de_baixa: item.de_baixa
        }
      }));
      
      console.log('✅ Final inscriptions processed:', inscriptions.length);
    } catch (e) {
      console.error('❌ Error loading inscriptions:', e);
      error = 'Error carregant les inscripcions';
    } finally {
      loading = false;
    }
  }

  function getPlayersInCategory(categoryId: string) {
    return inscriptions.filter(i => i.categoria_assignada_id === categoryId);
  }

  function getPlayersWithoutCategory() {
    return inscriptions.filter(i => !i.categoria_assignada_id);
  }

  // Utilitzar les categories carregades o les rebudes per prop
  $: finalCategories = loadedCategories.length > 0 ? loadedCategories : categories;
  $: sortedCategories = finalCategories.sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));
  $: playersWithoutCategory = getPlayersWithoutCategory();
  
  // Debug per veure què està passant
  $: {
    console.log('🔍 DEBUG SocialLeaguePlayersGrid:');
    console.log('  - Total inscriptions:', inscriptions.length);
    console.log('  - Categories received from prop:', categories.length, categories.map(c => c?.nom));
    console.log('  - Categories loaded directly:', loadedCategories.length, loadedCategories.map(c => c?.nom));
    console.log('  - Final categories used:', finalCategories.length, finalCategories.map(c => c?.nom));
    console.log('  - Players without category:', playersWithoutCategory.length);
    if (inscriptions.length > 0 && finalCategories.length > 0) {
      finalCategories.forEach(cat => {
        const playersInCat = getPlayersInCategory(cat.id);
        console.log(`  - ${cat.nom}: ${playersInCat.length} jugadors`);
      });
    }
  }
</script>

<div class="space-y-6">
  {#if loading}
    <div class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant jugadors...</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-red-800 mb-2">Error</h3>
      <p class="text-red-600">{error}</p>
    </div>
  {:else if inscriptions.length === 0}
    <div class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha jugadors inscrits</h3>
      <p class="mt-1 text-sm text-gray-500">Els jugadors apareixeran aquí quan es facin les inscripcions.</p>
    </div>
  {:else}
    <!-- Si les categories encara es carreguen, mostrar tots els jugadors temporalment -->
    {#if finalCategories.length === 0 && inscriptions.length > 0}
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="text-center mb-4 pb-3 border-b border-blue-200">
          <h3 class="text-lg font-bold text-gray-900">📋 Tots els Jugadors Inscrits</h3>
          <p class="text-sm text-blue-600 font-medium">
            Carregant categories...
          </p>
          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mt-2">
            {inscriptions.length} jugadors
          </span>
        </div>

        <div class="space-y-2 max-h-96 overflow-y-auto">
          {#each inscriptions as inscription (inscription.id)}
            {@const soci = inscription.socis}
            {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
            {@const cognoms = soci?.cognoms || `Soci #${inscription.soci_numero}`}
            <div class="flex items-center justify-between py-1">
              <div class="flex items-center">
                <div class="w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center text-sm font-bold mr-3">
                  {inicialNom}
                </div>
                <span class="text-sm font-medium text-gray-900">
                  {cognoms}
                </span>
              </div>
            </div>
          {/each}
        </div>
      </div>
    {:else}
    <!-- Categories compactes amb jugadors -->
    <div class="flex flex-wrap gap-4">
      {#each sortedCategories as category (category.id)}
        {@const playersInCategory = getPlayersInCategory(category.id)}
        {#if playersInCategory.length > 0}
          <div class="bg-white border-2 border-gray-200 rounded-lg p-3 min-w-fit hover:shadow-lg transition-shadow">
            <!-- Capçalera de categoria -->
            <div class="text-center mb-3 pb-2 border-b border-gray-200">
              <h3 class="text-sm font-bold text-gray-900 whitespace-nowrap">{category.nom}</h3>
              <p class="text-xs text-blue-600 font-medium whitespace-nowrap">
                {category.distancia_caramboles} car. • {playersInCategory.length} jug.
              </p>
            </div>

            <!-- Llista de jugadors compacta -->
            <div class="space-y-2">
              {#each playersInCategory as inscription (inscription.id)}
                {@const soci = inscription.socis}
                {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
                {@const primerCognom = soci?.cognoms ? soci.cognoms.split(' ')[0] : ''}
                {@const nomComplet = soci ? `${inicialNom}. ${primerCognom}` : `Soci #${inscription.soci_numero}`}
                <div class="flex items-center py-1">
                  <div class="flex items-center">
                    <div class="w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center text-xs font-bold mr-2 flex-shrink-0">
                      {inicialNom}
                    </div>
                    <span class="text-xs text-gray-900 whitespace-nowrap">
                      {nomComplet}
                    </span>
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      {/each}

      <!-- Jugadors sense categoria (si n'hi ha) -->
      {#if playersWithoutCategory.length > 0}
        <div class="bg-yellow-50 border-2 border-yellow-300 rounded-lg p-4">
          <div class="text-center mb-4 pb-3 border-b border-yellow-300">
            <h3 class="text-lg font-bold text-gray-900">⚠️ Sense Categoria</h3>
            <p class="text-sm text-orange-600 font-medium">
              Pendent assignació
            </p>
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-200 text-yellow-800 mt-2">
              {playersWithoutCategory.length} jugadors
            </span>
          </div>

          <div class="space-y-2">
            {#each playersWithoutCategory as inscription (inscription.id)}
              {@const soci = inscription.socis}
              {@const inicialNom = soci?.nom ? soci.nom.charAt(0).toUpperCase() : '?'}
              {@const cognoms = soci?.cognoms || `Soci #${inscription.soci_numero}`}
              <div class="flex items-center py-1">
                <div class="flex items-center">
                  <div class="w-8 h-8 bg-yellow-500 text-white rounded-full flex items-center justify-center text-sm font-bold mr-3">
                    {inicialNom}
                  </div>
                  <span class="text-sm font-medium text-gray-900">
                    {cognoms}
                  </span>
                </div>
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>
    {/if}
  {/if}
</div>
