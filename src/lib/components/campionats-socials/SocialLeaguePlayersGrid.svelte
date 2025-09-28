<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  export let eventId: string = '';
  export let categories: any[] = [];

  let inscriptions: any[] = [];
  let loading = false;
  let error: string | null = null;

  onMount(() => {
    if (eventId) {
      loadInscriptions();
    }
  });

  $: if (eventId) {
    loadInscriptions();
  }

  async function loadInscriptions() {
    loading = true;
    error = null;

    try {
      const { data, error: inscriptionsError } = await supabase
        .from('inscripcions')
        .select(`
          id,
          soci_numero,
          categoria_assignada_id,
          data_inscripcio,
          pagat,
          confirmat,
          socis!inscripcions_soci_numero_fkey(
            numero_soci,
            nom,
            cognoms,
            email,
            data_naixement,
            categoria_3bandes
          )
        `)
        .eq('event_id', eventId)
        .order('data_inscripcio', { ascending: true });

      if (inscriptionsError) throw inscriptionsError;

      inscriptions = data || [];
    } catch (e) {
      console.error('Error loading inscriptions:', e);
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

  function formatPlayerName(inscription: any) {
    if (inscription.socis) {
      return `${inscription.socis.nom} ${inscription.socis.cognoms}`;
    }
    return `Soci #${inscription.soci_numero}`;
  }

  function getPlayerEmail(inscription: any) {
    return inscription.socis?.email || '';
  }

  function getPlayerAge(inscription: any) {
    if (!inscription.socis?.data_naixement) return null;

    const birthDate = new Date(inscription.socis.data_naixement);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();

    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }

    return age;
  }

  function getStatusColor(inscription: any) {
    if (!inscription.confirmat) return 'bg-yellow-100 text-yellow-800';
    if (!inscription.pagat) return 'bg-orange-100 text-orange-800';
    return 'bg-green-100 text-green-800';
  }

  function getStatusText(inscription: any) {
    if (!inscription.confirmat) return 'Pendent confirmació';
    if (!inscription.pagat) return 'Pendent pagament';
    return 'Confirmat i pagat';
  }

  // Sort categories by order
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
  {:else}
    <!-- Categories amb jugadors assignats -->
    {#each sortedCategories as category (category.id)}
      {@const playersInCategory = getPlayersInCategory(category.id)}
      {#if playersInCategory.length > 0}
        <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <!-- Category header -->
          <div class="bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-4">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-xl font-bold text-white">{category.nom}</h3>
                <p class="text-blue-100 text-sm">
                  {category.distancia_caramboles} caramboles •
                  Mínim {category.min_jugadors} - Màxim {category.max_jugadors} jugadors
                </p>
              </div>
              <div class="text-right">
                <div class="text-2xl font-bold text-white">
                  {playersInCategory.length}
                </div>
                <div class="text-blue-100 text-sm">jugadors</div>
              </div>
            </div>
          </div>

          <!-- Players grid -->
          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {#each playersInCategory as inscription (inscription.id)}
                {@const playerAge = getPlayerAge(inscription)}
                <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900 text-sm">
                        {formatPlayerName(inscription)}
                      </h4>
                      <p class="text-xs text-gray-500 mt-1">
                        Soci #{inscription.socis?.numero_soci || inscription.soci_numero}
                      </p>
                      {#if playerAge}
                        <p class="text-xs text-gray-500">
                          {playerAge} anys
                        </p>
                      {/if}
                      {#if inscription.socis?.categoria_3bandes}
                        <p class="text-xs text-blue-600 font-medium">
                          Cat. {inscription.socis.categoria_3bandes}
                        </p>
                      {/if}
                    </div>
                    <div class="ml-2">
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {getStatusColor(inscription)}">
                        {#if inscription.confirmat && inscription.pagat}
                          ✓
                        {:else if inscription.confirmat}
                          €
                        {:else}
                          ?
                        {/if}
                      </span>
                    </div>
                  </div>

                  <div class="mt-3 pt-3 border-t border-gray-200">
                    <p class="text-xs text-gray-500" title={getStatusText(inscription)}>
                      Inscrit: {new Date(inscription.data_inscripcio).toLocaleDateString('ca-ES')}
                    </p>
                  </div>
                </div>
              {/each}
            </div>

            <!-- Category status summary -->
            <div class="mt-6 pt-4 border-t border-gray-200">
              <div class="flex items-center justify-between text-sm">
                <div class="flex space-x-6">
                  <span class="text-gray-600">
                    <span class="font-medium text-green-600">
                      {playersInCategory.filter(i => i.confirmat && i.pagat).length}
                    </span> confirmats
                  </span>
                  <span class="text-gray-600">
                    <span class="font-medium text-orange-600">
                      {playersInCategory.filter(i => i.confirmat && !i.pagat).length}
                    </span> pendents pagament
                  </span>
                  <span class="text-gray-600">
                    <span class="font-medium text-yellow-600">
                      {playersInCategory.filter(i => !i.confirmat).length}
                    </span> pendents confirmació
                  </span>
                </div>
                <div class="text-gray-500">
                  {playersInCategory.length}/{category.max_jugadors} places
                </div>
              </div>

              <!-- Progress bar -->
              <div class="mt-2">
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div
                    class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                    style="width: {Math.min((playersInCategory.length / category.max_jugadors) * 100, 100)}%"
                  ></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      {/if}
    {/each}

    <!-- Jugadors sense categoria assignada -->
    {#if playersWithoutCategory.length > 0}
      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <!-- Header -->
        <div class="bg-gradient-to-r from-yellow-500 to-orange-500 px-6 py-4">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-xl font-bold text-white">⚠️ Sense Categoria Assignada</h3>
              <p class="text-yellow-100 text-sm">
                Jugadors pendents d'assignació a una categoria
              </p>
            </div>
            <div class="text-right">
              <div class="text-2xl font-bold text-white">
                {playersWithoutCategory.length}
              </div>
              <div class="text-yellow-100 text-sm">jugadors</div>
            </div>
          </div>
        </div>

        <!-- Players grid -->
        <div class="p-6">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {#each playersWithoutCategory as inscription (inscription.id)}
              {@const playerAge = getPlayerAge(inscription)}
              <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <h4 class="font-medium text-gray-900 text-sm">
                      {formatPlayerName(inscription)}
                    </h4>
                    <p class="text-xs text-gray-500 mt-1">
                      Soci #{inscription.socis?.numero_soci || inscription.soci_numero}
                    </p>
                    {#if playerAge}
                      <p class="text-xs text-gray-500">
                        {playerAge} anys
                      </p>
                    {/if}
                    {#if inscription.socis?.categoria_3bandes}
                      <p class="text-xs text-blue-600 font-medium">
                        Cat. {inscription.socis.categoria_3bandes}
                      </p>
                    {/if}
                  </div>
                  <div class="ml-2">
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {getStatusColor(inscription)}">
                      {#if inscription.confirmat && inscription.pagat}
                        ✓
                      {:else if inscription.confirmat}
                        €
                      {:else}
                        ?
                      {/if}
                    </span>
                  </div>
                </div>

                <div class="mt-3 pt-3 border-t border-yellow-200">
                  <p class="text-xs text-gray-500" title={getStatusText(inscription)}>
                    Inscrit: {new Date(inscription.data_inscripcio).toLocaleDateString('ca-ES')}
                  </p>
                </div>
              </div>
            {/each}
          </div>
        </div>
      </div>
    {/if}

    <!-- Resum general -->
    {#if inscriptions.length > 0}
      <div class="bg-white border border-gray-200 rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
          <span class="mr-2">📊</span>
          Resum General d'Inscripcions
        </h3>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600">{inscriptions.length}</div>
            <div class="text-sm text-gray-500">Total Inscrits</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-green-600">
              {inscriptions.filter(i => i.confirmat && i.pagat).length}
            </div>
            <div class="text-sm text-gray-500">Confirmats i Pagats</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-orange-600">
              {inscriptions.filter(i => i.confirmat && !i.pagat).length}
            </div>
            <div class="text-sm text-gray-500">Pendents Pagament</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-yellow-600">
              {playersWithoutCategory.length}
            </div>
            <div class="text-sm text-gray-500">Sense Categoria</div>
          </div>
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
  {/if}
</div>