<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  const dispatch = createEventDispatcher();

  export let eventId: string = '';
  export let inscriptions: any[] = [];
  export let socis: any[] = [];
  export let categories: any[] = [];
  export let processing = false;

  // Detectar si ja existeixen categories
  $: existingCategories = categories.length > 0;
  $: operationMode = existingCategories ? 'reassign' : 'create';

  let previousChampions = new Map(); // Map de numero_soci -> {posicio, categoria_nom, modalitat, temporada}
  let loadingChampions = false;

  let proposalMode = 'by_level'; // 'by_level' | 'by_count' | 'custom'
  let numberOfCategories = 3;
  let customCategories = [];
  let showPreview = false;
  let proposedCategories = [];
  let generatingProposal = false;

  function generateCategoryName(distance, order, existingCategories) {
    // Comprovar si ja existeix una categoria amb aquesta distància
    const categoriesWithSameDistance = existingCategories.filter(
      cat => cat.distancia_caramboles === distance
    );

    // Determinar el número de categoria basat en l'ordre
    const categoryNumber = order;
    const baseName = `${categoryNumber}a`;

    // Si no hi ha cap categoria amb aquesta distància, usar nom base
    if (categoriesWithSameDistance.length === 0) {
      return baseName;
    }

    // Si ja existeix una categoria amb aquesta distància, afegir suffix A/B/C...
    const suffix = String.fromCharCode(65 + categoriesWithSameDistance.length); // A=65, B=66, C=67...
    return `${categoryNumber}a ${suffix}`;
  }

  // Configuració inicial de categories (l'usuari podrà modificar les caramboles)
  function getInitialCategories(count) {
    const categories = [];
    for (let i = 0; i < count; i++) {
      const distance = 40; // Valor per defecte que l'usuari podrà canviar
      const categoryName = generateCategoryName(distance, i + 1, categories);

      categories.push({
        nom: categoryName,
        distancia_caramboles: distance,
        ordre_categoria: i + 1,
        max_entrades: 2,
        min_jugadors: 4,
        max_jugadors: 16
      });
    }
    return categories;
  }

  $: inscriptionsWithAverages = inscriptions.map(inscription => {
    const soci = socis.find(s => s.numero_soci === inscription.soci_numero);
    return {
      ...inscription,
      sociInfo: soci || { nom: 'Desconegut', cognoms: '', numero_soci: inscription.soci_numero, historicalAverage: null },
      average: soci?.historicalAverage || 0
    };
  }).sort((a, b) => (b.average || 0) - (a.average || 0));

  // Analitza les mitjanes per fer recomanacions
  $: averageStats = (() => {
    const averages = inscriptionsWithAverages
      .map(i => i.average)
      .filter(avg => avg !== null && avg > 0);

    if (averages.length === 0) return null;

    const sorted = [...averages].sort((a, b) => b - a);
    const min = Math.min(...sorted);
    const max = Math.max(...sorted);
    const median = sorted[Math.floor(sorted.length / 2)];

    return {
      count: sorted.length,
      min: min,
      max: max,
      median: median,
      hasAverages: sorted.length / inscriptionsWithAverages.length
    };
  })();

  // Recomanació automàtica del nombre de categories
  $: recommendedCategories = (() => {
    const totalPlayers = inscriptionsWithAverages.length;
    if (totalPlayers <= 8) return 2;
    if (totalPlayers <= 16) return 3;
    if (totalPlayers <= 24) return 4;
    return Math.min(5, Math.ceil(totalPlayers / 8));
  })();

  async function generateProposal() {
    generatingProposal = true;

    try {
      // Carregar campions abans de generar la proposta
      if (eventId && previousChampions.size === 0) {
        console.log('Loading champions before generating proposal...');
        await loadPreviousChampions();
      }

      if (proposalMode === 'by_level') {
        generateLevelBasedProposal();
      } else if (proposalMode === 'by_count') {
        generateCountBasedProposal();
      } else {
        generateCustomProposal();
      }
      showPreview = true;
    } finally {
      generatingProposal = false;
    }
  }

  function generateLevelBasedProposal() {
    // Usar categories existents o crear-ne de noves
    if (existingCategories) {
      proposedCategories = categories.map(cat => ({
        ...cat,
        players: []
      }));
    } else {
      proposedCategories = getInitialCategories(numberOfCategories).map(cat => ({
        ...cat,
        players: []
      }));
    }

    // Distribuir jugadors de manera equitativa ordenats per mitjana (millors repartits)
    distributePlayersEvenly();
  }

  function generateCountBasedProposal() {
    // Usar categories existents o crear-ne de noves
    if (existingCategories) {
      proposedCategories = categories.map(cat => ({
        ...cat,
        players: []
      }));
    } else {
      proposedCategories = getInitialCategories(numberOfCategories).map(cat => ({
        ...cat,
        players: []
      }));
    }

    // Distribuir jugadors de manera equitativa (sense ordenar per mitjana)
    distributePlayersEvenly(false);
  }

  function distributePlayersEvenly(sortByAverage = true) {
    // Separar jugadors amb mitjana dels sense mitjana
    const playersWithAverage = inscriptionsWithAverages.filter(p => p.average > 0);
    const playersWithoutAverage = inscriptionsWithAverages.filter(p => p.average <= 0);

    // Calcular distribució equitativa amb TOTS els jugadors
    const totalPlayers = inscriptionsWithAverages.length;
    const basePlayersPerCategory = Math.floor(totalPlayers / numberOfCategories);
    const remainingPlayers = totalPlayers % numberOfCategories;

    // Ordenar jugadors amb mitjana si cal
    const playersToDistribute = sortByAverage
      ? [...playersWithAverage] // Ja estan ordenats per mitjana descendant
      : playersWithAverage.slice().sort(() => Math.random() - 0.5); // Aleatori

    // Resetear categories
    proposedCategories.forEach(category => {
      category.players = [];
    });

    // Estratègia: omplir les primeres categories completament, deixar la darrera menys plena
    let playerIndex = 0;

    proposedCategories.forEach((category, catIndex) => {
      // Calcular places objectiu per aquesta categoria
      const targetPlayersForCategory = basePlayersPerCategory + (catIndex < remainingPlayers ? 1 : 0);

      let playersToAssignHere = 0;

      if (catIndex < numberOfCategories - 1) {
        // Categories que no són la darrera: omplir completament amb jugadors amb mitjana
        playersToAssignHere = Math.min(
          playersToDistribute.length - playerIndex,
          targetPlayersForCategory
        );
      } else {
        // Darrera categoria: deixar espai per tots els jugadors sense mitjana
        const spacesForWithoutAverage = playersWithoutAverage.length;
        playersToAssignHere = Math.max(0, Math.min(
          playersToDistribute.length - playerIndex,
          targetPlayersForCategory - spacesForWithoutAverage
        ));
      }

      if (playersToAssignHere > 0) {
        category.players = playersToDistribute.slice(playerIndex, playerIndex + playersToAssignHere);
        playerIndex += playersToAssignHere;
      }

      // Configurar max_jugadors amb el target final
      category.max_jugadors = Math.max(16, targetPlayersForCategory + 2);
    });

    // Els jugadors sense mitjana es queden en el bucket especial
    // La distribució es completa quan l'usuari els assigna manualment
  }

  function generateCustomProposal() {
    // En mode custom, sempre usar customCategories (que poden ser les existents si s'han carregat)
    proposedCategories = customCategories.map(cat => ({
      ...cat,
      players: []
    }));

    // Distribuir jugadors de manera equitativa per categories personalitzades
    const totalPlayers = inscriptionsWithAverages.length;
    const basePlayersPerCategory = Math.floor(totalPlayers / proposedCategories.length);
    const remainingPlayers = totalPlayers % proposedCategories.length;

    let playerIndex = 0;
    proposedCategories.forEach((category, catIndex) => {
      const playersForThisCategory = basePlayersPerCategory + (catIndex < remainingPlayers ? 1 : 0);
      category.players = inscriptionsWithAverages.slice(playerIndex, playerIndex + playersForThisCategory);
      category.max_jugadors = playersForThisCategory + 2;
      playerIndex += playersForThisCategory;
    });
  }

  async function createCategoriesAndAssignments() {
    try {
      processing = true;

      console.log('Creating categories for event:', eventId);

      // 1. Crear categories a la base de dades
      const categoriesToCreate = proposedCategories.map(cat => ({
        event_id: eventId,
        nom: cat.nom,
        distancia_caramboles: cat.distancia_caramboles,
        ordre_categoria: cat.ordre_categoria,
        max_entrades: cat.max_entrades,
        min_jugadors: cat.min_jugadors,
        max_jugadors: cat.max_jugadors
      }));

      console.log('Categories to create:', categoriesToCreate);

      const { data: createdCategories, error: categoryError } = await supabase
        .from('categories')
        .insert(categoriesToCreate)
        .select();

      console.log('Supabase response:', { data: createdCategories, error: categoryError });

      if (categoryError) {
        console.error('Category creation error details:', categoryError);
        throw new Error(`Error creant categories: ${categoryError.message}. Comprova que tens permisos d'administrador.`);
      }

      if (!createdCategories || createdCategories.length === 0) {
        throw new Error('No s\'han pogut crear les categories. Resposta buida de la base de dades.');
      }

      // 2. Assignar jugadors a les categories creades
      const assignments = [];
      proposedCategories.forEach((proposedCat, index) => {
        const createdCategory = createdCategories[index];
        if (createdCategory) {
          proposedCat.players.forEach(player => {
            assignments.push({
              inscriptionId: player.id,
              categoryId: createdCategory.id
            });
          });
        }
      });

      console.log('Player assignments to make:', assignments.length);

      // Aplicar assignacions
      if (assignments.length > 0) {
        const updatePromises = assignments.map(({ inscriptionId, categoryId }) =>
          supabase
            .from('inscripcions')
            .update({ categoria_assignada_id: categoryId })
            .eq('id', inscriptionId)
        );

        const results = await Promise.all(updatePromises);
        const errors = results.filter(result => result.error);
        if (errors.length > 0) {
          console.error('Assignment errors:', errors);
          throw new Error(`Errors en ${errors.length} assignacions de jugadors.`);
        }
      }

      console.log('Categories and assignments created successfully');

      // Notificar al component pare que s'han creat categories
      dispatch('categoriesCreated');

      // Resetear estado
      showPreview = false;
      proposedCategories = [];

    } catch (error) {
      console.error('Error creating categories:', error);
      const errorMessage = error.message || 'Error desconegut creant categories';
      dispatch('error', { message: errorMessage });
    } finally {
      processing = false;
    }
  }

  async function reassignPlayersToCategories() {
    try {
      processing = true;

      console.log('Reassigning players to existing categories');

      // Crear assignacions basades en les categories existents
      const assignments = [];
      proposedCategories.forEach(proposedCat => {
        // Trobar la categoria existent corresponent
        const existingCategory = categories.find(cat => cat.nom === proposedCat.nom);
        if (existingCategory) {
          proposedCat.players.forEach(player => {
            assignments.push({
              inscriptionId: player.id,
              categoryId: existingCategory.id
            });
          });
        }
      });

      console.log('Player reassignments to make:', assignments.length);

      // Primer, netejar totes les assignacions existents d'aquest event
      const allInscriptionIds = inscriptions.map(i => i.id);
      if (allInscriptionIds.length > 0) {
        const { error: clearError } = await supabase
          .from('inscripcions')
          .update({ categoria_assignada_id: null })
          .in('id', allInscriptionIds);

        if (clearError) {
          console.error('Error clearing assignments:', clearError);
          throw new Error(`Error netejant assignacions existents: ${clearError.message}`);
        }
      }

      // Aplicar les noves assignacions
      if (assignments.length > 0) {
        const updatePromises = assignments.map(({ inscriptionId, categoryId }) =>
          supabase
            .from('inscripcions')
            .update({ categoria_assignada_id: categoryId })
            .eq('id', inscriptionId)
        );

        const results = await Promise.all(updatePromises);
        const errors = results.filter(result => result.error);
        if (errors.length > 0) {
          console.error('Reassignment errors:', errors);
          throw new Error(`Errors en ${errors.length} reasignacions de jugadors.`);
        }
      }

      console.log('Player reassignments completed successfully');

      // Notificar al component pare
      dispatch('categoriesCreated');

      // Resetear estado
      showPreview = false;
      proposedCategories = [];

    } catch (error) {
      console.error('Error reassigning players:', error);
      const errorMessage = error.message || 'Error desconegut reasignant jugadors';
      dispatch('error', { message: errorMessage });
    } finally {
      processing = false;
    }
  }

  function addCustomCategory() {
    const newOrder = customCategories.length + 1;
    const distance = 40;
    const categoryName = generateCategoryName(distance, newOrder, customCategories);

    customCategories = [...customCategories, {
      nom: categoryName,
      distancia_caramboles: distance,
      ordre_categoria: newOrder,
      max_entrades: 2,
      min_jugadors: 4,
      max_jugadors: 16
    }];
  }

  function removeCustomCategory(index) {
    customCategories = customCategories.filter((_, i) => i !== index);
    // Reorder remaining categories and regenerate names
    customCategories = customCategories.map((cat, i) => {
      const newOrder = i + 1;
      const newName = generateCategoryName(cat.distancia_caramboles, newOrder, customCategories.slice(0, i));

      return {
        ...cat,
        nom: newName,
        ordre_categoria: newOrder
      };
    });
  }

  // Inicialitzar número recomanat
  $: if (recommendedCategories && !numberOfCategories) {
    numberOfCategories = recommendedCategories;
  }

  // Quan hi ha categories existents, usar-les en lloc de crear-ne de noves
  $: if (existingCategories && proposalMode !== 'custom') {
    numberOfCategories = categories.length;
    customCategories = categories.map(cat => ({
      nom: cat.nom,
      distancia_caramboles: cat.distancia_caramboles,
      ordre_categoria: cat.ordre_categoria,
      max_entrades: cat.max_entrades,
      min_jugadors: cat.min_jugadors,
      max_jugadors: cat.max_jugadors
    }));
  }

  function movePlayerBetweenCategories(playerId, fromCategoryIndex, toCategoryIndex) {
    if (fromCategoryIndex === toCategoryIndex) return;

    // Trobar el jugador a la categoria origen (pot estar en unassigned)
    let player;
    if (fromCategoryIndex === -1) {
      // Jugador des del bucket sense categoria
      player = unassignedPlayers.find(p => p.id === playerId);
      if (player) {
        // Eliminar del bucket sense categoria (es maneja automàticament via reactivity)
      }
    } else {
      player = proposedCategories[fromCategoryIndex].players.find(p => p.id === playerId);
      if (player) {
        // Eliminar de la categoria origen
        proposedCategories[fromCategoryIndex].players = proposedCategories[fromCategoryIndex].players.filter(p => p.id !== playerId);
      }
    }

    if (!player) return;

    if (toCategoryIndex === -1) {
      // Moure al bucket sense categoria - no fem res, es maneja automàticament
      proposedCategories = [...proposedCategories]; // Force reactivity
      return;
    }

    // Afegir a la categoria destí
    proposedCategories[toCategoryIndex].players = [...proposedCategories[toCategoryIndex].players, player];

    // Reequilibrar automàticament totes les categories
    rebalanceCategories();

    // Force reactivity per actualitzar tots els buckets
    proposedCategories = [...proposedCategories];
  }

  function rebalanceCategories() {
    // Calcular distribució objectiu amb TOTS els jugadors (assignats + sense assignar)
    const totalPlayers = inscriptionsWithAverages.length;
    const basePlayersPerCategory = Math.floor(totalPlayers / numberOfCategories);
    const remainingPlayers = totalPlayers % numberOfCategories;

    // Crear array amb els jugadors objectiu per cada categoria
    const targetSizes = proposedCategories.map((_, index) =>
      basePlayersPerCategory + (index < remainingPlayers ? 1 : 0)
    );

    // Reequilibri categòria per categòria, empenyent jugadors cap avall seqüencialment
    for (let catIndex = 0; catIndex < proposedCategories.length - 1; catIndex++) {
      const category = proposedCategories[catIndex];
      const targetSize = targetSizes[catIndex];
      const currentSize = category.players.length;

      if (currentSize > targetSize) {
        // Categoria té massa jugadors - moure l'excés directament a la següent categoria
        const excessPlayers = currentSize - targetSize;

        // Agafar els jugadors amb pitjor mitjana per moure'ls (sense mitjana primer, després pitjors mitjanes)
        const sortedPlayers = sortPlayersByAverage(category.players).reverse(); // Invertim per tenir els pitjors primer
        const playersToMove = sortedPlayers.slice(0, excessPlayers);

        // Moure'ls a la categoria immediatament inferior
        playersToMove.forEach(player => {
          category.players = category.players.filter(p => p.id !== player.id);
          proposedCategories[catIndex + 1].players = [...proposedCategories[catIndex + 1].players, player];
        });
      }
    }
  }

  // Calcular jugadors sense categoria assignada
  $: unassignedPlayers = (() => {
    const assignedPlayerIds = new Set();
    proposedCategories.forEach(cat => {
      cat.players.forEach(player => assignedPlayerIds.add(player.id));
    });
    return inscriptionsWithAverages.filter(player => !assignedPlayerIds.has(player.id));
  })();

  // Funció per trobar l'índex de categoria d'un jugador
  function findPlayerCategoryIndex(playerId) {
    for (let i = 0; i < proposedCategories.length; i++) {
      if (proposedCategories[i].players.some(p => p.id === playerId)) {
        return i;
      }
    }
    return -1; // No trobat
  }

  async function loadPreviousChampions() {
    if (loadingChampions) return;

    try {
      loadingChampions = true;

      // Obtenir l'event actual per saber la modalitat i temporada
      const { data: currentEvent } = await supabase
        .from('events')
        .select('modalitat, temporada')
        .eq('id', eventId)
        .single();

      if (!currentEvent) return;

      // Calcular temporada anterior
      const currentYear = parseInt(currentEvent.temporada);
      const previousYear = currentYear - 1;
      const previousSeason = previousYear.toString();

      // Buscar campions i subcampions (posicions 1 i 2) de la mateixa modalitat i temporada anterior
      console.log('Looking for champions:', {
        modalitat: currentEvent.modalitat,
        previousSeason: previousSeason,
        posicions: [1, 2]
      });

      // Temporalment deshabilitat fins a configurar correctament la relació
      console.log('Champions loading disabled temporarily');
      return;

      // Filtrar i processar els resultats
      previousChampions.clear();

      const filteredChampions = champions?.filter(champion => {
        return champion.categories?.events?.modalitat === currentEvent.modalitat &&
               champion.categories?.events?.temporada === previousSeason;
      }) || [];

      console.log('Filtered champions:', filteredChampions);

      filteredChampions.forEach(champion => {
        if (champion.socis && champion.categories?.events) {
          const numeroSoci = champion.socis.numero_soci;
          const championInfo = {
            posicio: champion.posicio,
            categoria_nom: champion.categories.nom,
            modalitat: champion.categories.events.modalitat,
            temporada: champion.categories.events.temporada,
            nom: champion.socis.nom,
            cognoms: champion.socis.cognoms
          };

          previousChampions.set(numeroSoci, championInfo);
          console.log('Added champion:', championInfo);
        }
      });

      console.log(`Loaded ${previousChampions.size} previous champions/runners-up for ${currentEvent.modalitat} from season ${previousSeason}`);

    } catch (error) {
      console.error('Error loading previous champions:', error);
    } finally {
      loadingChampions = false;
    }
  }

  function getPlayerChampionStatus(numeroSoci) {
    return previousChampions.get(numeroSoci) || null;
  }

  function sortPlayersByAverage(players) {
    return [...players].sort((a, b) => {
      // Primer: jugadors sense mitjana (average === 0)
      if (a.average === 0 && b.average > 0) return -1;
      if (b.average === 0 && a.average > 0) return 1;

      // Si tots dos tenen mitjana o tots dos no tenen, ordenar per mitjana descendent
      return (b.average || 0) - (a.average || 0);
    });
  }

  // Carregar campions quan s'inicialitza o canvia l'event
  $: if (eventId) {
    console.log('EventId changed, loading champions for event:', eventId);
    loadPreviousChampions();
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
      <span class="mr-2">{existingCategories ? '⚙️' : '🚀'}</span>
      {existingCategories ? 'Reasignació de Categories' : 'Configuració Inicial de Categories'}
    </h3>

    {#if existingCategories}
      <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-6">
        <h4 class="font-medium text-orange-900 mb-2">Categories Existents Detectades</h4>
        <p class="text-sm text-orange-800 mb-3">
          Aquest event ja té {categories.length} categories creades. Pots reasignar els jugadors a aquestes categories existents.
        </p>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          {#each categories as category}
            <div class="bg-orange-100 border border-orange-300 rounded p-2 text-sm">
              <div class="font-medium text-orange-900">{category.nom}</div>
              <div class="text-orange-700">{category.distancia_caramboles} caramboles</div>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
      <h4 class="font-medium text-blue-900 mb-2">Anàlisi de les Inscripcions</h4>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
        <div>
          <span class="font-medium text-blue-800">Total jugadors:</span>
          <span class="text-blue-700">{inscriptionsWithAverages.length}</span>
        </div>
        <div>
          <span class="font-medium text-blue-800">Categories recomanades:</span>
          <span class="text-blue-700">{recommendedCategories}</span>
        </div>
        {#if averageStats}
          <div>
            <span class="font-medium text-blue-800">Amb mitjana:</span>
            <span class="text-blue-700">{averageStats.count} ({(averageStats.hasAverages * 100).toFixed(0)}%)</span>
          </div>
          <div>
            <span class="font-medium text-blue-800">Rang mitjanes:</span>
            <span class="text-blue-700">{averageStats.min.toFixed(2)} - {averageStats.max.toFixed(2)}</span>
          </div>
        {:else}
          <div class="col-span-2">
            <span class="font-medium text-orange-800">⚠️ Sense mitjanes històriques disponibles</span>
          </div>
        {/if}
      </div>

      <!-- Previous Champions Section -->
      {#if previousChampions.size > 0}
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mt-4">
          <h4 class="font-medium text-yellow-900 mb-2 flex items-center">
            <span class="mr-2">🏆</span> Campions i Subcampions de la Temporada Anterior
          </h4>
          <div class="text-sm space-y-1">
            {#each Array.from(previousChampions.values()) as champion}
              <div class="flex items-center space-x-2">
                <span class="font-medium text-yellow-800">{champion.nom} {champion.cognoms}</span>
                <span class="text-xs bg-yellow-200 px-2 py-1 rounded">
                  {champion.posicio === 1 ? '🏆 Campió' : '🥈 Subcampió'} - {champion.categoria_nom}
                </span>
              </div>
            {/each}
          </div>
          <div class="text-xs text-yellow-700 mt-2">
            Aquests jugadors es ressalten automàticament a la vista prèvia
          </div>
        </div>
      {/if}
    </div>

    <!-- Mode Selection -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Mode de creació
        </label>
        <select
          bind:value={proposalMode}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="by_level">Distribució equitativa ordenada per mitjana</option>
          <option value="by_count">Distribució equitativa aleatòria</option>
          {#if !existingCategories}
            <option value="custom">Categories personalitzades</option>
          {/if}
        </select>
        {#if existingCategories}
          <p class="mt-1 text-xs text-gray-500">Les categories personalitzades ja existeixen. Només es poden reasignar jugadors.</p>
        {/if}
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Nombre de categories
        </label>
        <input
          type="number"
          min="2"
          max="6"
          bind:value={numberOfCategories}
          disabled={existingCategories}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
        />
        {#if existingCategories}
          <p class="mt-1 text-xs text-gray-500">Definit per les categories existents ({categories.length})</p>
        {/if}
      </div>
    </div>

    <!-- Custom Categories Editor -->
    {#if proposalMode === 'custom'}
      <div class="mt-6">
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-md font-medium text-gray-800">Categories personalitzades</h4>
          <button
            on:click={addCustomCategory}
            class="px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700"
          >
            Afegir Categoria
          </button>
        </div>

        <div class="space-y-3">
          {#each customCategories as category, index}
            <div class="flex items-center space-x-4 bg-gray-50 p-3 rounded-lg">
              <div class="flex-1 grid grid-cols-1 md:grid-cols-4 gap-3">
                <input
                  type="text"
                  bind:value={category.nom}
                  placeholder="Nom categoria"
                  class="px-2 py-1 border border-gray-300 rounded text-sm"
                />
                <input
                  type="number"
                  bind:value={category.distancia_caramboles}
                  placeholder="Caramboles"
                  class="px-2 py-1 border border-gray-300 rounded text-sm"
                />
                <input
                  type="number"
                  bind:value={category.max_jugadors}
                  placeholder="Max jugadors"
                  class="px-2 py-1 border border-gray-300 rounded text-sm"
                />
                <button
                  on:click={() => removeCustomCategory(index)}
                  class="px-2 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700"
                >
                  Eliminar
                </button>
              </div>
            </div>
          {/each}

          {#if customCategories.length === 0}
            <div class="text-center py-4 text-gray-500 text-sm">
              Clica "Afegir Categoria" per començar
            </div>
          {/if}
        </div>
      </div>
    {/if}

    <!-- Action Buttons -->
    <div class="flex items-center space-x-3 mt-6">
      <button
        on:click={generateProposal}
        disabled={generatingProposal || inscriptionsWithAverages.length === 0 || (proposalMode === 'custom' && customCategories.length === 0)}
        class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
      >
        {generatingProposal ? 'Generant...' : 'Generar Proposta'}
      </button>
    </div>
  </div>

  <!-- Preview -->
  {#if showPreview && proposedCategories.length > 0}
    <div class="bg-white border border-gray-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
        <span class="mr-2">👀</span> Vista Prèvia de Categories i Assignacions
      </h3>

      <!-- Jugadors sense categoria assignada -->
      {#if unassignedPlayers.length > 0}
        <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-6">
          <h4 class="font-medium text-orange-900 mb-3 flex items-center">
            <span class="mr-2">📋</span> Jugadors Pendents d'Assignar ({unassignedPlayers.length})
          </h4>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {#each sortPlayersByAverage(unassignedPlayers) as player}
              {@const championStatus = getPlayerChampionStatus(player.sociInfo.numero_soci)}
              <div class="bg-white border border-orange-200 rounded p-3"
                   class:bg-yellow-50={championStatus?.posicio === 1}
                   class:bg-gray-50={championStatus?.posicio === 2}>
                <div class="flex items-center justify-between">
                  <div class="text-sm flex-1">
                    <div class="flex items-center space-x-2">
                      <div class="font-medium text-gray-900">
                        {player.sociInfo.nom} {player.sociInfo.cognoms}
                      </div>
                      {#if championStatus}
                        {#if championStatus.posicio === 1}
                          <span class="text-xs bg-yellow-500 text-white px-1 py-0.5 rounded-full font-bold">🏆</span>
                        {:else if championStatus.posicio === 2}
                          <span class="text-xs bg-gray-500 text-white px-1 py-0.5 rounded-full font-bold">🥈</span>
                        {/if}
                      {/if}
                    </div>
                    <div class="text-gray-500">
                      #{player.sociInfo.numero_soci}
                      {#if championStatus}
                        <span class="text-xs text-blue-600">
                          • {championStatus.categoria_nom} ({championStatus.temporada})
                        </span>
                      {/if}
                    </div>
                  </div>
                  <div class="text-right">
                    <select
                      value={-1}
                      on:change={(e) => movePlayerBetweenCategories(player.id, -1, parseInt(e.target.value))}
                      class="text-xs border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value={-1}>Sense assignar</option>
                      {#each proposedCategories as targetCategory, targetIndex}
                        <option value={targetIndex}>
                          {targetCategory.nom}
                        </option>
                      {/each}
                    </select>
                    {#if player.average > 0}
                      <div class="text-xs text-blue-600 mt-1">{player.average.toFixed(2)}</div>
                    {:else}
                      <div class="text-xs text-gray-400 mt-1">S/M</div>
                    {/if}
                  </div>
                </div>
              </div>
            {/each}
          </div>
          <div class="text-xs text-orange-700 mt-3">
            Assigna aquests jugadors a les categories utilitzant els desplegables
          </div>
        </div>
      {/if}

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-6">
        {#each proposedCategories as category, index}
          <div class="border border-gray-200 rounded-lg">
            <div class="bg-blue-50 px-4 py-3 border-b border-gray-200 rounded-t-lg">
              <h4 class="font-medium text-gray-900">{category.nom}</h4>
              <div class="flex items-center space-x-3 mt-2">
                <div class="flex items-center space-x-2">
                  <label class="text-sm text-gray-600">Caramboles:</label>
                  <input
                    type="number"
                    step="5"
                    bind:value={category.distancia_caramboles}
                    class="w-16 px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
                <div class="text-sm text-gray-600">
                  • {category.players.length} jugadors
                </div>
              </div>
            </div>
            <div class="p-3 max-h-64 overflow-y-auto">
              {#each sortPlayersByAverage(category.players) as player, playerIndex}
                {@const championStatus = getPlayerChampionStatus(player.sociInfo.numero_soci)}
                <div class="flex items-center justify-between py-2 border-b border-gray-100 last:border-0"
                     class:bg-yellow-50={championStatus?.posicio === 1}
                     class:bg-gray-50={championStatus?.posicio === 2}>
                  <div class="text-sm flex-1">
                    <div class="flex items-center space-x-2">
                      <div class="font-medium text-gray-900">
                        {player.sociInfo.nom} {player.sociInfo.cognoms}
                      </div>
                      {#if championStatus}
                        {#if championStatus.posicio === 1}
                          <span class="text-xs bg-yellow-500 text-white px-2 py-1 rounded-full font-bold">🏆 CAMPIÓ</span>
                        {:else if championStatus.posicio === 2}
                          <span class="text-xs bg-gray-500 text-white px-2 py-1 rounded-full font-bold">🥈 SUBCAMPIÓ</span>
                        {/if}
                      {/if}
                    </div>
                    <div class="text-gray-500">
                      #{player.sociInfo.numero_soci}
                      {#if championStatus}
                        <span class="text-xs text-blue-600">
                          • {championStatus.categoria_nom} ({championStatus.temporada})
                        </span>
                      {/if}
                    </div>
                  </div>
                  <div class="flex items-center space-x-2">
                    <div class="text-right text-xs">
                      {#if player.average > 0}
                        <span class="text-blue-600 font-medium">{player.average.toFixed(2)}</span>
                      {:else}
                        <span class="text-gray-400">S/M</span>
                      {/if}
                    </div>
                    <!-- Move player buttons -->
                    <div class="flex flex-col space-y-1">
                      <select
                        value={findPlayerCategoryIndex(player.id)}
                        on:change={(e) => movePlayerBetweenCategories(player.id, findPlayerCategoryIndex(player.id), parseInt(e.target.value))}
                        class="text-xs border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
                      >
                        {#each proposedCategories as targetCategory, targetIndex}
                          <option value={targetIndex}>
                            {targetCategory.nom}
                          </option>
                        {/each}
                      </select>
                    </div>
                  </div>
                </div>
              {/each}

              {#if category.players.length === 0}
                <div class="text-center text-gray-400 py-4 text-sm">
                  Sense jugadors assignats
                </div>
              {/if}
            </div>
          </div>
        {/each}
      </div>

      <div class="flex items-center space-x-3">
        <button
          on:click={existingCategories ? reassignPlayersToCategories : createCategoriesAndAssignments}
          disabled={processing}
          class="px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 disabled:bg-gray-400"
        >
          {#if processing}
            {existingCategories ? 'Reasignant Jugadors...' : 'Creant Categories...'}
          {:else}
            {existingCategories ? 'Aplicar Reasignacions' : 'Crear Categories i Aplicar Assignacions'}
          {/if}
        </button>
        <button
          on:click={() => { showPreview = false; proposedCategories = []; }}
          class="px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700"
        >
          Cancel·lar
        </button>
      </div>

      <div class="mt-4 text-sm text-gray-600">
        <strong>Resum:</strong>
        {#if existingCategories}
          Es reasignaran {inscriptionsWithAverages.length} jugadors a les {proposedCategories.length} categories existents.
        {:else}
          Es crearan {proposedCategories.length} categories amb assignació automàtica de {inscriptionsWithAverages.length} jugadors.
        {/if}
      </div>
    </div>
  {/if}
</div>