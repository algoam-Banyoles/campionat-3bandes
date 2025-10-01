<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import FontSizeControl from './FontSizeControl.svelte';
  import HighContrastToggle from './HighContrastToggle.svelte';

  export let isOpen = false;

  const dispatch = createEventDispatcher();
  let modalElement: HTMLElement;
  let previousActiveElement: HTMLElement | null = null;

  onMount(() => {
    // Capture the element that was focused before opening the modal
    if (isOpen) {
      previousActiveElement = document.activeElement as HTMLElement;
    }
  });

  $: if (isOpen) {
    // Focus the modal when it opens
    setTimeout(() => {
      if (modalElement) {
        modalElement.focus();
      }
    }, 100);

    // Prevent body scroll
    document.body.style.overflow = 'hidden';
  } else {
    // Restore body scroll
    document.body.style.overflow = '';

    // Return focus to the element that opened the modal
    if (previousActiveElement) {
      previousActiveElement.focus();
    }
  }

  function closeModal() {
    isOpen = false;
    dispatch('close');
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      closeModal();
    }
  }

  function handleBackdropClick(event: MouseEvent) {
    if (event.target === event.currentTarget) {
      closeModal();
    }
  }

  function trapFocus(event: KeyboardEvent) {
    if (event.key !== 'Tab') return;

    const focusableElements = modalElement.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const firstElement = focusableElements[0] as HTMLElement;
    const lastElement = focusableElements[focusableElements.length - 1] as HTMLElement;

    if (event.shiftKey) {
      if (document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
      }
    } else {
      if (document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    }
  }
</script>

{#if isOpen}
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div
    class="modal-backdrop"
    on:click={handleBackdropClick}
    on:keydown={handleKeydown}
    role="dialog"
    aria-modal="true"
    aria-labelledby="accessibility-modal-title"
    tabindex="0"
  >
    <!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
    <div
      bind:this={modalElement}
      class="modal-content"
      on:keydown={trapFocus}
      role="document"
      tabindex="-1"
    >
      <div class="modal-header">
        <h2 id="accessibility-modal-title" class="modal-title">
          Configuració d'Accessibilitat
        </h2>
        <button
          type="button"
          class="close-button"
          on:click={closeModal}
          aria-label="Tancar configuració d'accessibilitat"
        >
          <svg class="close-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>

      <div class="modal-body">
        <div class="control-section">
          <h3 class="control-title">Mida del Text</h3>
          <p class="control-description">Ajusta la mida del text per millorar la llegibilitat</p>
          <FontSizeControl />
        </div>

        <div class="control-section">
          <h3 class="control-title">Contrast</h3>
          <p class="control-description">Activa el mode d'alt contrast per millorar la visibilitat</p>
          <HighContrastToggle />
        </div>

        <div class="info-section">
          <h3 class="info-title">Navegació amb Teclat</h3>
          <ul class="keyboard-shortcuts">
            <li><kbd>Tab</kbd> - Navegar entre elements</li>
            <li><kbd>Enter</kbd> o <kbd>Espai</kbd> - Activar botons</li>
            <li><kbd>Esc</kbd> - Tancar aquest panel</li>
          </ul>
        </div>
      </div>

      <div class="modal-footer">
        <button
          type="button"
          class="done-button"
          on:click={closeModal}
        >
          Fet
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.6);
    z-index: 10000;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }

  .modal-content {
    background: white;
    border-radius: 16px;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
    max-width: 500px;
    width: 100%;
    max-height: 90vh;
    overflow-y: auto;
    position: relative;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 24px 24px 0 24px;
    border-bottom: 1px solid #e5e7eb;
    margin-bottom: 24px;
    padding-bottom: 16px;
  }

  .modal-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
    margin: 0;
  }

  .close-button {
    padding: 8px;
    background: none;
    border: none;
    cursor: pointer;
    color: #6b7280;
    border-radius: 6px;
    transition: all 0.2s ease;
    min-height: 40px;
    min-width: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-button:hover {
    background: #f3f4f6;
    color: #374151;
  }

  /* Enhanced focus for desktop */
  @media (hover: hover) and (pointer: fine) {
    .close-button:focus-visible {
      outline: 4px solid #2563eb;
      outline-offset: 2px;
      box-shadow: 0 0 0 2px white, 0 0 0 7px #2563eb, 0 0 12px rgba(37, 99, 235, 0.3);
      background: #dbeafe;
    }

    .done-button:focus-visible {
      outline: 4px solid #fbbf24;
      outline-offset: 3px;
      box-shadow: 0 0 0 2px white, 0 0 0 7px #fbbf24, 0 0 12px rgba(251, 191, 36, 0.3);
      transform: translateY(-2px);
    }
  }

  /* Standard focus for non-desktop */
  @media not all and (hover: hover) and (pointer: fine) {
    .close-button:focus-visible {
      outline: 2px solid #3b82f6;
      outline-offset: 2px;
    }

    .done-button:focus-visible {
      outline: 2px solid #3b82f6;
      outline-offset: 2px;
    }
  }

  .close-icon {
    width: 20px;
    height: 20px;
  }

  .modal-body {
    padding: 0 24px;
  }

  .control-section {
    margin-bottom: 32px;
  }

  .control-title {
    font-size: 1.25rem;
    font-weight: 600;
    color: #1f2937;
    margin: 0 0 8px 0;
  }

  .control-description {
    font-size: 1rem;
    color: #6b7280;
    margin: 0 0 16px 0;
    line-height: 1.5;
  }

  .info-section {
    background: #f8fafc;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 24px;
  }

  .info-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: #1f2937;
    margin: 0 0 12px 0;
  }

  .keyboard-shortcuts {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .keyboard-shortcuts li {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 8px;
    font-size: 0.875rem;
    color: #4b5563;
  }

  .keyboard-shortcuts li:last-child {
    margin-bottom: 0;
  }

  kbd {
    background: #e5e7eb;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    padding: 2px 6px;
    font-size: 0.75rem;
    font-family: ui-monospace, SFMono-Regular, monospace;
    color: #374151;
    min-width: 24px;
    text-align: center;
  }

  .modal-footer {
    padding: 24px;
    border-top: 1px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
  }

  .done-button {
    background: #3b82f6;
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    min-height: 48px;
  }

  .done-button:hover {
    background: #2563eb;
  }

  .done-button:focus {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }

  /* Mobile adjustments */
  @media (max-width: 640px) {
    .modal-backdrop {
      padding: 16px;
    }

    .modal-content {
      border-radius: 12px;
      max-height: 95vh;
    }

    .modal-header,
    .modal-body,
    .modal-footer {
      padding-left: 20px;
      padding-right: 20px;
    }

    .modal-title {
      font-size: 1.375rem;
    }

    .control-title {
      font-size: 1.125rem;
    }
  }

  /* High contrast mode */
  :global(.high-contrast) .modal-content {
    background: #ffffff !important;
    border: 3px solid #000000 !important;
  }

  :global(.high-contrast) .modal-backdrop {
    background: rgba(0, 0, 0, 0.8) !important;
  }

  :global(.high-contrast) .modal-title,
  :global(.high-contrast) .control-title,
  :global(.high-contrast) .info-title {
    color: #000000 !important;
  }

  :global(.high-contrast) .done-button {
    background: #000000 !important;
    color: #ffffff !important;
    border: 2px solid #000000 !important;
  }

  /* Respect reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .close-button,
    .done-button {
      transition: none;
    }
  }
</style>