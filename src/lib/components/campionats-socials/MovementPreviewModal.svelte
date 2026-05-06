<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { Category, CategoryMovement } from '$lib/types';

  export let open = false;
  export let movements: CategoryMovement[] = [];
  export let categories: Category[] = [];
  export let processing = false;

  const dispatch = createEventDispatcher<{
    confirm: void;
    cancel: void;
  }>();

  function categoryName(id: string | null | undefined): string {
    if (!id) return 'Sense categoria';
    return categories.find(c => c.id === id)?.nom ?? 'Desconeguda';
  }

  function close() {
    if (processing) return;
    dispatch('cancel');
  }

  function confirm() {
    if (processing) return;
    dispatch('confirm');
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }

  $: cascadeCount = Math.max(0, movements.length - 1);
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div
    class="modal-backdrop"
    role="dialog"
    aria-modal="true"
    aria-labelledby="movement-preview-title"
  >
    <button
      type="button"
      class="backdrop-btn"
      aria-label="Tancar diàleg"
      on:click={close}
    ></button>

    <div class="modal-card">
      <div class="modal-head">
        <div class="editorial-eyebrow">Moviment intel·ligent</div>
        <h3 id="movement-preview-title" class="modal-title">Confirmar moviment</h3>
        <p class="modal-sub">
          {#if cascadeCount === 0}
            S'aplicarà 1 moviment.
          {:else}
            S'aplicaran <strong>{movements.length}</strong> moviments en total ({cascadeCount} per efecte cascada).
          {/if}
        </p>
      </div>

      <div class="modal-body">
        {#if movements.length === 0}
          <p class="empty-state">No hi ha moviments per aplicar.</p>
        {:else}
          <ol class="movement-list">
            {#each movements as m, i (m.inscriptionId + i)}
              {@const isMain = i === 0}
              <li class="movement-item" class:main={isMain}>
                <span class="movement-num">{i + 1}</span>
                <div class="movement-content">
                  <div class="movement-name">{m.playerName ?? 'Jugador'}</div>
                  <div class="movement-categories">
                    <span class="cat-from">{categoryName(m.previousCategoryId)}</span>
                    <span class="cat-arrow">→</span>
                    <span class="cat-to">{categoryName(m.categoryId)}</span>
                  </div>
                  <div class="movement-reason">{m.reason}</div>
                </div>
              </li>
            {/each}
          </ol>
        {/if}
      </div>

      <div class="modal-foot">
        <button type="button" class="btn-secondary" on:click={close} disabled={processing}>
          Cancel·lar
        </button>
        <button
          type="button"
          class="btn-primary"
          on:click={confirm}
          disabled={processing || movements.length === 0}
        >
          {processing ? 'Aplicant…' : 'Confirmar i aplicar'}
        </button>
      </div>
    </div>
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
  .backdrop-btn {
    position: absolute;
    inset: 0;
    background: transparent;
    border: none;
    cursor: default;
  }
  .modal-card {
    position: relative;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    width: 100%;
    max-width: 36rem;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    font-family: var(--font-sans, sans-serif);
  }
  .modal-head {
    padding: 1rem 1.3rem;
    border-bottom: 1px solid var(--rule, #e6e3dc);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .modal-title {
    margin: 0.3rem 0 0.4rem;
    font-size: 1.125rem;
    font-weight: 700;
    letter-spacing: -0.01em;
    color: var(--ink, #1a1814);
  }
  .modal-sub {
    margin: 0;
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
  }
  .modal-body {
    flex: 1;
    overflow-y: auto;
    padding: 1rem 1.3rem;
  }
  .empty-state {
    text-align: center;
    color: var(--ink-3, #807a72);
    padding: 2rem 0;
  }
  .movement-list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  .movement-item {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 0.75rem;
    background: var(--paper, #fbfaf6);
    border: 1px solid var(--rule, #e6e3dc);
  }
  .movement-item.main {
    background: var(--paper-elevated, #fff);
    border-color: var(--ink, #1a1814);
  }
  .movement-num {
    flex-shrink: 0;
    width: 1.75rem;
    height: 1.75rem;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
    font-weight: 700;
    background: var(--rule, #e6e3dc);
    color: var(--ink-2, #4a443e);
    font-variant-numeric: tabular-nums;
  }
  .movement-item.main .movement-num {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
  }
  .movement-content { flex: 1; min-width: 0; }
  .movement-name {
    font-weight: 600;
    color: var(--ink, #1a1814);
    font-size: 0.9375rem;
  }
  .movement-categories {
    margin-top: 0.2rem;
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
  }
  .cat-from { color: var(--ink-3, #807a72); }
  .cat-arrow {
    margin: 0 0.4rem;
    color: var(--ink-3, #807a72);
  }
  .cat-to {
    font-weight: 600;
    color: var(--ink, #1a1814);
  }
  .movement-reason {
    margin-top: 0.25rem;
    font-size: 0.75rem;
    color: var(--ink-3, #807a72);
  }
  .modal-foot {
    padding: 0.95rem 1.3rem;
    border-top: 1px solid var(--rule, #e6e3dc);
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    background: var(--paper, #fbfaf6);
  }
  .btn-secondary, .btn-primary {
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
  .btn-secondary:hover:not(:disabled) { background: var(--paper, #fbfaf6); }
  .btn-primary {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
  }
  .btn-primary:hover:not(:disabled) { opacity: 0.9; }
  .btn-secondary:disabled, .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
