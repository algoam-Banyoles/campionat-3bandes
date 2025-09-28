<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  export let inscriptions: any[] = [];
  export let categories: any[] = [];
  export let socis: any[] = [];
  export let processing = false;

  let assignmentStrategy = 'by_average'; // 'by_average' | 'balanced' | 'random'
  let proposedAssignments = [];
  let showPreview = false;

  // Configuració dels rangs de mitjana per categoria
  let averageRanges = {};

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
    const categoryCounters = {};

    // Inicialitzar comptadors
    categories.forEach(cat => {
      categoryCounters[cat.id] = inscriptions.filter(i => i.categoria_assignada_id === cat.id).length;
    });

    // Ordenar inscripcions per mitjana (de més alta a més baixa)
    const sortedInscriptions = [...unassignedInscriptions].sort((a, b) => {
      const avgA = getSociInfo(a).historicalAverage || 0;
      const avgB = getSociInfo(b).historicalAverage || 0;
      return avgB - avgA;
    });

    sortedInscriptions.forEach((inscription, index) => {
      const sociInfo = getSociInfo(inscription);

      // Trobar la categoria amb menys jugadors
      const leastPopulatedCategory = categories.reduce((min, cat) => {
        return categoryCounters[cat.id] < categoryCounters[min.id] ? cat : min;
      });

      categoryCounters[leastPopulatedCategory.id]++;

      assignments.push({
        inscription,
        sociInfo,
        currentCategory: null,
        proposedCategory: leastPopulatedCategory,
        reason: `Equilibri de categories - ${categoryCounters[leastPopulatedCategory.id]} jugadors`
      });
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
    proposedAssignments = calculateAssignments();
    showPreview = true;
  }

  function applyAssignments() {
    const assignments = proposedAssignments.map(assignment => ({
      inscriptionId: assignment.inscription.id,
      categoryId: assignment.proposedCategory?.id || null
    }));

    dispatch('applyAssignments', { assignments });
    showPreview = false;
    proposedAssignments = [];
  }

  function updateRange(categoryId, field, value) {
    if (!averageRanges[categoryId]) {
      averageRanges[categoryId] = { min: 0, max: 99 };
    }
    averageRanges[categoryId][field] = parseFloat(value) || 0;
    averageRanges = { ...averageRanges }; // Force reactivity
  }

  function removeAssignment(index) {
    proposedAssignments = proposedAssignments.filter((_, i) => i !== index);
  }

  function changeAssignment(index, newCategoryId) {
    const newCategory = categories.find(c => c.id === newCategoryId);
    proposedAssignments[index].proposedCategory = newCategory;
    proposedAssignments[index].reason = 'Modificació manual';
    proposedAssignments = [...proposedAssignments]; // Force reactivity
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
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Estratègia d'assignació
        </label>
        <select
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
                <label class="text-sm text-gray-600">Min:</label>
                <input
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
                <label class="text-sm text-gray-600">Max:</label>
                <input
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
    <div class="flex items-center space-x-3 mt-6">
      <button
        on:click={generatePreview}
        disabled={processing || unassignedInscriptions.length === 0 || categories.length === 0}
        class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
      >
        {processing ? 'Processant...' : 'Generar Vista Prèvia'}
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
      <h3 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
        <span class="mr-2">👀</span> Vista Prèvia de les Assignacions
      </h3>

      <div class="space-y-3 max-h-96 overflow-y-auto">
        {#each proposedAssignments as assignment, index}
          <div class="flex items-center justify-between bg-gray-50 p-4 rounded-lg">
            <div class="flex-1">
              <div class="flex items-center space-x-4">
                <div>
                  <div class="font-medium text-gray-900">
                    {assignment.sociInfo.nom} {assignment.sociInfo.cognoms}
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
</div>