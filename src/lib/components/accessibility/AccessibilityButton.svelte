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
  <span class="accessibility-text">Accessibilitat</span>
</button>

<style>
  .accessibility-button {
    position: fixed;
    top: 50%;
    right: 0;
    transform: translateY(-50%);
    z-index: 1000;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 16px;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 8px 0 0 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 1rem;
    font-weight: 600;
    box-shadow: -4px 0 12px rgba(59, 130, 246, 0.3);
    min-height: 48px;
    writing-mode: horizontal-tb;
  }

  .accessibility-button:hover {
    background: #2563eb;
    transform: translateY(-50%) translateX(-4px);
    box-shadow: -6px 0 16px rgba(59, 130, 246, 0.4);
  }

  /* Enhanced focus for desktop */
  @media (hover: hover) and (pointer: fine) {
    .accessibility-button:focus-visible {
      outline: 4px solid #fbbf24;
      outline-offset: 3px;
      box-shadow: 0 0 0 2px white, 0 0 0 7px #fbbf24, 0 0 16px rgba(251, 191, 36, 0.4);
      transform: translateY(-50%) translateX(-6px);
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
    font-size: 1.25rem;
  }

  .text-small {
    font-size: 0.875rem;
  }

  .accessibility-text {
    white-space: nowrap;
  }

  /* Mobile responsive */
  @media (max-width: 768px) {
    .accessibility-button {
      position: fixed;
      bottom: 80px;
      left: 16px;
      right: auto;
      top: auto;
      transform: none;
      padding: 14px 18px;
      border-radius: 50px;
      box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
    }

    .accessibility-button:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 16px rgba(59, 130, 246, 0.4);
    }
  }

  @media (max-width: 480px) {
    .accessibility-button {
      bottom: 88px;
      left: 12px;
      padding: 12px;
      border-radius: 50%;
      min-width: 56px;
      min-height: 56px;
    }

    .accessibility-text {
      display: none;
    }

    .text-large {
      font-size: 1.125rem;
    }

    .text-small {
      font-size: 0.75rem;
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
      transform: translateY(-50%);
    }

    @media (max-width: 768px) {
      .accessibility-button:hover {
        transform: none;
      }
    }
  }
</style>