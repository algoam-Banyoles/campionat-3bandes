<script lang="ts">
  import { onMount } from 'svelte';

  let fontSize = 'normal';

  const fontSizes = {
    small: { label: 'Petit', multiplier: 0.9 },
    normal: { label: 'Normal', multiplier: 1.0 },
    large: { label: 'Gran', multiplier: 1.15 },
    xlarge: { label: 'Extra Gran', multiplier: 1.3 }
  };

  onMount(() => {
    fontSize = localStorage.getItem('fontSize') || 'normal';
    applyFontSize();
  });

  function applyFontSize() {
    const multiplier = fontSizes[fontSize].multiplier;
    document.documentElement.style.setProperty('--font-size-multiplier', multiplier.toString());
    localStorage.setItem('fontSize', fontSize);
  }

  function changeFontSize(size: string) {
    fontSize = size;
    applyFontSize();
  }
</script>

<div class="font-control" role="group" aria-labelledby="font-control-label">
  <h3 id="font-control-label" class="sr-only">Control de mida de text</h3>

  <div class="font-control-buttons">
    {#each Object.entries(fontSizes) as [key, { label }]}
      <button
        type="button"
        class="font-btn"
        class:active={fontSize === key}
        on:click={() => changeFontSize(key)}
        aria-pressed={fontSize === key}
        aria-label="Establir text {label.toLowerCase()}"
      >
        <span class="font-preview" style="font-size: {fontSizes[key].multiplier}em;" aria-hidden="true">A</span>
        <span class="font-label">{label}</span>
      </button>
    {/each}
  </div>
</div>

<style>
  .font-control {
    background: transparent;
    border: none;
    border-radius: 0;
    padding: 0;
    box-shadow: none;
  }

  .font-control-buttons {
    display: flex;
    gap: 8px;
  }

  .font-btn {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    padding: 16px 12px;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    background: #f9fafb;
    cursor: pointer;
    transition: all 0.2s ease;
    min-width: 80px;
    min-height: 72px;
    flex: 1;
  }

  .font-btn:hover {
    border-color: #3b82f6;
    background: #f8fafc;
  }

  /* Enhanced focus for desktop */
  @media (hover: hover) and (pointer: fine) {
    .font-btn:focus-visible {
      outline: 4px solid #2563eb;
      outline-offset: 3px;
      box-shadow: 0 0 0 2px white, 0 0 0 7px #2563eb, 0 0 12px rgba(37, 99, 235, 0.3);
      transform: translateY(-2px);
    }
  }

  /* Standard focus for non-desktop */
  @media not all and (hover: hover) and (pointer: fine) {
    .font-btn:focus-visible {
      outline: 2px solid #3b82f6;
      outline-offset: 2px;
    }
  }

  .font-btn.active {
    border-color: #3b82f6;
    background: #dbeafe;
    color: #1e40af;
  }

  .font-preview {
    font-weight: 600;
    line-height: 1;
  }

  .font-label {
    font-size: 0.875rem;
    font-weight: 500;
    text-align: center;
  }

  /* Hide on very small screens */
  @media (max-width: 480px) {
    .font-control {
      padding: 8px;
    }

    .font-btn {
      min-width: 50px;
      min-height: 50px;
      padding: 8px 6px;
    }

    .font-label {
      font-size: 0.625rem;
    }
  }
</style>