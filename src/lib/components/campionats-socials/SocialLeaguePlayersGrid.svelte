<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  export let eventId: string = '';
  export let categories: any[] = [];

  let inscriptions: any[] = [];
  let loading = false;
  let error: string | null = null;

  onM      </div>
  {/if} {
    if (eventId) {
      loadInscriptions();
    }
  });

  $: if (eventId) {
    loadInscriptions();
  }

  async function loadInscriptions() {
    console.log('🔍 SocialLeaguePlayersGrid: Starting to load inscriptions for eventId:', eventId);
    console.log('🔍 Categories passed:', categories.length);

    loading = true;
    error = null;

    try {
      // Carregar inscripcions
      const { data: inscriptionsData, error: inscriptionsError } = await supabase
        .from('inscripcions')
        .select(`
          id,
          soci_numero,
          categoria_assignada_id,
          data_inscripcio,
          pagat,
          confirmat
        `)
        .eq('event_id', eventId)
        .order('data_inscripcio', { ascending: true });

      console.log('🔍 Inscriptions loaded:', inscriptionsData?.length || 0);

      if (inscriptionsError) throw inscriptionsError;

      if (!inscriptionsData || inscriptionsData.length === 0) {
        console.log('🔍 No inscriptions found');
        inscriptions = [];
        return;
      }

      // Obtenir dades dels socis
      const sociNumbers = [...new Set(inscriptionsData.map(i => i.soci_numero))];
      const { data: socisData, error: socisError } = await supabase
        .from('socis')
        .select(`
          numero_soci,
          nom,
          cognoms,
          email
        `)
        .in('numero_soci', sociNumbers);

      if (socisError) throw socisError;

      // Combinar dades
      const socisMap = new Map(socisData?.map(soci => [soci.numero_soci, soci]) || []);
      inscriptions = inscriptionsData.map(inscription => ({
        ...inscription,
        socis: socisMap.get(inscription.soci_numero) || null
      }));

      console.log('🔍 Final inscriptions with socis:', inscriptions.length);
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

  // Ordenar categories
  $: sortedCategories = categories.sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));
  $: playersWithoutCategory = getPlayersWithoutCategory();
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
    <!-- Categories compactes amb jugadors -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {#each sortedCategories as category (category.id)}
        {@const playersInCategory = getPlayersInCategory(category.id)}
        {#if playersInCategory.length > 0}
          <div class="bg-white border-2 border-gray-200 rounded-lg p-4 hover:shadow-lg transition-shadow">
            <!-- Capçalera de categoria -->
            <div class="text-center mb-4 pb-3 border-b border-gray-200">
              <h3 class="text-lg font-bold text-gray-900">{category.nom}</h3>
              <p class="text-sm text-blue-600 font-medium">
                {category.distancia_caramboles} caramboles
              </p>
              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mt-2">
                {playersInCategory.length} jugadors
              </span>
            </div>

            <!-- Llista de jugadors compacta -->
            <div class="space-y-2">
              {#each playersInCategory as inscription (inscription.id)}
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
                  <div class="flex items-center">
                    {#if inscription.confirmat && inscription.pagat}
                      <span class="w-2 h-2 bg-green-500 rounded-full" title="Confirmat i pagat"></span>
                    {:else if inscription.confirmat}
                      <span class="w-2 h-2 bg-orange-500 rounded-full" title="Confirmat, pendent pagament"></span>
                    {:else}
                      <span class="w-2 h-2 bg-yellow-500 rounded-full" title="Pendent confirmació"></span>
                    {/if}
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
              <div class="flex items-center justify-between py-1">
                <div class="flex items-center">
                  <div class="w-8 h-8 bg-yellow-500 text-white rounded-full flex items-center justify-center text-sm font-bold mr-3">
                    {inicialNom}
                  </div>
                  <span class="text-sm font-medium text-gray-900">
                    {cognoms}
                  </span>
                </div>
                <div class="flex items-center">
                  {#if inscription.confirmat && inscription.pagat}
                    <span class="w-2 h-2 bg-green-500 rounded-full" title="Confirmat i pagat"></span>
                  {:else if inscription.confirmat}
                    <span class="w-2 h-2 bg-orange-500 rounded-full" title="Confirmat, pendent pagament"></span>
                  {:else}
                    <span class="w-2 h-2 bg-yellow-500 rounded-full" title="Pendent confirmació"></span>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>

    <!-- Llegenda d'estats -->
    <div class="bg-gray-50 border border-gray-200 rounded-lg p-4">
      <h4 class="text-sm font-medium text-gray-900 mb-3">Llegenda d'estats:</h4>
      <div class="flex flex-wrap gap-4 text-sm">
        <div class="flex items-center">
          <span class="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
          <span class="text-gray-600">Confirmat i pagat</span>
        </div>
        <div class="flex items-center">
          <span class="w-2 h-2 bg-orange-500 rounded-full mr-2"></span>
          <span class="text-gray-600">Confirmat, pendent pagament</span>
        </div>
        <div class="flex items-center">
          <span class="w-2 h-2 bg-yellow-500 rounded-full mr-2"></span>
          <span class="text-gray-600">Pendent confirmació</span>
        </div>
      </div>
    </div>
  {/if}
</div>

    <!-- Jugadors sense categoria assignada -->
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
            <div class="flex items-center justify-between py-1">
              <div class="flex items-center">
                <div class="w-8 h-8 bg-yellow-500 text-white rounded-full flex items-center justify-center text-sm font-bold mr-3">
                  {inicialNom}
                </div>
                <span class="text-sm font-medium text-gray-900">
                  {cognoms}
                </span>
              </div>
              <div class="flex items-center">
                {#if inscription.confirmat && inscription.pagat}
                  <span class="w-2 h-2 bg-green-500 rounded-full" title="Confirmat i pagat"></span>
                {:else if inscription.confirmat}
                  <span class="w-2 h-2 bg-orange-500 rounded-full" title="Confirmat, pendent pagament"></span>
                {:else}
                  <span class="w-2 h-2 bg-yellow-500 rounded-full" title="Pendent confirmació"></span>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Llegenda d'estats -->
    <div class="bg-gray-50 border border-gray-200 rounded-lg p-4">
      <h4 class="text-sm font-medium text-gray-900 mb-3">Llegenda d'estats:</h4>
      <div class="flex flex-wrap gap-4 text-sm">
        <div class="flex items-center">
          <span class="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
          <span class="text-gray-600">Confirmat i pagat</span>
        </div>
        <div class="flex items-center">
          <span class="w-2 h-2 bg-orange-500 rounded-full mr-2"></span>
          <span class="text-gray-600">Confirmat, pendent pagament</span>
        </div>
        <div class="flex items-center">
          <span class="w-2 h-2 bg-yellow-500 rounded-full mr-2"></span>
          <span class="text-gray-600">Pendent confirmació</span>
        </div>
      </div>
    {:else}
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha jugadors inscrits</h3>
        <p class="mt-1 text-sm text-gray-500">Els jugadors apareixeran aquí quan es facin les inscripcions.</p>
      </div>
  {/if}
</div>