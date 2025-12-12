<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { supabase } from '$lib/supabaseClient';

  const dispatch = createEventDispatcher();

  export let inscriptions: any[] = [];
  export let categories: any[] = [];
  export let socis: any[] = [];
  export let processing = false;
  export let events: any[] = [];
  export let selectedEventId: string = '';

  let assignmentStrategy = 'by_average'; // 'by_average' | 'balanced' | 'random'
  let proposedAssignments = [];
  let showPreview = false;

  // Configuració dels rangs de mitjana per categoria
  let averageRanges = {};

  // Modal per jugadors sense mitjana
  let showNoAverageModal = false;
  let playersWithoutAverage = [];
  let estimatedAverages = {};

  // Ascensos automàtics
  let showPromotionsModal = false;
  let proposedPromotions = [];
  let confirmedPromotions = {};

  // Assignacions manuals (per no reequilibrar-les)
  let manualAssignments = new Set();

  $: unassignedInscriptions = inscriptions.filter(i => !i.categoria_assignada_id);
  $: sortedCategories = categories.sort((a, b) => a.ordre_categoria - b.ordre_categoria);

  // Inicialitzar rangs automàticament quan canvien les categories
  $: if (categories.length > 0 && Object.keys(averageRanges).length === 0) {
    initializeAverageRanges();
  }

  function initializeAverageRanges() {
    // Calcular rangs automàtics basats en les distàncies de caramboles
    const sortedCats = categories.sort((a, b) => b.distancia_caramboles - a.distancia_caramboles);

    averageRanges = {};
    sortedCats.forEach((cat, index) => {
      const totalCats = sortedCats.length;

      if (totalCats === 1) {
        averageRanges[cat.id] = { min: 0, max: 99 };
      } else if (index === 0) {
        // Categoria més alta (més caramboles)
        averageRanges[cat.id] = { min: 2.0, max: 99 };
      } else if (index === totalCats - 1) {
        // Categoria més baixa
        averageRanges[cat.id] = { min: 0, max: 1.2 };
      } else {
        // Categories intermèdies
        const minRange = 2.0 - (index * 0.4);
        const maxRange = 2.0 - ((index - 1) * 0.4);
        averageRanges[cat.id] = {
          min: Math.max(0, minRange - 0.4),
          max: Math.min(99, maxRange)
        };
      }
    });
  }

  function getSociInfo(inscription) {
    return socis.find(s => s.numero_soci === inscription.soci_numero) || {
      nom: 'Desconegut',
      cognoms: '',
      numero_soci: inscription.soci_numero,
      historicalAverage: null
    };
  }

  function calculateAssignments() {
    if (assignmentStrategy === 'by_average') {
      return calculateByAverage();
    } else if (assignmentStrategy === 'balanced') {
      return calculateBalanced();
    } else {
      return calculateRandom();
    }
  }

  function calculateByAverage() {
    const assignments = [];

    unassignedInscriptions.forEach(inscription => {
      const sociInfo = getSociInfo(inscription);
      const average = sociInfo.historicalAverage;

      let assignedCategory = null;

      if (average !== null) {
        // Trobar la categoria que millor s'ajusti a la mitjana
        for (const category of sortedCategories) {
          const range = averageRanges[category.id];
          if (average >= range.min && average <= range.max) {
            assignedCategory = category;
            break;
          }
        }
      }

      // Si no trobem categoria per mitjana, assignar a la més baixa
      if (!assignedCategory && sortedCategories.length > 0) {
        assignedCategory = sortedCategories[sortedCategories.length - 1];
      }

      assignments.push({
        inscription,
        sociInfo,
        currentCategory: null,
        proposedCategory: assignedCategory,
        reason: average !== null
          ? `Mitjana ${average.toFixed(2)} s'ajusta al rang ${averageRanges[assignedCategory?.id]?.min.toFixed(2)}-${averageRanges[assignedCategory?.id]?.max.toFixed(2)}`
          : 'Sense mitjana històrica - assignat a categoria més baixa'
      });
    });

    return assignments;
  }

  function calculateBalanced() {
    const assignments = [];

    // Ordenar categories per ordre (millor a pitjor)
    const orderedCategories = [...categories].sort((a, b) => a.ordre_categoria - b.ordre_categoria);

    // Ordenar inscripcions per mitjana (de més alta a més baixa)
    const sortedInscriptions = [...unassignedInscriptions].sort((a, b) => {
      const sociInfoA = getSociInfo(a);
      const sociInfoB = getSociInfo(b);

      const avgA = sociInfoA.historicalAverage || sociInfoA.oldestAverage || 0;
      const avgB = sociInfoB.historicalAverage || sociInfoB.oldestAverage || 0;

      return avgB - avgA;
    });

    // Calcular jugadors per categoria
    const totalPlayers = sortedInscriptions.length;
    const numCategories = orderedCategories.length;
    const playersPerCategory = Math.floor(totalPlayers / numCategories);
    const remainingPlayers = totalPlayers % numCategories;

    let playerIndex = 0;

    // Distribuir jugadors seqüencialment per categories
    orderedCategories.forEach((category, catIndex) => {
      // Categories superiors tenen un jugador extra si sobren jugadors
      const playersInThisCategory = playersPerCategory + (catIndex < remainingPlayers ? 1 : 0);

      for (let i = 0; i < playersInThisCategory && playerIndex < totalPlayers; i++) {
        const inscription = sortedInscriptions[playerIndex];
        const sociInfo = getSociInfo(inscription);

        let reason = `Posició ${playerIndex + 1} per mitjana`;
        if (sociInfo.historicalAverage !== null) {
          reason += ` (${sociInfo.historicalAverage.toFixed(2)} - any ${sociInfo.historicalAverageYear})`;
        } else if (sociInfo.oldestAverage !== null) {
          reason += ` (${sociInfo.oldestAverage.toFixed(2)} - any ${sociInfo.oldestAverageYear} - antiga)`;
        } else {
          reason += ` - SENSE MITJANA`;
        }

        assignments.push({
          inscription,
          sociInfo,
          currentCategory: null,
          proposedCategory: category,
          reason
        });

        playerIndex++;
      }
    });

    return assignments;
  }

  function calculateRandom() {
    const assignments = [];

    unassignedInscriptions.forEach(inscription => {
      const sociInfo = getSociInfo(inscription);
      const randomCategory = categories[Math.floor(Math.random() * categories.length)];

      assignments.push({
        inscription,
        sociInfo,
        currentCategory: null,
        proposedCategory: randomCategory,
        reason: 'Assignació aleatòria'
      });
    });

    return assignments;
  }

  function generatePreview() {
    // Netejar assignacions manuals prèvies
    manualAssignments.clear();

    // Detectar jugadors sense mitjana
    playersWithoutAverage = unassignedInscriptions
      .map(inscription => {
        const sociInfo = getSociInfo(inscription);
        return {
          inscription,
          sociInfo,
          hasRecentAverage: sociInfo.historicalAverage !== null,
          hasOldAverage: sociInfo.oldestAverage !== null
        };
      })
      .filter(p => !p.hasRecentAverage && !p.hasOldAverage);

    // Si hi ha jugadors sense cap mitjana, mostrar modal
    if (playersWithoutAverage.length > 0 && (assignmentStrategy === 'by_average' || assignmentStrategy === 'balanced')) {
      showNoAverageModal = true;
      // Inicialitzar mitjanes estimades
      playersWithoutAverage.forEach(p => {
        estimatedAverages[p.inscription.id] = estimatedAverages[p.inscription.id] || '';
      });
    } else {
      // Generar assignacions directament
      proposedAssignments = calculateAssignments();
      showPreview = true;
    }
  }

  function confirmNoAverageModal() {
    // Aplicar mitjanes estimades als socis
    playersWithoutAverage.forEach(p => {
      const estimated = parseFloat(estimatedAverages[p.inscription.id]);
      if (!isNaN(estimated) && estimated > 0) {
        // Actualitzar temporalment la mitjana del soci
        const soci = socis.find(s => s.numero_soci === p.inscription.soci_numero);
        if (soci) {
          soci.historicalAverage = estimated;
          soci.historicalAverageYear = new Date().getFullYear();
        }
      }
    });

    // Generar assignacions
    showNoAverageModal = false;
    proposedAssignments = calculateAssignments();
    showPreview = true;
  }

  async function checkAutomaticPromotions() {
    try {
      // Validar que tenim un event seleccionat
      if (!selectedEventId) {
        console.warn('No hi ha cap event seleccionat');
        showPromotionsModal = true;
        proposedPromotions = [];
        return;
      }

      // Obtenir informació de l'event actual
      const currentEvent = events.find(e => e.id === selectedEventId);
      if (!currentEvent) {
        console.error('Event actual no trobat');
        showPromotionsModal = true;
        proposedPromotions = [];
        return;
      }

      // Validar format de temporada
      if (!currentEvent.temporada || !currentEvent.temporada.includes('-')) {
        console.error('Format de temporada invàlid:', currentEvent.temporada);
        showPromotionsModal = true;
        proposedPromotions = [];
        return;
      }

      // Buscar l'event de la temporada anterior amb la mateixa modalitat
      const currentSeasonYear = parseInt(currentEvent.temporada.split('-')[1]);
      const previousSeasonStart = currentSeasonYear - 2;
      const previousSeasonEnd = currentSeasonYear - 1;
      const previousSeason = `${previousSeasonStart}-${previousSeasonEnd}`;

      console.log(`Buscant event anterior: modalitat=${currentEvent.modalitat}, temporada=${previousSeason}`);

      const { data: previousEvents, error: eventsError } = await supabase
        .from('events')
        .select('id, nom, temporada, modalitat')
        .eq('modalitat', currentEvent.modalitat)
        .eq('temporada', previousSeason)
        .eq('tipus_competicio', 'lliga_social')
        .eq('estat_competicio', 'finalitzat');

      if (eventsError) {
        console.error('Error buscant events anteriors:', eventsError);
        throw eventsError;
      }

      if (!previousEvents || previousEvents.length === 0) {
        console.log('No s\'ha trobat cap event de la temporada anterior');
        showPromotionsModal = true;
        proposedPromotions = [];
        return;
      }

      const previousEvent = previousEvents[0];
      console.log('Event anterior trobat:', previousEvent);

      // Obtenir classificacions finals de l'event anterior
      const { data: classifications, error: classError } = await supabase
        .rpc('get_social_league_classifications', {
          p_event_id: previousEvent.id
        });

      if (classError) {
        console.error('Error obtenint classificacions:', classError);
        throw classError;
      }

      console.log(`Classificacions obtingudes: ${classifications?.length || 0}`);

      // Obtenir categories de l'event anterior
      const { data: previousCategories, error: catError } = await supabase
        .from('categories')
        .select('*')
        .eq('event_id', previousEvent.id)
        .order('ordre_categoria');

      if (catError) throw catError;

      // Processar campions i subcampions per cada categoria (excepte la 1a)
      const promotions = [];
      const sortedPrevCats = (previousCategories || []).sort((a, b) => a.ordre_categoria - b.ordre_categoria);

      if (sortedPrevCats.length === 0) {
        console.log('No s\'han trobat categories de la temporada anterior');
        showPromotionsModal = true;
        proposedPromotions = [];
        return;
      }

      // Ordenar categories actuals per ordre
      const sortedCurrentCats = [...categories].sort((a, b) => a.ordre_categoria - b.ordre_categoria);

      for (let i = 1; i < sortedPrevCats.length; i++) {
        const category = sortedPrevCats[i];
        const categoryClassifications = (classifications || [])
          .filter(c => c.categoria_id === category.id)
          .sort((a, b) => {
            // Ordenar per punts, després per victòries
            if (b.punts !== a.punts) return b.punts - a.punts;
            const aVictories = a.victories || 0;
            const bVictories = b.victories || 0;
            return bVictories - aVictories;
          });

        // Obtenir 1r i 2n de cada categoria
        const topTwo = categoryClassifications.slice(0, 2);

        if (topTwo.length === 0) {
          console.log(`No hi ha classificacions per la categoria ${category.nom}`);
          continue;
        }

        for (let j = 0; j < topTwo.length; j++) {
          const player = topTwo[j];

          // Buscar la categoria superior en les categories actuals
          // Intentem trobar una categoria amb ordre inferior (millor)
          const prevCategoryOrder = category.ordre_categoria;
          const targetCategory = sortedCurrentCats.find(c => c.ordre_categoria === prevCategoryOrder - 1);

          if (!targetCategory) {
            console.log(`No s'ha trobat categoria objectiu per ascens des de ${category.nom}`);
            continue;
          }

          // Obtenir informació del jugador des de players
          const { data: playerData, error: playerError } = await supabase
            .from('players')
            .select('numero_soci, socis(nom, cognoms)')
            .eq('id', player.jugador_id)
            .single();

          if (playerError) {
            console.warn(`Error obtenint dades del jugador ${player.jugador_id}:`, playerError);
            continue;
          }

          if (playerData && playerData.socis) {
            // Convertir socis a objecte si és un array (degut al tipus de Supabase)
            const sociData = Array.isArray(playerData.socis) ? playerData.socis[0] : playerData.socis;

            if (!sociData) {
              console.warn(`No s'han trobat dades del soci per al jugador ${player.jugador_id}`);
              continue;
            }

            // Verificar que el jugador està inscrit a l'event actual
            const isInscribed = inscriptions.some(i => i.soci_numero === playerData.numero_soci);
            if (!isInscribed) {
              console.log(`Jugador ${sociData.nom} ${sociData.cognoms} no està inscrit a l'event actual`);
              continue;
            }

            promotions.push({
              player: {
                nom: sociData.nom,
                cognoms: sociData.cognoms,
                numero_soci: playerData.numero_soci
              },
              currentCategory: category.nom,
              proposedCategory: targetCategory.nom,
              reason: `${j === 0 ? 'Guanyador' : 'Segon classificat'} ${category.nom} temporada ${previousSeason}`,
              position: j + 1,
              stats: {
                punts: player.punts,
                victories: player.victories || 0,
                partides: player.partides || 0
              }
            });
          }
        }
      }

      console.log(`Propostes d'ascens: ${promotions.length}`);
      proposedPromotions = promotions;
      showPromotionsModal = true;

    } catch (e) {
      console.error('Error comprovant ascensos automàtics:', e);
      showPromotionsModal = true;
      proposedPromotions = [];
    }
  }

  async function confirmPromotions() {
    try {
      const promotionsToApply = proposedPromotions.filter(promo =>
        confirmedPromotions[promo.player.numero_soci]
      );

      if (promotionsToApply.length === 0) {
        showPromotionsModal = false;
        return;
      }

      // Preparar assignacions per aplicar
      const assignments = [];

      for (const promo of promotionsToApply) {
        // Trobar la inscripció d'aquest jugador
        const inscription = inscriptions.find(i => i.soci_numero === promo.player.numero_soci);
        if (!inscription) {
          console.warn(`No s'ha trobat inscripció per al jugador ${promo.player.numero_soci}`);
          continue;
        }

        // Trobar la categoria objectiu
        const targetCategory = categories.find(c => c.nom === promo.proposedCategory);
        if (!targetCategory) {
          console.warn(`No s'ha trobat la categoria ${promo.proposedCategory}`);
          continue;
        }

        assignments.push({
          inscriptionId: inscription.id,
          categoryId: targetCategory.id
        });
      }

      // Aplicar assignacions utilitzant el mateix mecanisme que les assignacions automàtiques
      if (assignments.length > 0) {
        dispatch('applyAssignments', { assignments });
      }

      showPromotionsModal = false;
      proposedPromotions = [];
      confirmedPromotions = {};

    } catch (e) {
      console.error('Error aplicant ascensos:', e);
      alert('Error aplicant els ascensos. Si us plau, torna-ho a intentar.');
    }
  }

  function applyAssignments() {
    const assignments = proposedAssignments.map(assignment => ({
      inscriptionId: assignment.inscription.id,
      categoryId: assignment.proposedCategory?.id || null
    }));

    dispatch('applyAssignments', { assignments });
    showPreview = false;
    proposedAssignments = [];
    manualAssignments.clear();
  }

  function updateRange(categoryId, field, value) {
    if (!averageRanges[categoryId]) {
      averageRanges[categoryId] = { min: 0, max: 99 };
    }
    averageRanges[categoryId][field] = parseFloat(value) || 0;
    averageRanges = { ...averageRanges }; // Force reactivity
  }

  function removeAssignment(index) {
    const inscriptionId = proposedAssignments[index].inscription.id;
    manualAssignments.delete(inscriptionId);
    proposedAssignments = proposedAssignments.filter((_, i) => i !== index);
  }

  function changeAssignment(index, newCategoryId) {
    const assignment = proposedAssignments[index];
    const newCategory = categories.find(c => c.id === newCategoryId);

    // Marcar com a assignació manual
    manualAssignments.add(assignment.inscription.id);

    // Canviar la categoria
    assignment.proposedCategory = newCategory;
    assignment.reason = 'Modificació manual';

    // Reequilibrar automàticament els jugadors NO manuals
    rebalanceAssignments();
  }

  function rebalanceAssignments() {
    // Separar assignacions manuals i automàtiques
    const manualAssigns = proposedAssignments.filter(a => manualAssignments.has(a.inscription.id));
    const autoAssigns = proposedAssignments.filter(a => !manualAssignments.has(a.inscription.id));

    // Comptar jugadors per categoria (incloent manuals)
    const categoryCounters = {};
    categories.forEach(cat => {
      categoryCounters[cat.id] = manualAssigns.filter(a => a.proposedCategory?.id === cat.id).length;
    });

    // Ordenar categories per ordre
    const orderedCategories = [...categories].sort((a, b) => a.ordre_categoria - b.ordre_categoria);

    // Calcular distribució òptima dels jugadors automàtics
    const totalAutoPlayers = autoAssigns.length;
    const numCategories = orderedCategories.length;

    // Calcular quants jugadors hauria de tenir cada categoria (total)
    const totalPlayers = proposedAssignments.length;
    const targetPlayersPerCategory = Math.floor(totalPlayers / numCategories);
    const remainingPlayers = totalPlayers % numCategories;

    // Ordenar assignacions automàtiques per mitjana
    const sortedAutoAssigns = [...autoAssigns].sort((a, b) => {
      const avgA = a.sociInfo.historicalAverage || a.sociInfo.oldestAverage || 0;
      const avgB = b.sociInfo.historicalAverage || b.sociInfo.oldestAverage || 0;
      return avgB - avgA;
    });

    // Redistribuir jugadors automàtics
    let autoPlayerIndex = 0;
    const newAssignments = [...manualAssigns];

    orderedCategories.forEach((category, catIndex) => {
      // Calcular quants jugadors ha de tenir aquesta categoria en total
      const targetTotal = targetPlayersPerCategory + (catIndex < remainingPlayers ? 1 : 0);
      // Restar els que ja té (manuals)
      const slotsAvailable = Math.max(0, targetTotal - categoryCounters[category.id]);

      // Assignar jugadors automàtics als slots disponibles
      for (let i = 0; i < slotsAvailable && autoPlayerIndex < totalAutoPlayers; i++) {
        const assignment = sortedAutoAssigns[autoPlayerIndex];
        assignment.proposedCategory = category;
        assignment.reason = `Posició ${autoPlayerIndex + 1} per mitjana (reequilibrat)`;

        if (assignment.sociInfo.historicalAverage !== null) {
          assignment.reason += ` (${assignment.sociInfo.historicalAverage.toFixed(2)} - any ${assignment.sociInfo.historicalAverageYear})`;
        } else if (assignment.sociInfo.oldestAverage !== null) {
          assignment.reason += ` (${assignment.sociInfo.oldestAverage.toFixed(2)} - any ${assignment.sociInfo.oldestAverageYear} - antiga)`;
        }

        newAssignments.push(assignment);
        autoPlayerIndex++;
      }
    });

    // Actualitzar la llista d'assignacions
    proposedAssignments = newAssignments;
  }
</script>

<div class="space-y-6">
  <!-- Configuració de l'assignació automàtica -->
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
      <span class="mr-2">🤖</span> Assignació Automàtica de Categories
    </h3>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <!-- Estratègia -->
      <div>
        <label for="assignment-strategy" class="block text-sm font-medium text-gray-700 mb-2">
          Estratègia d'assignació
        </label>
        <select
          id="assignment-strategy"
          bind:value={assignmentStrategy}
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="by_average">Per mitjana històrica</option>
          <option value="balanced">Equilibrada (igual nombre per categoria)</option>
          <option value="random">Aleatòria</option>
        </select>
      </div>

      <!-- Estadístiques -->
      <div>
        <div class="text-sm text-gray-600">
          <div>📝 <strong>{unassignedInscriptions.length}</strong> inscripcions sense categoria</div>
          <div>🏆 <strong>{categories.length}</strong> categories disponibles</div>
        </div>
      </div>
    </div>

    <!-- Configuració de rangs per mitjana -->
    {#if assignmentStrategy === 'by_average' && categories.length > 0}
      <div class="mt-6">
        <h4 class="text-md font-medium text-gray-800 mb-3">Rangs de mitjana per categoria</h4>
        <div class="space-y-3">
          {#each sortedCategories as category}
            <div class="flex items-center space-x-4 bg-gray-50 p-3 rounded-lg">
              <div class="flex-1">
                <div class="font-medium text-gray-900">{category.nom}</div>
                <div class="text-sm text-gray-600">{category.distancia_caramboles} caramboles</div>
              </div>
              <div class="flex items-center space-x-2">
                <label for="min-{category.id}" class="text-sm text-gray-600">Min:</label>
                <input
                  id="min-{category.id}"
                  type="number"
                  step="0.1"
                  min="0"
                  max="10"
                  value={averageRanges[category.id]?.min || 0}
                  on:input={(e) => updateRange(category.id, 'min', e.target.value)}
                  class="w-20 px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
              <div class="flex items-center space-x-2">
                <label for="max-{category.id}" class="text-sm text-gray-600">Max:</label>
                <input
                  id="max-{category.id}"
                  type="number"
                  step="0.1"
                  min="0"
                  max="10"
                  value={averageRanges[category.id]?.max || 99}
                  on:input={(e) => updateRange(category.id, 'max', e.target.value)}
                  class="w-20 px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Botons d'acció -->
    <div class="flex flex-wrap items-center gap-3 mt-6">
      <button
        on:click={generatePreview}
        disabled={processing || unassignedInscriptions.length === 0 || categories.length === 0}
        class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
      >
        {processing ? 'Processant...' : 'Generar Vista Prèvia'}
      </button>

      <button
        on:click={checkAutomaticPromotions}
        disabled={processing || categories.length === 0}
        class="px-4 py-2 bg-purple-600 text-white text-sm rounded hover:bg-purple-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
        title="Pujar automàticament guanyador i segon de cada categoria"
      >
        🏆 Ascensos Automàtics
      </button>

      {#if showPreview && proposedAssignments.length > 0}
        <button
          on:click={applyAssignments}
          disabled={processing}
          class="px-4 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 disabled:bg-gray-400"
        >
          Aplicar Assignacions
        </button>
        <button
          on:click={() => { showPreview = false; proposedAssignments = []; }}
          class="px-4 py-2 bg-gray-600 text-white text-sm rounded hover:bg-gray-700"
        >
          Cancel·lar
        </button>
      {/if}
    </div>
  </div>

  <!-- Vista prèvia de les assignacions -->
  {#if showPreview && proposedAssignments.length > 0}
    <div class="bg-white border border-gray-200 rounded-lg p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-2 flex items-center">
        <span class="mr-2">👀</span> Vista Prèvia de les Assignacions
      </h3>

      {#if manualAssignments.size > 0}
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-4">
          <p class="text-sm text-blue-800">
            ℹ️ {manualAssignments.size} assignació{manualAssignments.size > 1 ? 'ns' : ''} manual{manualAssignments.size > 1 ? 's' : ''}.
            Els altres jugadors s'han reequilibrat automàticament per mantenir una distribució equilibrada entre categories.
          </p>
        </div>
      {/if}

      <div class="space-y-3 max-h-96 overflow-y-auto">
        {#each proposedAssignments as assignment, index}
          <div class="flex items-center justify-between p-4 rounded-lg"
               class:bg-blue-50={manualAssignments.has(assignment.inscription.id)}
               class:bg-gray-50={!manualAssignments.has(assignment.inscription.id)}
               class:border-2={manualAssignments.has(assignment.inscription.id)}
               class:border-blue-300={manualAssignments.has(assignment.inscription.id)}>
            <div class="flex-1">
              <div class="flex items-center space-x-4">
                <div>
                  <div class="flex items-center gap-2">
                    <div class="font-medium text-gray-900">
                      {assignment.sociInfo.nom} {assignment.sociInfo.cognoms}
                    </div>
                    {#if manualAssignments.has(assignment.inscription.id)}
                      <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                        ✏️ Manual
                      </span>
                    {/if}
                  </div>
                  <div class="text-sm text-gray-600">
                    Soci #{assignment.sociInfo.numero_soci}
                    {#if assignment.sociInfo.historicalAverage !== null}
                      • Mitjana: {assignment.sociInfo.historicalAverage.toFixed(2)}
                    {:else}
                      • Sense mitjana històrica
                    {/if}
                  </div>
                </div>
                <div class="text-center">
                  <div class="text-sm text-gray-500">→</div>
                </div>
                <div>
                  <select
                    value={assignment.proposedCategory?.id || ''}
                    on:change={(e) => changeAssignment(index, e.target.value)}
                    class="px-3 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500"
                  >
                    <option value="">Sense categoria</option>
                    {#each categories as category}
                      <option value={category.id}>{category.nom}</option>
                    {/each}
                  </select>
                </div>
              </div>
              <div class="text-xs text-gray-500 mt-2">
                {assignment.reason}
              </div>
            </div>
            <button
              on:click={() => removeAssignment(index)}
              class="ml-4 text-red-600 hover:text-red-900 text-sm"
            >
              Eliminar
            </button>
          </div>
        {/each}
      </div>

      <div class="mt-4 text-sm text-gray-600 text-center">
        {proposedAssignments.length} assignacions proposades
      </div>
    </div>
  {/if}

  <!-- Modal per jugadors sense mitjana -->
  {#if showNoAverageModal}
    <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 max-w-3xl w-full mx-4 shadow-xl max-h-[90vh] overflow-y-auto">
        <h3 class="text-lg font-medium text-gray-900 mb-4">
          ⚠️ Jugadors sense mitjana històrica
        </h3>

        <p class="text-sm text-gray-600 mb-4">
          Els següents jugadors no tenen mitjana històrica. Si us plau, indica una mitjana estimada per poder fer l'assignació de categoria correctament.
        </p>

        <div class="space-y-4 mb-6">
          {#each playersWithoutAverage as player}
            <div class="bg-gray-50 p-4 rounded-lg">
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="font-medium text-gray-900">
                    {player.sociInfo.nom} {player.sociInfo.cognoms}
                  </div>
                  <div class="text-sm text-gray-600">
                    Soci #{player.sociInfo.numero_soci}
                  </div>
                  {#if player.sociInfo.oldestAverage}
                    <div class="text-sm text-amber-600 mt-1">
                      📊 Última mitjana registrada: {player.sociInfo.oldestAverage.toFixed(2)} (any {player.sociInfo.oldestAverageYear})
                    </div>
                  {/if}
                </div>
                <div class="ml-4">
                  <label for="avg-{player.inscription.id}" class="block text-sm font-medium text-gray-700 mb-1">
                    Mitjana estimada
                  </label>
                  <input
                    id="avg-{player.inscription.id}"
                    type="number"
                    step="0.1"
                    min="0"
                    max="10"
                    bind:value={estimatedAverages[player.inscription.id]}
                    placeholder={player.sociInfo.oldestAverage ? player.sociInfo.oldestAverage.toFixed(2) : "0.00"}
                    class="w-24 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              </div>
            </div>
          {/each}
        </div>

        <div class="flex justify-end space-x-3">
          <button
            on:click={() => { showNoAverageModal = false; playersWithoutAverage = []; }}
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel·lar
          </button>
          <button
            on:click={confirmNoAverageModal}
            class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700"
          >
            Continuar amb l'assignació
          </button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Modal per ascensos automàtics -->
  {#if showPromotionsModal}
    <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 max-w-4xl w-full mx-4 shadow-xl max-h-[90vh] overflow-y-auto">
        <h3 class="text-lg font-medium text-gray-900 mb-4">
          🏆 Ascensos Automàtics
        </h3>

        {#if proposedPromotions.length === 0}
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
            <p class="text-sm text-blue-800">
              ℹ️ No s'han trobat propostes d'ascens automàtic.
            </p>
            <p class="text-sm text-blue-700 mt-2">
              Això pot ser perquè no hi ha cap event finalitzat de la temporada anterior amb la mateixa modalitat,
              o perquè tots els guanyadors i subcampions ja estan assignats a la categoria més alta.
            </p>
          </div>
        {:else}
          <p class="text-sm text-gray-600 mb-4">
            Els següents jugadors són proposats per pujar de categoria basant-se en els resultats de la temporada anterior.
            Marca els ascensos que vols confirmar.
          </p>

          <div class="space-y-3 mb-6">
            {#each proposedPromotions as promo}
              <div class="bg-gray-50 p-4 rounded-lg border-l-4" class:border-yellow-400={promo.position === 1} class:border-gray-400={promo.position === 2}>
                <div class="flex items-start justify-between">
                  <div class="flex items-start space-x-3 flex-1">
                    <input
                      type="checkbox"
                      id="promo-{promo.player.numero_soci}"
                      bind:checked={confirmedPromotions[promo.player.numero_soci]}
                      class="mt-1 h-5 w-5 text-purple-600 focus:ring-purple-500 border-gray-300 rounded"
                    />
                    <label for="promo-{promo.player.numero_soci}" class="flex-1 cursor-pointer">
                      <div class="flex items-center gap-2">
                        <div class="font-medium text-gray-900">
                          {promo.player.nom} {promo.player.cognoms}
                        </div>
                        {#if promo.position === 1}
                          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                            🥇 Guanyador
                          </span>
                        {:else if promo.position === 2}
                          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                            🥈 Segon
                          </span>
                        {/if}
                      </div>
                      <div class="text-sm text-gray-600 mt-1">
                        Soci #{promo.player.numero_soci}
                      </div>
                      <div class="text-sm text-gray-700 mt-2">
                        {promo.reason}
                      </div>
                      <div class="flex items-center gap-2 mt-2">
                        <span class="text-sm font-medium text-gray-700">{promo.currentCategory}</span>
                        <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6"></path>
                        </svg>
                        <span class="text-sm font-medium text-purple-700">{promo.proposedCategory}</span>
                      </div>
                    </label>
                  </div>
                </div>
              </div>
            {/each}
          </div>
        {/if}

        <div class="flex justify-end space-x-3">
          <button
            on:click={() => { showPromotionsModal = false; proposedPromotions = []; confirmedPromotions = {}; }}
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            {proposedPromotions.length === 0 ? 'Tancar' : 'Cancel·lar'}
          </button>
          {#if proposedPromotions.length > 0}
            <button
              on:click={confirmPromotions}
              disabled={Object.values(confirmedPromotions).filter(Boolean).length === 0}
              class="px-4 py-2 text-sm font-medium text-white bg-purple-600 border border-transparent rounded-md hover:bg-purple-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
            >
              Confirmar {Object.values(confirmedPromotions).filter(Boolean).length} ascensos
            </button>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>