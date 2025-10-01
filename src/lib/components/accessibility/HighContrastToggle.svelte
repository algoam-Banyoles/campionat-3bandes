<script lang="ts">
  import { onMount } from 'svelte';

  let highContrast = false;

  onMount(() => {
    highContrast = localStorage.getItem('highContrast') === 'true';
    applyContrast();
  });

  function toggleContrast() {
    highContrast = !highContrast;
    applyContrast();
    localStorage.setItem('highContrast', highContrast.toString());
  }

  function applyContrast() {
    if (highContrast) {
      document.documentElement.classList.add('high-contrast');
    } else {
      document.documentElement.classList.remove('high-contrast');
    }
  }
</script>

<button
  type="button"
  class="contrast-toggle"
  on:click={toggleContrast}
  aria-pressed={highContrast}
  aria-label={highContrast ? 'Desactivar alt contrast' : 'Activar alt contrast'}
>
  <span class="contrast-icon" aria-hidden="true">
    {#if highContrast}
      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 2a8 8 0 100 16 8 8 0 000-16zM10 4a6 6 0 100 12V4z" clip-rule="evenodd"/>
      </svg>
    {:else}
      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path d="M10 2a8 8 0 100 16 8 8 0 000-16zM10 4a6 6 0 100 12V4z"/>
      </svg>
    {/if}
  </span>
  <span class="contrast-label">
    {highContrast ? 'Contrast Normal' : 'Alt Contrast'}
  </span>
</button>

<style>
  .contrast-toggle {
    display: flex;
    align-items: center;
    justify-content: flex-start;
    gap: 12px;
    padding: 16px 20px;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    background: #f9fafb;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 1rem;
    font-weight: 500;
    min-height: 56px;
    width: 100%;
  }

  .contrast-toggle:hover {
    border-color: #3b82f6;
    background: #f8fafc;
  }

  /* Enhanced focus for desktop */
  @media (hover: hover) and (pointer: fine) {
    .contrast-toggle:focus-visible {
      outline: 4px solid #2563eb;
      outline-offset: 3px;
      box-shadow: 0 0 0 2px white, 0 0 0 7px #2563eb, 0 0 12px rgba(37, 99, 235, 0.3);
      transform: translateY(-2px);
    }
  }

  /* Standard focus for non-desktop */
  @media not all and (hover: hover) and (pointer: fine) {
    .contrast-toggle:focus-visible {
      outline: 2px solid #3b82f6;
      outline-offset: 2px;
    }
  }

  .contrast-toggle[aria-pressed="true"] {
    background: #1f2937;
    color: white;
    border-color: #1f2937;
  }

  .contrast-toggle[aria-pressed="true"]:hover {
    background: #374151;
    border-color: #374151;
  }

  .contrast-icon {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .contrast-label {
    font-size: 1rem;
    white-space: nowrap;
  }

  /* Mobile adjustments */
  @media (max-width: 640px) {
    .contrast-toggle {
      padding: 10px 12px;
      font-size: 0.875rem;
      min-height: 44px;
    }

    .contrast-label {
      font-size: 0.875rem;
    }
  }

  /* Very small screens - icon only */
  @media (max-width: 480px) {
    .contrast-label {
      display: none;
    }

    .contrast-toggle {
      min-width: 48px;
      padding: 12px;
    }
  }
</style>