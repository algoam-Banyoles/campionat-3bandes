<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  export let event: any = null;
  export let showDetails: boolean = false;

  let classifications: any[] = [];
  let loadedCategories: any[] = [];
  let loading = false;
  let error: string | null = null;
  let selectedCategory = 'all';
  let lastMatchDate: Date | null = null;
  let expandedCategories: Set<string> = new Set();

  onMount(() => {
    if (event?.id) {
      loadCategories();
      loadClassifications();
    }
  });

  // Expand all categories by default when classifications first load
  let hasInitialized = false;
  $: if (classifications.length > 0 && !hasInitialized) {
    expandedCategories = new Set(
      Array.from(new Set(classifications.map(c => c.categoria_id)))
    );
    hasInitialized = true;
  }

  function toggleCategory(categoryId: string) {
    if (expandedCategories.has(categoryId)) {
      expandedCategories.delete(categoryId);
    } else {
      expandedCategories.add(categoryId);
    }
    expandedCategories = expandedCategories; // Trigger reactivity
  }

  $: if (event?.id) {
    loadCategories();
    loadClassifications();
  }

  async function loadCategories() {
    if (!event?.id) return;

    try {
      const { data, error: categoriesError } = await supabase
        .from('categories')
        .select('*')
        .eq('event_id', event.id)
        .order('ordre_categoria', { ascending: true });

      if (categoriesError) throw categoriesError;
      loadedCategories = data || [];
    } catch (e) {
      console.error('Error loading categories:', e);
    }
  }

  async function loadClassifications() {
    if (!event?.id) {
      return;
    }

    loading = true;
    error = null;

    try {
      // Load real-time classifications for social leagues from calendari_partides
      const { data, error: classificationsError } = await supabase
        .rpc('get_social_league_classifications', {
          p_event_id: event.id
        });

      if (classificationsError) throw classificationsError;

      classifications = data || [];

      // Load last match date
      const { data: lastMatch, error: lastMatchError } = await supabase
        .from('calendari_partides')
        .select('data_joc')
        .eq('event_id', event.id)
        .eq('estat', 'validat')
        .not('caramboles_jugador1', 'is', null)
        .not('caramboles_jugador2', 'is', null)
        .order('data_joc', { ascending: false })
        .limit(1)
        .single();

      if (!lastMatchError && lastMatch) {
        lastMatchDate = new Date(lastMatch.data_joc);
      }

    } catch (e) {
      console.error('❌ Error loading classifications:', e);
      error = 'Error carregant les classificacions';
    } finally {
      loading = false;
    }
  }

  function formatPlayerName(classification: any) {
    const nom = classification.soci_nom;
    const cognoms = classification.soci_cognoms;

    if (!nom && !cognoms) return `Soci #${classification.soci_numero}`;

    // Format: inicial(s) del nom + primer cognom
    let inicials = '';
    if (nom) {
      const noms = nom.trim().split(/\s+/);
      inicials = noms.map(n => n.charAt(0).toUpperCase() + '.').join('');
    }

    const primerCognom = cognoms ? cognoms.trim().split(/\s+/)[0] : '';

    if (inicials && primerCognom) {
      return `${inicials} ${primerCognom}`;
    } else if (inicials) {
      return inicials;
    } else if (primerCognom) {
      return primerCognom;
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

  // Extract unique categories from classifications
  $: categoriesFromClassifications = Array.from(
    new Map(
      classifications
        .filter(c => c.categoria_id) // Filter out classifications without categoria_id
        .map(c => [
          c.categoria_id,
          {
            id: c.categoria_id,
            nom: c.categoria_nom,
            ordre_categoria: c.categoria_ordre,
            distancia_caramboles: c.categoria_distancia_caramboles || 0
          }
        ])
    ).values()
  ).sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));

  // Use loaded categories first, then from event prop, then from classifications
  $: sortedCategories = loadedCategories.length > 0
    ? loadedCategories
    : (event?.categories && event.categories.length > 0)
    ? event.categories.sort((a: any, b: any) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0))
    : categoriesFromClassifications;

  $: console.log('📊 SocialLeagueClassifications - Categories:', sortedCategories.length, 'Classifications:', classifications.length, 'Loaded categories:', loadedCategories.length);

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
        <!-- Category header - Clickable to expand/collapse -->
        <button
          on:click={() => toggleCategory(category.id)}
          class="w-full bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-4 hover:from-blue-700 hover:to-indigo-700 transition-colors"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="text-white text-2xl">
                {#if expandedCategories.has(category.id)}
                  ▼
                {:else}
                  ▶
                {/if}
              </div>
              <div class="text-left">
                <h4 class="text-xl font-bold text-white">{category.nom}</h4>
                <p class="text-blue-100 text-sm">
                  {category.distancia_caramboles || 0} caramboles
                </p>
              </div>
            </div>
            <div class="text-right">
              <div class="text-2xl font-bold text-white">
                {categoryClassifications.length}
              </div>
              <div class="text-blue-100 text-sm">classificats</div>
            </div>
          </div>
        </button>

        {#if expandedCategories.has(category.id)}
          {#if categoryClassifications.length === 0}
            <div class="p-6 text-center">
              <p class="text-gray-500">No hi ha classificacions disponibles per aquesta categoria.</p>
            </div>
          {:else}
            <!-- Desktop Table View -->
            <div class="hidden md:block overflow-x-auto">
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
                    Punts
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    Caramboles
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    Entrades
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    Mitjana
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-center text-sm font-semibold text-gray-900">
                    Millor Mitjana
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white">
                {#each categoryClassifications as classification (classification.soci_numero + classification.categoria_id)}
                  <tr class="hover:bg-gray-50 {classification.posicio <= 3 ? 'bg-gradient-to-r from-yellow-50 to-orange-50' : ''}">
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6">
                      <div class="flex items-center justify-center">
                        <span class="flex items-center justify-center w-8 h-8 rounded-full border-2 {getPositionColor(classification.posicio)} font-bold text-sm">
                          {getPositionIcon(classification.posicio)}
                        </span>
                      </div>
                    </td>
                    <td class="px-3 py-4 text-sm">
                      <div class="font-medium text-gray-900">
                        {formatPlayerName(classification)}
                      </div>
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="font-medium text-gray-700">
                        {classification.partides_jugades}
                      </span>
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        {classification.punts}
                      </span>
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="font-medium text-gray-700">
                        {classification.caramboles_totals}
                      </span>
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="font-medium text-gray-700">
                        {classification.entrades_totals}
                      </span>
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="font-medium text-purple-600">
                        {classification.mitjana_general}
                      </span>
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="font-medium text-purple-600">
                        {classification.millor_mitjana}
                      </span>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
            </div>

            <!-- Mobile Card View -->
            <div class="md:hidden space-y-4">
              {#each categoryClassifications as classification (classification.soci_numero + classification.categoria_id)}
                <div class="bg-white border border-gray-200 rounded-xl p-4 shadow-sm {classification.posicio <= 3 ? 'ring-2 ring-yellow-300 bg-gradient-to-r from-yellow-50 to-orange-50' : ''}">
                  <!-- Header -->
                  <div class="flex items-center justify-between mb-4">
                    <div class="flex items-center space-x-3">
                      <span class="flex items-center justify-center w-12 h-12 rounded-full border-2 {getPositionColor(classification.posicio)} font-bold text-lg">
                        {getPositionIcon(classification.posicio)}
                      </span>
                      <div>
                        <div class="font-semibold text-gray-900 text-lg leading-tight">
                          {formatPlayerName(classification)}
                        </div>
                        <div class="text-sm text-gray-500">Posició #{classification.posicio}</div>
                      </div>
                    </div>
                    <div class="text-right">
                      <div class="text-3xl font-bold text-blue-600">{classification.punts}</div>
                      <div class="text-xs text-gray-500 uppercase tracking-wide">punts</div>
                    </div>
                  </div>

                  <!-- Stats Grid -->
                  <div class="grid grid-cols-2 gap-3 mb-4">
                    <div class="bg-gray-50 rounded-lg p-3 text-center min-h-[60px] flex flex-col justify-center">
                      <div class="text-xl font-bold text-gray-900">{classification.partides_jugades}</div>
                      <div class="text-xs text-gray-500 uppercase tracking-wide">Partides</div>
                    </div>
                    <div class="bg-green-50 rounded-lg p-3 text-center min-h-[60px] flex flex-col justify-center">
                      <div class="text-xl font-bold text-green-600">{classification.caramboles_totals}</div>
                      <div class="text-xs text-gray-500 uppercase tracking-wide">Caramboles</div>
                    </div>
                    <div class="bg-purple-50 rounded-lg p-3 text-center min-h-[60px] flex flex-col justify-center">
                      <div class="text-xl font-bold text-purple-600">{classification.entrades_totals}</div>
                      <div class="text-xs text-gray-500 uppercase tracking-wide">Entrades</div>
                    </div>
                    <div class="bg-indigo-50 rounded-lg p-3 text-center min-h-[60px] flex flex-col justify-center">
                      <div class="text-xl font-bold text-indigo-600">{classification.mitjana_general}</div>
                      <div class="text-xs text-gray-500 uppercase tracking-wide">Mitjana</div>
                    </div>
                  </div>

                  <!-- Best Average (highlighted separately) -->
                  <div class="bg-gradient-to-r from-purple-100 to-indigo-100 rounded-lg p-3 text-center">
                    <div class="text-sm text-gray-600 mb-1">Millor Mitjana</div>
                    <div class="text-2xl font-bold text-purple-700">{classification.millor_mitjana}</div>
                  </div>
                </div>
              {/each}
            </div>
                    </td>
                    <td class="px-3 py-4 text-sm text-center">
                      <span class="font-bold text-lg text-indigo-600">
                        {classification.punts}
                      </span>
                    </td>
                    <td class="px-3 py-4 text-sm text-center text-blue-600 font-medium">
                      {classification.caramboles_totals}
                    </td>
                    <td class="px-3 py-4 text-sm text-center text-gray-900 font-medium">
                      {classification.entrades_totals}
                    </td>
                    <td class="px-3 py-4 text-sm text-center font-mono font-medium text-purple-600">
                      {classification.mitjana_general?.toFixed(3) || '0.000'}
                    </td>
                    <td class="px-3 py-4 text-sm text-center font-mono font-medium text-green-600">
                      {classification.millor_mitjana?.toFixed(3) || '0.000'}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>

          {#if showDetails}
            <!-- Category statistics -->
            {@const totalPartides = categoryClassifications.reduce((sum, c) => sum + c.partides_jugades, 0) / 2}
            {@const totalCaramboles = categoryClassifications.reduce((sum, c) => sum + c.caramboles_totals, 0)}
            {@const totalEntrades = categoryClassifications.reduce((sum, c) => sum + c.entrades_totals, 0)}
            {@const mitjanaCategoria = totalEntrades > 0 ? (totalCaramboles / totalEntrades) : 0}

            <div class="bg-gradient-to-r from-gray-50 to-blue-50 px-6 py-4 border-t border-gray-200">
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                <div class="text-center">
                  <div class="font-bold text-2xl text-blue-700">
                    {Math.floor(totalPartides)}
                  </div>
                  <div class="text-gray-600 font-medium">Total Partides</div>
                </div>
                <div class="text-center">
                  <div class="font-bold text-2xl text-green-700">
                    {totalCaramboles}
                  </div>
                  <div class="text-gray-600 font-medium">Total Caramboles</div>
                </div>
                <div class="text-center">
                  <div class="font-bold text-2xl text-purple-700">
                    {mitjanaCategoria.toFixed(3)}
                  </div>
                  <div class="text-gray-600 font-medium">Mitjana Categoria</div>
                </div>
                <div class="text-center">
                  <div class="font-bold text-lg text-gray-700">
                    {#if lastMatchDate}
                      {lastMatchDate.toLocaleDateString('ca-ES', { day: 'numeric', month: 'short', year: 'numeric' })}
                    {:else}
                      Sense partides
                    {/if}
                  </div>
                  <div class="text-gray-600 font-medium">Última Actualització</div>
                </div>
              </div>
            </div>
          {/if}
          {/if}
        {/if}
      </div>
    {/each}

    {#if selectedCategory === 'all' && filteredCategories.length > 1}
      <!-- Overall summary -->
      {@const totalJugadors = classifications.length}
      {@const totalPartides = classifications.reduce((sum, c) => sum + c.partides_jugades, 0) / 2}
      {@const totalCaramboles = classifications.reduce((sum, c) => sum + c.caramboles_totals, 0)}
      {@const totalEntrades = classifications.reduce((sum, c) => sum + c.entrades_totals, 0)}
      {@const mitjanaGeneral = totalEntrades > 0 ? (totalCaramboles / totalEntrades) : 0}

      <div class="bg-white border border-gray-200 rounded-lg p-6">
        <h4 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
          <span class="mr-2">📊</span>
          Resum General del Campionat
        </h4>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600">
              {totalJugadors}
            </div>
            <div class="text-sm text-gray-500">Total Jugadors Inscrits</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-green-600">
              {Math.floor(totalPartides)}
            </div>
            <div class="text-sm text-gray-500">Total Partides Jugades</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-purple-600">
              {totalCaramboles}
            </div>
            <div class="text-sm text-gray-500">Total Caramboles Fetes</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-indigo-600">
              {mitjanaGeneral.toFixed(3)}
            </div>
            <div class="text-sm text-gray-500">Mitjana General Campionat</div>
          </div>
        </div>
      </div>
    {/if}
  {/if}
</div>