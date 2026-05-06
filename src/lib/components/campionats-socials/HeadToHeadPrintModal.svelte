<script lang="ts">
  import HeadToHeadPrintable from '$lib/components/campionats-socials/HeadToHeadPrintable.svelte';
  import { showError, showWarning } from '$lib/stores/toastStore';

  export let event: { id: string; modalitat?: string; temporada?: string };
  export let categories: Array<{ id: string; nom: string; distancia_caramboles: number; max_entrades?: number }>;

  let showPrintModal = false;
  let selectedCategoriesToPrint: Set<string> = new Set();
  let printableComponent: HeadToHeadPrintable;
  let loadingPrint = false;

  const modalityNames: Record<string, string> = {
    tres_bandes: '3 Bandes',
    lliure: 'Lliure',
    banda: 'Banda'
  };

  export function open() {
    showPrintModal = true;
    selectedCategoriesToPrint = new Set();
  }

  function closePrintModal() {
    showPrintModal = false;
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
    selectedCategoriesToPrint = new Set(categories.map((c) => c.id));
  }

  function deselectAllCategories() {
    selectedCategoriesToPrint = new Set();
  }

  async function prepareAndPrint() {
    if (selectedCategoriesToPrint.size === 0) {
      showWarning('Selecciona almenys una categoria per imprimir');
      return;
    }

    loadingPrint = true;

    for (const categoryId of selectedCategoriesToPrint) {
      await printableComponent.loadCategory(categoryId);
    }

    await new Promise((resolve) => setTimeout(resolve, 500));

    const printContent = document.querySelector('.print-only');
    if (!printContent) {
      loadingPrint = false;
      showError("No s'ha pogut trobar el contingut per imprimir");
      return;
    }

    const contentClone = printContent.cloneNode(true) as HTMLElement;
    const logos = contentClone.querySelectorAll('.corner-logo');
    logos.forEach((logo) => {
      const img = logo as HTMLImageElement;
      img.src = window.location.origin + '/logo.png';
    });

    showPrintModal = false;
    loadingPrint = false;

    const printWindow = window.open('', '_blank', 'width=1200,height=800');
    if (!printWindow) {
      showError("No s'ha pogut obrir la finestra d'impressió. Comprova que els pop-ups estiguin permesos.");
      return;
    }

    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <title></title>
          <style>
            @page { size: A3 landscape; margin: 0; }
            @media print {
              -webkit-print-color-adjust: exact !important;
              print-color-adjust: exact !important;
              color-adjust: exact !important;
            }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body { font-family: Arial, sans-serif; background: white; margin: 0; padding: 0; }
            ${getComputedPrintStyles()}
          </style>
        </head>
        <body>${contentClone.innerHTML}</body>
      </html>
    `);

    printWindow.document.close();

    setTimeout(() => {
      try {
        printWindow.focus();
        printWindow.print();
      } catch (e) {
        console.error('Error printing:', e);
        showError("Error en la impressió. Si us plau, torna-ho a intentar.");
        printWindow.close();
      }
    }, 1000);
  }

  function getComputedPrintStyles(): string {
    return `
      .printable-container { width: 100%; }
      .print-page { width: 100%; padding: 0.4cm; padding-bottom: 1.5cm; page-break-inside: avoid; page-break-after: always; position: relative; min-height: 100vh; box-sizing: border-box; }
      .page-break { page-break-after: always; break-after: page; }
      .print-header { position: relative; margin-bottom: 0.15cm; padding-bottom: 0.1cm; border-bottom: 1px solid #000; min-height: 0.8cm; }
      .header-center { text-align: center; margin-bottom: 0; }
      .header-center h1 { font-size: 10pt; margin: 0; font-weight: bold; color: #000; line-height: 1.1; }
      .header-subtitle { font-size: 7pt; margin: 0; color: #000; }
      .header-right { position: absolute; right: 0; top: 0; text-align: right; }
      .category-info { font-size: 7pt; margin: 0; color: #000; }
      .print-grid { width: 100%; border-collapse: collapse; font-size: 7pt; margin-bottom: 0.2cm; color: #000; }
      .print-grid th, .print-grid td { border: 1px solid #444; padding: 0; text-align: center; }
      .corner-cell { background: #fff; width: 1.5cm; padding: 1px; vertical-align: middle; }
      .corner-logo { max-width: 100%; max-height: 1cm; height: auto; display: block; margin: 0 auto; }
      .player-header { background: #333; color: white; font-weight: bold; height: 1.2cm; width: 0.9cm; padding: 0; position: relative; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .player-name-rotated { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-45deg); transform-origin: center; white-space: nowrap; font-size: 5pt; width: 1.5cm; overflow: hidden; text-overflow: ellipsis; }
      .player-row-header { background: #e8e8e8; font-weight: bold; text-align: left; padding-left: 2px; font-size: 7pt; white-space: nowrap; width: 1.7cm; color: #000; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .match-cell { width: 1.15cm; height: 1.05cm; padding: 0; vertical-align: middle; }
      .self-cell { background: #d0d0d0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .self-match { color: #666; font-size: 10pt; font-weight: bold; }
      .match-grid { display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: 1fr 1fr 1fr; width: 100%; height: 100%; border: 2px solid #000; gap: 1px; background-color: #000; }
      .grid-cell { border: none; padding: 0; text-align: center; font-size: 10pt; font-weight: 800; display: flex; align-items: center; justify-content: center; line-height: 1; background: #fff; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .grid-cell.top-left { grid-column: 1; grid-row: 1; }
      .grid-cell.top-right { grid-column: 2; grid-row: 1; }
      .grid-cell.middle-full { grid-column: 1 / -1; grid-row: 2; background: #f0f0f0; font-weight: bold; }
      .grid-cell.bottom-full { grid-column: 1 / -1; grid-row: 3; }
      .loading-text, .error-text, .empty-text { text-align: center; padding: 1cm; font-size: 10pt; }
      .error-text { color: #c00; }
      .print-footer { position: absolute; bottom: 0.3cm; left: 0.3cm; right: 0.3cm; display: flex; align-items: center; justify-content: center; gap: 0.3cm; padding-top: 0.1cm; border-top: 0.5px solid #ccc; height: 1.4cm; }
      .qr-code { width: 1.2cm; height: 1.2cm; display: block; }
      .qr-text { font-size: 14pt; color: #555; font-style: italic; line-height: 1; }
    `;
  }
</script>

{#if showPrintModal}
  <div class="modal-backdrop" on:click={closePrintModal} on:keydown={(e) => e.key === 'Escape' && closePrintModal()} role="presentation">
    <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
    <div class="modal-card" on:click|stopPropagation role="dialog" aria-labelledby="h2hp-title" tabindex="-1">
      <div class="modal-head">
        <h3 id="h2hp-title">Selecciona categories a imprimir</h3>
        <button type="button" class="modal-close" on:click={closePrintModal} aria-label="Tancar">×</button>
      </div>

      <div class="modal-body">
        <p class="hint">
          Format: <strong>A3 apaïsat</strong> · Cada categoria s'imprimeix en una pàgina independent.
        </p>
        <div class="quick-actions">
          <button type="button" class="quick-btn" on:click={selectAllCategories}>Seleccionar totes</button>
          <button type="button" class="quick-btn" on:click={deselectAllCategories}>Deseleccionar totes</button>
        </div>

        <div class="cat-list">
          {#each categories as category}
            <label class="cat-row">
              <input
                type="checkbox"
                checked={selectedCategoriesToPrint.has(category.id)}
                on:change={() => toggleCategoryForPrint(category.id)}
              />
              <div class="cat-info">
                <div class="cat-name">{category.nom}</div>
                {#if category.distancia_caramboles}
                  <div class="cat-meta">
                    {category.distancia_caramboles} caramboles
                    {#if category.max_entrades} · Màx. {category.max_entrades} entrades{/if}
                  </div>
                {/if}
              </div>
            </label>
          {/each}
        </div>
      </div>

      <div class="modal-foot">
        <span class="count">
          {selectedCategoriesToPrint.size}
          {selectedCategoriesToPrint.size === 1 ? 'categoria seleccionada' : 'categories seleccionades'}
        </span>
        <div class="actions">
          <button type="button" class="btn-secondary" on:click={closePrintModal}>Cancel·lar</button>
          <button
            type="button"
            class="btn-primary"
            on:click={prepareAndPrint}
            disabled={selectedCategoriesToPrint.size === 0 || loadingPrint}
          >
            {loadingPrint ? 'Preparant…' : 'Imprimir'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- Component ocult de renderitzat per a impressió -->
{#if event && categories.length > 0}
  <div class="print-only">
    <HeadToHeadPrintable
      bind:this={printableComponent}
      eventId={event.id}
      eventName={modalityNames[event.modalitat ?? ''] ?? event.modalitat ?? ''}
      season={event.temporada ?? ''}
      {categories}
    />
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 60;
    padding: 1rem;
  }
  .modal-card {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    width: 100%;
    max-width: 36rem;
    max-height: 90vh;
    overflow-y: auto;
    font-family: var(--font-sans, sans-serif);
  }
  .modal-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.1rem 1.3rem;
    border-bottom: 1px solid var(--rule, #e6e3dc);
  }
  .modal-head h3 {
    margin: 0;
    font-size: 1.05rem;
    font-weight: 700;
    letter-spacing: -0.01em;
    color: var(--ink, #1a1814);
  }
  .modal-close {
    background: transparent;
    border: none;
    font-size: 1.5rem;
    line-height: 1;
    color: var(--ink-3, #807a72);
    cursor: pointer;
  }
  .modal-close:hover { color: var(--ink, #1a1814); }
  .modal-body { padding: 1.1rem 1.3rem; }
  .hint {
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
    margin: 0 0 0.85rem;
  }
  .quick-actions {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1rem;
  }
  .quick-btn {
    background: var(--paper, #fbfaf6);
    border: 1px solid var(--rule, #e6e3dc);
    padding: 0.4rem 0.75rem;
    font-size: 0.8125rem;
    font-weight: 500;
    cursor: pointer;
    color: var(--ink-2, #4a443e);
    font-family: var(--font-sans, sans-serif);
  }
  .quick-btn:hover { border-color: var(--ink, #1a1814); color: var(--ink, #1a1814); }
  .cat-list { display: flex; flex-direction: column; gap: 0.35rem; }
  .cat-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.7rem 0.8rem;
    border: 1px solid var(--rule, #e6e3dc);
    cursor: pointer;
    background: var(--paper-elevated, #fff);
  }
  .cat-row:hover { background: var(--paper, #fbfaf6); }
  .cat-row input[type='checkbox'] {
    width: 1rem;
    height: 1rem;
    accent-color: var(--ink, #1a1814);
  }
  .cat-info { flex: 1; }
  .cat-name { font-weight: 600; color: var(--ink, #1a1814); font-size: 0.9375rem; }
  .cat-meta { font-size: 0.8125rem; color: var(--ink-3, #807a72); margin-top: 0.15rem; }
  .modal-foot {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.3rem;
    border-top: 1px solid var(--rule, #e6e3dc);
    background: var(--paper, #fbfaf6);
  }
  .count { font-size: 0.8125rem; color: var(--ink-2, #4a443e); }
  .actions { display: flex; gap: 0.5rem; }
  .btn-secondary,
  .btn-primary {
    padding: 0.55rem 1rem;
    font-family: var(--font-sans, sans-serif);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    border: 1px solid var(--ink, #1a1814);
  }
  .btn-secondary {
    background: var(--paper-elevated, #fff);
    color: var(--ink, #1a1814);
  }
  .btn-secondary:hover { background: var(--paper, #fbfaf6); }
  .btn-primary {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
  }
  .btn-primary:hover:not(:disabled) { opacity: 0.9; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .print-only { display: none; }
</style>
