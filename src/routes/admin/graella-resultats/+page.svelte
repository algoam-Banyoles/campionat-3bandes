<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import HeadToHeadGrid from '$lib/components/campionats-socials/HeadToHeadGrid.svelte';
  import HeadToHeadPrintable from '$lib/components/campionats-socials/HeadToHeadPrintable.svelte';

  let selectedEvent: any = null;
  let categories: any[] = [];
  let selectedCategory: any = null;
  let loading = false;
  let error = '';

  // Print modal
  let showPrintModal = false;
  let selectedCategoriesToPrint: Set<string> = new Set();
  let printableComponent: HeadToHeadPrintable;
  let loadingPrint = false;

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

  function openPrintModal() {
    showPrintModal = true;
    selectedCategoriesToPrint = new Set();
  }

  function toggleCategoryForPrint(categoryId: string) {
    if (selectedCategoriesToPrint.has(categoryId)) {
      selectedCategoriesToPrint.delete(categoryId);
    } else {
      selectedCategoriesToPrint.add(categoryId);
    }
    selectedCategoriesToPrint = selectedCategoriesToPrint;
  }

  function selectAllCategories() {
    selectedCategoriesToPrint = new Set(categories.map(c => c.id));
  }

  function deselectAllCategories() {
    selectedCategoriesToPrint = new Set();
  }

  async function prepareAndPrint() {
    if (selectedCategoriesToPrint.size === 0) {
      alert('Selecciona almenys una categoria per imprimir');
      return;
    }

    loadingPrint = true;

    // Load data for all selected categories
    for (const categoryId of selectedCategoriesToPrint) {
      await printableComponent.loadCategory(categoryId);
    }

    // Wait for rendering
    await new Promise(resolve => setTimeout(resolve, 500));

    // Get the printable content
    const printContent = document.querySelector('.print-only');
    if (!printContent) {
      loadingPrint = false;
      alert('Error: no s\'ha pogut trobar el contingut per imprimir');
      return;
    }

    // Convert logo images to use absolute URL
    const contentClone = printContent.cloneNode(true) as HTMLElement;
    const logos = contentClone.querySelectorAll('.corner-logo');
    logos.forEach((logo) => {
      const img = logo as HTMLImageElement;
      img.src = window.location.origin + '/logo.png';
    });

    // Close modal and reset loading state
    showPrintModal = false;
    loadingPrint = false;

    // Create a new window for printing
    const printWindow = window.open('', '_blank', 'width=1200,height=800');
    if (!printWindow) {
      alert('Error: no s\'ha pogut obrir la finestra d\'impressió. Comprova que els pop-ups estiguin permesos.');
      return;
    }

    // Write the HTML to the new window
    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <title>Graella de Resultats - Impressió</title>
          <style>
            @page {
              size: A3 landscape;
              margin: 1cm;
            }

            @media print {
              -webkit-print-color-adjust: exact !important;
              print-color-adjust: exact !important;
              color-adjust: exact !important;
            }

            * {
              box-sizing: border-box;
              margin: 0;
              padding: 0;
            }

            body {
              font-family: Arial, sans-serif;
              background: white;
              margin: 0;
              padding: 0;
            }

            ${getComputedPrintStyles()}
          </style>
        </head>
        <body>
          ${contentClone.innerHTML}
        </body>
      </html>
    `);

    printWindow.document.close();

    // Simple timeout approach - wait a bit for content to render, then print
    setTimeout(() => {
      try {
        printWindow.focus();
        printWindow.print();
        // Don't auto-close, let user close the window
      } catch (e) {
        console.error('Error printing:', e);
        alert('Error en la impressió. Si us plau, torna-ho a intentar.');
        printWindow.close();
      }
    }, 1000);
  }

  function getComputedPrintStyles(): string {
    // Get all styles from the HeadToHeadPrintable component - optimized to fit one category per A3 page
    return `
      .printable-container { width: 100%; }
      .print-page { width: 100%; padding: 0.15cm; page-break-inside: avoid; page-break-after: always; }
      .page-break { page-break-after: always; break-after: page; }

      .print-header { position: relative; margin-bottom: 0.15cm; padding-bottom: 0.1cm; border-bottom: 1px solid #000; min-height: 0.8cm; }
      .header-center { text-align: center; margin-bottom: 0; }
      .header-center h1 { font-size: 10pt; margin: 0; font-weight: bold; color: #000; line-height: 1.1; }
      .header-subtitle { font-size: 7pt; margin: 0; color: #000; }
      .header-right { position: absolute; right: 0; top: 0; text-align: right; }
      .category-info { font-size: 7pt; margin: 0; color: #000; }

      .print-grid { width: 100%; border-collapse: collapse; font-size: 5pt; margin-bottom: 0.2cm; color: #000; }
      .print-grid th, .print-grid td { border: 1px solid #444; padding: 0; text-align: center; }

      .corner-cell { background: #fff; width: 1.5cm; padding: 1px; vertical-align: middle; }
      .corner-logo { max-width: 100%; max-height: 1cm; height: auto; display: block; margin: 0 auto; }
      .player-header { background: #333; color: white; font-weight: bold; height: 1cm; width: 0.7cm; padding: 0; position: relative; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .player-name-rotated { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-45deg); transform-origin: center; white-space: nowrap; font-size: 5pt; width: 1.5cm; overflow: hidden; text-overflow: ellipsis; }

      .player-row-header { background: #e8e8e8; font-weight: bold; text-align: left; padding-left: 2px; font-size: 6pt; white-space: nowrap; width: 1.5cm; color: #000; -webkit-print-color-adjust: exact; print-color-adjust: exact; }

      .match-cell { width: 0.7cm; height: 0.6cm; padding: 0; vertical-align: middle; }
      .self-cell { background: #d0d0d0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .self-match { color: #666; font-size: 10pt; font-weight: bold; }

      .match-grid { display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: 1fr 1fr 1fr; width: 100%; height: 100%; border: 2px solid #000; gap: 1px; background-color: #000; }
      .grid-cell { border: none; padding: 0; text-align: center; font-size: 4.5pt; font-weight: 700; display: flex; align-items: center; justify-content: center; line-height: 1; background: #fff; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .grid-cell.top-left { grid-column: 1; grid-row: 1; }
      .grid-cell.top-right { grid-column: 2; grid-row: 1; }
      .grid-cell.middle-full { grid-column: 1 / -1; grid-row: 2; background: #f0f0f0; font-weight: bold; }
      .grid-cell.bottom-full { grid-column: 1 / -1; grid-row: 3; }

      .loading-text, .error-text, .empty-text { text-align: center; padding: 1cm; font-size: 10pt; }
      .error-text { color: #c00; }
    `;
  }

  function closePrintModal() {
    showPrintModal = false;
    selectedCategoriesToPrint = new Set();
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

<div class="no-print container mx-auto px-4 py-8 max-w-7xl">
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
          <div class="text-right space-y-3">
            <div>
              <div class="text-2xl font-bold text-blue-600">{categories.length}</div>
              <div class="text-sm text-gray-600">Categories</div>
            </div>
            <button
              on:click={openPrintModal}
              class="no-print inline-flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
              disabled={categories.length === 0}
            >
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
              </svg>
              Imprimir (A3)
            </button>
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

<!-- Print Modal -->
{#if showPrintModal}
  <div class="no-print fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
      <div class="p-6">
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-2xl font-bold text-gray-900">Selecciona Categories a Imprimir</h3>
          <button
            type="button"
            aria-label="Tancar modal d'impressió"
            on:click={closePrintModal}
            class="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <div class="mb-4 pb-4 border-b border-gray-200">
          <p class="text-sm text-gray-600 mb-3">
            Format: <strong>A3 Apaïsat</strong> | Cada categoria s'imprimirà en una pàgina independent
          </p>
          <div class="flex gap-2">
            <button
              on:click={selectAllCategories}
              class="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded hover:bg-blue-200"
            >
              Seleccionar Totes
            </button>
            <button
              on:click={deselectAllCategories}
              class="px-3 py-1 text-sm bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
            >
              Deseleccionar Totes
            </button>
          </div>
        </div>

        <div class="space-y-2 mb-6">
          {#each categories as category}
            <label class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors">
              <input
                type="checkbox"
                checked={selectedCategoriesToPrint.has(category.id)}
                on:change={() => toggleCategoryForPrint(category.id)}
                class="w-4 h-4 text-purple-600 rounded focus:ring-purple-500"
              />
              <div class="ml-3 flex-1">
                <div class="font-semibold text-gray-900">{category.nom}</div>
                <div class="text-sm text-gray-600">
                  {category.distancia_caramboles} caramboles | Max. {category.max_entrades} entrades
                </div>
              </div>
            </label>
          {/each}
        </div>

        <div class="flex items-center justify-between pt-4 border-t border-gray-200">
          <div class="text-sm text-gray-600">
            {selectedCategoriesToPrint.size} {selectedCategoriesToPrint.size === 1 ? 'categoria seleccionada' : 'categories seleccionades'}
          </div>
          <div class="flex gap-3">
            <button
              on:click={closePrintModal}
              class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
            >
              Cancel·lar
            </button>
            <button
              on:click={prepareAndPrint}
              disabled={selectedCategoriesToPrint.size === 0 || loadingPrint}
              class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
            >
              {#if loadingPrint}
                <svg class="animate-spin h-5 w-5 mr-2" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"/>
                </svg>
                Preparant...
              {:else}
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                </svg>
                Imprimir
              {/if}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- Hidden printable component -->
{#if selectedEvent && categories.length > 0}
  <div class="print-only">
    <HeadToHeadPrintable
      bind:this={printableComponent}
      eventId={selectedEvent.id}
      eventName="{modalityNames[selectedEvent.modalitat] || selectedEvent.modalitat}"
      season={selectedEvent.temporada}
      categories={categories}
    />
  </div>
{/if}

<style>
  :global(body) {
    background-color: #f9fafb;
  }

  /* Hide print content on screen */
  .print-only {
    display: none;
  }
</style>
