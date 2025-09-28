<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  export let event: any = null;
  export let showDetails: boolean = false;

  let classifications: any[] = [];
  let loading = false;
  let error: string | null = null;
  let selectedCategory = 'all';

  onMount(() => {
    if (event?.id) {
      loadClassifications();
    }
  });

  $: if (event?.id) {
    loadClassifications();
  }

  async function loadClassifications() {
    if (!event?.id) return;

    loading = true;
    error = null;

    try {
      // Load classifications for this event
      const { data, error: classificationsError } = await supabase
        .from('classificacions')
        .select(`
          id,
          temporada,
          categoria_id,
          soci_numero,
          posicio,
          partides_jugades,
          partides_guanyades,
          partides_perdudes,
          caramboles_fetes,
          caramboles_rebudes,
          mitjana,
          punts,
          data_actualitzacio,
          categories!classificacions_categoria_id_fkey(
            id,
            nom,
            distancia_caramboles,
            ordre_categoria
          ),
          socis!classificacions_soci_numero_fkey(
            numero_soci,
            nom,
            cognoms,
            email
          )
        `)
        .eq('temporada', event.temporada)
        .order('categoria_id', { ascending: true })
        .order('posicio', { ascending: true });

      if (classificationsError) throw classificationsError;

      // Filter classifications to only show categories from this event
      const eventCategoryIds = event.categories?.map((c: any) => c.id) || [];
      classifications = (data || []).filter(c => eventCategoryIds.includes(c.categoria_id));

    } catch (e) {
      console.error('Error loading classifications:', e);
      error = 'Error carregant les classificacions';
    } finally {
      loading = false;
    }
  }

  function formatPlayerName(classification: any) {
    if (classification.socis) {
      return `${classification.socis.nom} ${classification.socis.cognoms}`;
    }
    return `Soci #${classification.soci_numero}`;
  }

  function getPositionColor(position: number) {
    if (position === 1) return 'bg-yellow-100 text-yellow-800 border-yellow-200';
    if (position === 2) return 'bg-gray-100 text-gray-800 border-gray-200';
    if (position === 3) return 'bg-orange-100 text-orange-800 border-orange-200';
    return 'bg-white text-gray-700 border-gray-200';
  }

  function getPositionIcon(position: number) {
    if (position === 1) return '🥇';
    if (position === 2) return '🥈';
    if (position === 3) return '🥉';
    return position.toString();
  }

  function calculateWinPercentage(won: number, total: number) {
    if (total === 0) return 0;
    return Math.round((won / total) * 100);
  }

  function calculateGoalDifference(made: number, received: number) {
    return made - received;
  }

  // Group classifications by category
  $: classificationsByCategory = classifications.reduce((groups, classification) => {
    const categoryId = classification.categoria_id;
    if (!groups[categoryId]) {
      groups[categoryId] = [];
    }
    groups[categoryId].push(classification);
    return groups;
  }, {} as Record<string, any[]>);

  // Get sorted categories from event
  $: sortedCategories = (event?.categories || []).sort((a: any, b: any) =>
    (a.ordre_categoria || 0) - (b.ordre_categoria || 0)
  );

  // Filter categories based on selected filter
  $: filteredCategories = selectedCategory === 'all'
    ? sortedCategories
    : sortedCategories.filter((c: any) => c.id === selectedCategory);
</script>

<div class="space-y-6">
  <!-- Header and filters -->
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-4">
      <h3 class="text-lg font-medium text-gray-900 flex items-center mb-4 sm:mb-0">
        <span class="mr-2">🏆</span>
        Classificacions
        {#if event}
          <span class="ml-2 text-sm font-normal text-gray-600">
            - Temporada {event.temporada}
          </span>
        {/if}
      </h3>

      <!-- Category filter -->
      <select
        bind:value={selectedCategory}
        class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="all">Totes les categories</option>
        {#each sortedCategories as category}
          <option value={category.id}>{category.nom}</option>
        {/each}
      </select>
    </div>

    {#if event}
      <p class="text-sm text-gray-600">
        Classificacions actualitzades de la temporada {event.temporada} per al campionat: <strong>{event.nom}</strong>
      </p>
    {/if}
  </div>

  {#if loading}
    <div class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <p class="mt-2 text-gray-600">Carregant classificacions...</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-red-800 mb-2">Error</h3>
      <p class="text-red-600">{error}</p>
    </div>
  {:else if filteredCategories.length === 0}
    <div class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No hi ha classificacions disponibles</h3>
      <p class="mt-1 text-sm text-gray-500">Les classificacions apareixeran aquí quan es juguin partides.</p>
    </div>
  {:else}
    <!-- Classifications by category -->
    {#each filteredCategories as category (category.id)}
      {@const categoryClassifications = classificationsByCategory[category.id] || []}

      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <!-- Category header -->
        <div class="bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-4">
          <div class="flex items-center justify-between">
            <div>
              <h4 class="text-xl font-bold text-white">{category.nom}</h4>
              <p class="text-blue-100 text-sm">
                {category.distancia_caramboles} caramboles
              </p>
            </div>
            <div class="text-right">
              <div class="text-2xl font-bold text-white">
                {categoryClassifications.length}
              </div>
              <div class="text-blue-100 text-sm">classificats</div>
            </div>
          </div>
        </div>

        {#if categoryClassifications.length === 0}
          <div class="p-6 text-center">
            <p class="text-gray-500">No hi ha classificacions disponibles per aquesta categoria.</p>
          </div>
        {:else}
          <!-- Classification table -->
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-300">
              <thead class="bg-gray-50">
                <tr>
                  <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                    Pos.
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    Jugador
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    PJ
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    PG
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    PP
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    % Vict.
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    CF
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    CR
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    Diferència
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    Mitjana
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    Punts
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white">
                {#each categoryClassifications as classification (classification.id)}
                  {@const winPercentage = calculateWinPercentage(classification.partides_guanyades, classification.partides_jugades)}
                  {@const goalDifference = calculateGoalDifference(classification.caramboles_fetes, classification.caramboles_rebudes)}

                  <tr class="hover:bg-gray-50 {classification.posicio <= 3 ? 'bg-gradient-to-r from-yellow-50 to-orange-50' : ''}">
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6">
                      <div class="flex items-center justify-center">
                        <span class="flex items-center justify-center w-8 h-8 rounded-full border-2 {getPositionColor(classification.posicio)} font-bold text-sm">
                          {getPositionIcon(classification.posicio)}
                        </span>
                      </div>
                    </td>
                    <td class="px-3 py-4 text-sm">
                      <div>
                        <div class="font-medium text-gray-900">
                          {formatPlayerName(classification)}
                        </div>
                        <div class="text-gray-500 text-xs">
                          Soci #{classification.soci_numero}
                        </div>
                      </div>
                    </td>
                    <td class="px-3 py-4 text-sm text-center font-medium text-gray-900">
                      {classification.partides_jugades}
                    </td>
                    <td class="px-3 py-4 text-sm text-center text-green-600 font-medium">
                      {classification.partides_guanyades}
                    </td>
                    <td class="px-3 py-4 text-sm text-center text-red-600 font-medium">
                      {classification.partides_perdudes}
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="px-2 py-1 rounded-full text-xs font-medium {winPercentage >= 70 ? 'bg-green-100 text-green-800' : winPercentage >= 50 ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'}">
                        {winPercentage}%
                      </span>
                    </td>
                    <td class="px-3 py-4 text-sm text-center text-blue-600 font-medium">
                      {classification.caramboles_fetes}
                    </td>
                    <td class="px-3 py-4 text-sm text-center text-orange-600 font-medium">
                      {classification.caramboles_rebudes}
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="font-medium {goalDifference > 0 ? 'text-green-600' : goalDifference < 0 ? 'text-red-600' : 'text-gray-500'}">
                        {goalDifference > 0 ? '+' : ''}{goalDifference}
                      </span>
                    </td>
                    <td class="px-3 py-4 text-sm text-center font-mono font-medium text-purple-600">
                      {classification.mitjana?.toFixed(2) || '0.00'}
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="font-bold text-lg text-indigo-600">
                        {classification.punts}
                      </span>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>

          {#if showDetails}
            <!-- Category statistics -->
            <div class="bg-gray-50 px-6 py-4 border-t border-gray-200">
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                <div class="text-center">
                  <div class="font-medium text-gray-900">
                    {categoryClassifications.reduce((sum, c) => sum + c.partides_jugades, 0)}
                  </div>
                  <div class="text-gray-500">Total Partides</div>
                </div>
                <div class="text-center">
                  <div class="font-medium text-gray-900">
                    {categoryClassifications.reduce((sum, c) => sum + c.caramboles_fetes, 0)}
                  </div>
                  <div class="text-gray-500">Total Caramboles</div>
                </div>
                <div class="text-center">
                  <div class="font-medium text-gray-900">
                    {categoryClassifications.length > 0 ?
                      (categoryClassifications.reduce((sum, c) => sum + (c.mitjana || 0), 0) / categoryClassifications.length).toFixed(2) :
                      '0.00'}
                  </div>
                  <div class="text-gray-500">Mitjana Categoria</div>
                </div>
                <div class="text-center">
                  <div class="font-medium text-gray-900">
                    {classification?.data_actualitzacio ?
                      new Date(classification.data_actualitzacio).toLocaleDateString('ca-ES') :
                      'No actualitzat'}
                  </div>
                  <div class="text-gray-500">Última Actualització</div>
                </div>
              </div>
            </div>
          {/if}
        {/if}
      </div>
    {/each}

    {#if selectedCategory === 'all' && filteredCategories.length > 1}
      <!-- Overall summary -->
      <div class="bg-white border border-gray-200 rounded-lg p-6">
        <h4 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
          <span class="mr-2">📊</span>
          Resum General de Classificacions
        </h4>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600">
              {classifications.length}
            </div>
            <div class="text-sm text-gray-500">Total Jugadors Classificats</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-green-600">
              {classifications.reduce((sum, c) => sum + c.partides_jugades, 0)}
            </div>
            <div class="text-sm text-gray-500">Total Partides Jugades</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-purple-600">
              {classifications.reduce((sum, c) => sum + c.caramboles_fetes, 0)}
            </div>
            <div class="text-sm text-gray-500">Total Caramboles Fetes</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-indigo-600">
              {filteredCategories.length}
            </div>
            <div class="text-sm text-gray-500">Categories Actives</div>
          </div>
        </div>
      </div>
    {/if}
  {/if}
</div>