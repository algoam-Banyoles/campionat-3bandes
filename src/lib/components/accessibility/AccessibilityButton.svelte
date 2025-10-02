<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  function openAccessibilityPanel() {
    dispatch('open');
  }
</script>

<button
  type="button"
  class="accessibility-button"
  on:click={openAccessibilityPanel}
  aria-label="Obrir controls d'accessibilitat"
  title="Obrir controls d'accessibilitat"
>
  <span class="accessibility-icon" aria-hidden="true">
    <span class="text-large">A</span><span class="text-small">a</span>
  </span>
</button>

<style>
  .accessibility-button {
    position: fixed;
    bottom: 20px;
    right: 20px;
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 2px;
    padding: 12px;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 50%;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 1rem;
    font-weight: 600;
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
    min-width: 48px;
    min-height: 48px;
    width: 48px;
    height: 48px;
  }

  .accessibility-button:hover {
    background: #2563eb;
    transform: scale(1.1);
    box-shadow: 0 6px 16px rgba(59, 130, 246, 0.4);
  }

  /* Enhanced focus for desktop */
  @media (hover: hover) and (pointer: fine) {
    .accessibility-button:focus-visible {
      outline: 4px solid #fbbf24;
      outline-offset: 3px;
      box-shadow: 0 0 0 2px white, 0 0 0 7px #fbbf24, 0 0 16px rgba(251, 191, 36, 0.4);
      transform: scale(1.15);
    }
  }

  /* Standard focus for non-desktop */
  @media not all and (hover: hover) and (pointer: fine) {
    .accessibility-button:focus-visible {
      outline: 3px solid #fbbf24;
      outline-offset: 2px;
    }
  }

  .accessibility-icon {
    display: flex;
    align-items: baseline;
    gap: 1px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-weight: 700;
    line-height: 1;
  }

  .text-large {
    font-size: 1.125rem;
  }

  .text-small {
    font-size: 0.8rem;
  }

  /* Mobile responsive */
  @media (max-width: 768px) {
    .accessibility-button {
      bottom: 16px;
      right: 16px;
    }
  }

  @media (max-width: 480px) {
    .accessibility-button {
      bottom: 16px;
      right: 16px;
      width: 44px;
      height: 44px;
      min-width: 44px;
      min-height: 44px;
      padding: 10px;
    }

    .text-large {
      font-size: 1rem;
    }

    .text-small {
      font-size: 0.7rem;
    }
  }

  /* High contrast mode */
  :global(.high-contrast) .accessibility-button {
    background: #000000 !important;
    color: #ffffff !important;
    border: 3px solid #ffffff !important;
  }

  :global(.high-contrast) .accessibility-button:focus {
    outline: 4px solid #ff0000 !important;
    outline-offset: 2px !important;
  }

  /* Respect reduced motion */
  @media (prefers-reduced-motion: reduce) {
    .accessibility-button {
      transition: none;
    }

    .accessibility-button:hover {
      transform: none;
    }
  }
</style>