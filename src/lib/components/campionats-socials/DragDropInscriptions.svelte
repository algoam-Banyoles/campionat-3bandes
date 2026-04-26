<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import IntelligentCategoryMover from './IntelligentCategoryMover.svelte';
  import MovementPreviewModal from './MovementPreviewModal.svelte';
  import { lastMovementBatch } from '$lib/stores/movementUndoStore';
  import type { Category, CategoryMovement, InscripcioWithSoci, SociMin, UUID } from '$lib/types';

  const dispatch = createEventDispatcher();

  export let socis: SociMin[] = [];
  export let inscriptions: InscripcioWithSoci[] = [];
  export let categories: Category[] = [];
  export let loading = false;
  export let eventId: string = '';
  export let currentEvent: { modalitat?: string; temporada?: string } | null = null;
  export let useIntelligentMovement: boolean = true;

  type DragSource = 'available' | 'inscribed';
  type DraggedItem =
    | (SociMin & { source: 'available' })
    | (InscripcioWithSoci & { source: 'inscribed' });

  let searchTerm = '';
  let draggedItem: DraggedItem | null = null;
  let dragOverZone: string | null = null;

  // Referència al component intel·ligent
  let intelligentMover: IntelligentCategoryMover | undefined;

  // Estat de la confirmació de cascada
  let previewOpen = false;
  let previewMovements: CategoryMovement[] = [];
  let previewProcessing = false;
  let undoing = false;

  // Filtrar socis disponibles (no inscrits)
  $: availableSocis = socis.filter(soci =>
    !inscriptions.some(inscription => inscription.soci_numero === soci.numero_soci) &&
    (!searchTerm ||
     (soci.nom ?? '').toLowerCase().includes(searchTerm.toLowerCase()) ||
     (soci.cognoms ?? '').toLowerCase().includes(searchTerm.toLowerCase()) ||
     soci.numero_soci.toString().includes(searchTerm))
  );

  // Agrupar inscripcions per categoria
  $: inscriptionsByCategory = categories.reduce<Record<string, InscripcioWithSoci[]>>((acc, category) => {
    acc[category.id] = inscriptions.filter(inscription =>
      inscription.categoria_assignada_id === category.id
    );
    return acc;
  }, {});

  // Inscripcions sense categoria
  $: unassignedInscriptions = inscriptions.filter(inscription =>
    !inscription.categoria_assignada_id
  );

  /**
   * Determina si una categoria és "plena" (ha arribat al `max_jugadors`).
   * Es respecta tot i venir d'un soci nou (`available`) — només es permet
   * el moviment d'una inscripció ja existent dins de la mateixa categoria.
   */
  function isCategoryFull(category: Category): boolean {
    if (!category.max_jugadors) return false;
    const count = inscriptionsByCategory[category.id]?.length ?? 0;
    return count >= category.max_jugadors;
  }

  /** Indica si la categoria està prop del límit (≥ 80%). */
  function isCategoryNearFull(category: Category): boolean {
    if (!category.max_jugadors) return false;
    const count = inscriptionsByCategory[category.id]?.length ?? 0;
    return count >= Math.floor(category.max_jugadors * 0.8) && count < category.max_jugadors;
  }

  function handleDragStart(event: DragEvent, item: SociMin | InscripcioWithSoci, source: DragSource) {
    draggedItem = { ...(item as any), source };
    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/html', '');
    }
    (event.target as HTMLElement).style.opacity = '0.5';
  }

  function handleDragEnd(event: DragEvent) {
    (event.target as HTMLElement).style.opacity = '1';
    draggedItem = null;
    dragOverZone = null;
  }

  function handleDragOver(event: DragEvent, blocked = false) {
    event.preventDefault();
    if (event.dataTransfer) {
      event.dataTransfer.dropEffect = blocked ? 'none' : 'move';
    }
  }

  function handleDragEnter(event: DragEvent, zone: string) {
    event.preventDefault();
    dragOverZone = zone;
  }

  function handleDragLeave(event: DragEvent) {
    if (!(event.currentTarget as HTMLElement).contains(event.relatedTarget as Node)) {
      dragOverZone = null;
    }
  }

  async function handleDrop(event: DragEvent, targetCategory: UUID | null = null) {
    event.preventDefault();
    dragOverZone = null;

    if (!draggedItem) return;

    // Bloquejar drop si la categoria està plena (excepte moviments dins la mateixa cat.)
    if (targetCategory) {
      const cat = categories.find(c => c.id === targetCategory);
      if (cat && isCategoryFull(cat)) {
        const samePlace =
          draggedItem.source === 'inscribed' &&
          (draggedItem as InscripcioWithSoci).categoria_assignada_id === targetCategory;
        if (!samePlace) {
          dispatch('error', { message: `La categoria "${cat.nom}" ja té el màxim de ${cat.max_jugadors} jugadors.` });
          draggedItem = null;
          return;
        }
      }
    }

    if (draggedItem.source === 'available') {
      // Inscriure soci nou - sempre usar sistema tradicional
      dispatch('inscribe', {
        soci: draggedItem,
        categoryId: targetCategory
      });
    } else if (draggedItem.source === 'inscribed') {
      const inscribed = draggedItem as InscripcioWithSoci & { source: 'inscribed' };
      if (useIntelligentMovement && intelligentMover && targetCategory) {
        // Usar sistema intel·ligent
        await intelligentMover.movePlayerIntelligently(inscribed.id, targetCategory);
      } else {
        // Usar sistema tradicional
        dispatch('moveInscription', {
          inscriptionId: inscribed.id,
          categoryId: targetCategory
        });
      }
    }
  }

  function removeInscription(inscriptionId: UUID) {
    dispatch('removeInscription', { inscriptionId });
  }

  function getSociInfo(inscription: InscripcioWithSoci) {
    if (inscription.socis) {
      return {
        nom: inscription.socis.nom ?? '',
        cognoms: inscription.socis.cognoms ?? '',
        numero_soci: inscription.socis.numero_soci ?? inscription.soci_numero,
        email: inscription.socis.email ?? null
      };
    }
    const soci = socis.find(s => s.numero_soci === inscription.soci_numero);
    return soci || { nom: 'Desconegut', cognoms: '', numero_soci: inscription.soci_numero, email: null };
  }

  function handleMovementsCompleted(event: CustomEvent<{ movements: unknown[]; totalMoved: number }>) {
    const { movements, totalMoved } = event.detail;
    dispatch('intelligentMovementCompleted', {
      movements,
      totalMoved,
      message: `${totalMoved} jugadors moguts amb efecte cascada`
    });
  }

  function handleIntelligentMovementError(event: CustomEvent<{ message: string }>) {
    dispatch('error', event.detail);
  }

  function handleMovementsPending(event: CustomEvent<{ movements: CategoryMovement[] }>) {
    previewMovements = event.detail.movements;
    previewOpen = true;
  }

  async function confirmPreview() {
    if (!intelligentMover) return;
    previewProcessing = true;
    try {
      await intelligentMover.applyPendingMovements();
    } finally {
      previewProcessing = false;
      previewOpen = false;
      previewMovements = [];
    }
  }

  function cancelPreview() {
    intelligentMover?.cancelPendingMovements();
    previewOpen = false;
    previewMovements = [];
  }

  async function undoLastBatch() {
    if (!intelligentMover || !$lastMovementBatch || undoing) return;
    undoing = true;
    try {
      await intelligentMover.undoLastBatch($lastMovementBatch.movements);
    } finally {
      undoing = false;
    }
  }
</script>

<div class="space-y-6">
  <!-- Cercador -->
  <div class="bg-white border border-gray-200 rounded-lg p-4">
    <div class="flex items-center space-x-4">
      <div class="flex-1">
        <label for="search" class="block text-sm font-medium text-gray-700 mb-1">
          Cercar socis disponibles
        </label>
        <div class="relative">
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
          </div>
          <input
            id="search"
            type="text"
            bind:value={searchTerm}
            placeholder="Nom, cognoms o número de soci..."
            class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>
      </div>
      <div class="text-sm text-gray-500">
        {availableSocis.length} socis disponibles
      </div>
    </div>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <!-- Columna 1: Socis disponibles -->
    <div class="space-y-4">
      <h3 class="text-lg font-medium text-gray-900 flex items-center">
        <span class="mr-2">👥</span> Socis Disponibles
      </h3>

      <div class="bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg p-4 min-h-96 max-h-96 overflow-y-auto">
        {#if loading}
          <div class="flex items-center justify-center h-32">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span class="ml-2 text-gray-600">Carregant...</span>
          </div>
        {:else if availableSocis.length === 0}
          <div class="text-center text-gray-500 py-8">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
            </svg>
            <p class="mt-2">No hi ha socis disponibles</p>
            {#if searchTerm}
              <p class="text-sm">amb "{searchTerm}"</p>
            {/if}
          </div>
        {:else}
          {#each availableSocis as soci (soci.numero_soci)}
            <div
              draggable="true"
              role="button"
              tabindex="0"
              on:dragstart={(e) => handleDragStart(e, soci, 'available')}
              on:dragend={handleDragEnd}
              class="bg-white border border-gray-200 rounded-lg p-3 mb-2 cursor-move hover:shadow-md transition-shadow"
            >
              <div class="flex items-center justify-between">
                <div>
                  <div class="font-medium text-gray-900">
                    {soci.nom} {soci.cognoms}
                  </div>
                  <div class="text-sm text-gray-500">
                    Soci #{soci.numero_soci}
                  </div>
                </div>
                <div class="text-right">
                  {#if soci.historicalAverage != null}
                    <div class="text-sm font-medium text-blue-600">
                      {soci.historicalAverage.toFixed(2)}
                    </div>
                    <div class="text-xs text-gray-500">Mitjana</div>
                  {:else}
                    <div class="text-xs text-gray-500">Sense mitjana</div>
                  {/if}
                </div>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </div>

    <!-- Columna 2: Inscripcions sense categoria -->
    <div class="space-y-4">
      <h3 class="text-lg font-medium text-gray-900 flex items-center">
        <span class="mr-2">📝</span> Sense Categoria
      </h3>

      <div
        class="bg-yellow-50 border-2 border-dashed border-yellow-300 rounded-lg p-4 min-h-96 max-h-96 overflow-y-auto"
        class:border-yellow-500={dragOverZone === 'unassigned'}
        role="region"
        aria-label="Zona d'inscripcions no assignades"
        class:bg-yellow-100={dragOverZone === 'unassigned'}
        on:dragover={(e) => handleDragOver(e, false)}
        on:dragenter={(e) => handleDragEnter(e, 'unassigned')}
        on:dragleave={handleDragLeave}
        on:drop={(e) => handleDrop(e, null)}
      >
        {#if unassignedInscriptions.length === 0}
          <div class="text-center text-gray-500 py-8">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
            </svg>
            <p class="mt-2">Arrossega aquí per deixar sense categoria</p>
          </div>
        {:else}
          {#each unassignedInscriptions as inscription (inscription.id)}
            {@const sociInfo = getSociInfo(inscription)}
            <div
              draggable="true"
              role="button"
              tabindex="0"
              on:dragstart={(e) => handleDragStart(e, inscription, 'inscribed')}
              on:dragend={handleDragEnd}
              class="bg-white border border-gray-200 rounded-lg p-3 mb-2 cursor-move hover:shadow-md transition-shadow"
            >
              <div class="flex items-center justify-between">
                <div>
                  <div class="font-medium text-gray-900">
                    {sociInfo.nom} {sociInfo.cognoms}
                  </div>
                  <div class="text-sm text-gray-500">
                    Soci #{sociInfo.numero_soci}
                  </div>
                </div>
                <button
                  on:click={() => removeInscription(inscription.id)}
                  class="text-red-600 hover:text-red-900 text-sm"
                >
                  Eliminar
                </button>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </div>

    <!-- Columna 3: Categories -->
    <div class="space-y-4">
      <h3 class="text-lg font-medium text-gray-900 flex items-center">
        <span class="mr-2">🏆</span> Categories
      </h3>

      <div class="space-y-3 max-h-96 overflow-y-auto">
        {#each categories as category (category.id)}
          {@const count = inscriptionsByCategory[category.id]?.length ?? 0}
          {@const full = isCategoryFull(category)}
          {@const nearFull = isCategoryNearFull(category)}
          {@const draggingFromHere = draggedItem?.source === 'inscribed'
            && (draggedItem as InscripcioWithSoci).categoria_assignada_id === category.id}
          {@const dropBlocked = full && !draggingFromHere}
          <div class="bg-white border border-gray-200 rounded-lg" class:opacity-60={dropBlocked && draggedItem !== null}>
            <div class="px-4 py-2 border-b border-gray-200 rounded-t-lg"
              class:bg-blue-50={!full && !nearFull}
              class:bg-amber-50={nearFull}
              class:bg-red-50={full}
            >
              <div class="flex items-center justify-between">
                <div>
                  <h4 class="font-medium text-gray-900 flex items-center gap-2">
                    {category.nom}
                    {#if full}
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold bg-red-100 text-red-800 uppercase">
                        Plena
                      </span>
                    {:else if nearFull}
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold bg-amber-100 text-amber-800 uppercase">
                        Quasi plena
                      </span>
                    {/if}
                  </h4>
                  <div class="text-xs text-gray-600">
                    {category.distancia_caramboles} caramboles
                  </div>
                </div>
                <div class="text-right">
                  <div class="text-sm font-medium"
                    class:text-blue-600={!full && !nearFull}
                    class:text-amber-700={nearFull}
                    class:text-red-700={full}
                  >
                    {count}{#if category.max_jugadors}/{category.max_jugadors}{/if} inscrits
                  </div>
                  {#if category.min_jugadors && count < category.min_jugadors}
                    <div class="text-[10px] text-gray-500">
                      Mín. {category.min_jugadors}
                    </div>
                  {/if}
                </div>
              </div>
            </div>

            <div
              class="p-3 min-h-32 transition-colors"
              role="region"
              aria-label="Zona de categoria {category.nom}"
              class:border-blue-500={dragOverZone === category.id && !dropBlocked}
              class:bg-blue-50={dragOverZone === category.id && !dropBlocked}
              class:bg-red-50={dragOverZone === category.id && dropBlocked}
              class:cursor-not-allowed={dropBlocked && draggedItem !== null}
              on:dragover={(e) => handleDragOver(e, dropBlocked)}
              on:dragenter={(e) => handleDragEnter(e, category.id)}
              on:dragleave={handleDragLeave}
              on:drop={(e) => handleDrop(e, category.id)}
            >
              {#if dropBlocked && draggedItem !== null && dragOverZone === category.id}
                <div class="text-center text-red-700 py-4 font-medium text-sm">
                  ⛔ Categoria plena ({category.max_jugadors} jugadors)
                </div>
              {:else if !inscriptionsByCategory[category.id] || inscriptionsByCategory[category.id].length === 0}
                <div class="text-center text-gray-400 py-4">
                  <p class="text-sm">Arrossega jugadors aquí</p>
                </div>
              {:else}
                {#each inscriptionsByCategory[category.id] as inscription (inscription.id)}
                  {@const sociInfo = getSociInfo(inscription)}
                  <div
                    draggable="true"
                    role="button"
                    tabindex="0"
                    on:dragstart={(e) => handleDragStart(e, inscription, 'inscribed')}
                    on:dragend={handleDragEnd}
                    class="bg-gray-50 border border-gray-200 rounded p-2 mb-2 cursor-move hover:shadow-sm transition-shadow"
                  >
                    <div class="flex items-center justify-between">
                      <div>
                        <div class="text-sm font-medium text-gray-900">
                          {sociInfo.nom} {sociInfo.cognoms}
                        </div>
                        <div class="text-xs text-gray-500">
                          #{sociInfo.numero_soci}
                        </div>
                      </div>
                      <button
                        on:click={() => removeInscription(inscription.id)}
                        class="text-red-600 hover:text-red-900 text-xs"
                      >
                        ×
                      </button>
                    </div>
                  </div>
                {/each}
              {/if}
            </div>
          </div>
        {/each}

        {#if categories.length === 0}
          <div class="bg-gray-50 border border-gray-200 rounded-lg p-6">
            <div class="text-center text-gray-500">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14-7H5m14 14H5"/>
              </svg>
              <p class="mt-2">No hi ha categories creades</p>
              <p class="text-sm">Crea categories primer per organitzar les inscripcions</p>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>

<!-- Component intel·ligent per moviments (invisible) -->
<IntelligentCategoryMover
  bind:this={intelligentMover}
  {inscriptions}
  {categories}
  {socis}
  {eventId}
  {currentEvent}
  on:movementsCompleted={handleMovementsCompleted}
  on:movementsPending={handleMovementsPending}
  on:error={handleIntelligentMovementError}
/>

<!-- Modal de confirmació de moviments en cascada -->
<MovementPreviewModal
  open={previewOpen}
  movements={previewMovements}
  {categories}
  processing={previewProcessing}
  on:confirm={confirmPreview}
  on:cancel={cancelPreview}
/>

<!-- Xip flotant de "Desfer últim moviment" (apareix 5 min després d'un lot aplicat) -->
{#if $lastMovementBatch && $lastMovementBatch.movements.length > 0}
  <div class="fixed bottom-6 right-6 z-40 bg-white border border-gray-300 rounded-full shadow-lg pl-4 pr-2 py-2 flex items-center gap-3">
    <span class="text-sm text-gray-700">
      <span class="font-semibold">{$lastMovementBatch.movements.length}</span> moviment{$lastMovementBatch.movements.length === 1 ? '' : 's'} aplicat{$lastMovementBatch.movements.length === 1 ? '' : 's'}
    </span>
    <button
      type="button"
      on:click={undoLastBatch}
      disabled={undoing}
      class="inline-flex items-center gap-1.5 px-3 py-1 text-sm font-medium text-blue-700 bg-blue-50 hover:bg-blue-100 rounded-full disabled:opacity-50"
    >
      {#if undoing}
        <svg class="animate-spin h-3.5 w-3.5" fill="none" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25" />
          <path d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" fill="currentColor" class="opacity-75" />
        </svg>
        Desfent...
      {:else}
        ↶ Desfer
      {/if}
    </button>
  </div>
{/if}
