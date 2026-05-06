<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';

  export let match: any | null = null;
  export let saving: boolean = false;

  const dispatch = createEventDispatcher<{
    selectAbsent: { player: 1 | 2 };
    close: void;
  }>();

  function selectPlayer(player: 1 | 2) {
    dispatch('selectAbsent', { player });
  }

  function handleClose() {
    dispatch('close');
  }
</script>

{#if match}
  <div class="modal-root" role="dialog" aria-modal="true">
    <div class="modal-overlay" on:click={handleClose} role="presentation"></div>
    <div class="modal-card modal-card-lg modal-card-danger">
      <div class="modal-head">
        <div>
          <div class="editorial-eyebrow danger">Incompareixença</div>
          <h3 class="modal-title">Quin jugador no s'ha presentat?</h3>
        </div>
      </div>

      <div class="modal-body">
        <div class="info-callout">
          <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Conseqüències</div>
          <ul class="info-list">
            <li>El jugador que <strong>no s'ha presentat</strong>: 0 punts, 50 entrades.</li>
            <li>El jugador que <strong>s'ha presentat</strong>: 2 punts, 0 entrades.</li>
            <li>Amb <strong>2 incompareixences</strong>, eliminació automàtica del campionat.</li>
            <li>Les partides pendents del jugador eliminat queden <strong>anul·lades</strong>.</li>
          </ul>
        </div>

        <div class="player-pick-grid">
          <button
            type="button"
            on:click={() => selectPlayer(1)}
            class="player-pick"
            disabled={saving}
          >
            <div class="pick-eyebrow">Jugador 1</div>
            <div class="pick-name">{formatPlayerName(match.jugador1)}</div>
            <div class="pick-cta">Marcar incompareixença →</div>
          </button>

          <button
            type="button"
            on:click={() => selectPlayer(2)}
            class="player-pick"
            disabled={saving}
          >
            <div class="pick-eyebrow">Jugador 2</div>
            <div class="pick-name">{formatPlayerName(match.jugador2)}</div>
            <div class="pick-cta">Marcar incompareixença →</div>
          </button>
        </div>

        <div class="modal-actions">
          <button
            type="button"
            on:click={handleClose}
            class="btn-secondary"
            disabled={saving}
          >
            Cancel·lar
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-root { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 1rem; }
  .modal-overlay { position: absolute; inset: 0; background: rgba(26, 24, 20, 0.55); }
  .modal-card {
    position: relative; z-index: 10; max-width: 28rem; width: 100%;
    background: var(--paper-elevated); border: 1px solid var(--rule);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.18);
    max-height: 90vh; overflow-y: auto;
    font-family: var(--font-sans); color: var(--ink);
  }
  .modal-card-lg { max-width: 38rem; }
  .modal-card-danger { border-top: 3px solid var(--accent); }
  .modal-head { padding: 1rem 1.5rem; border-bottom: 2px solid var(--ink); }
  .editorial-eyebrow {
    font-size: 0.6875rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.16em;
    color: var(--ink-3);
  }
  .editorial-eyebrow.danger { color: var(--accent); }
  .modal-title {
    font-weight: 800; font-size: 1.25rem;
    letter-spacing: -0.022em; margin: 0.25rem 0 0;
  }
  .modal-body {
    padding: 1.25rem 1.5rem 1.5rem;
    display: flex; flex-direction: column; gap: 1.25rem;
  }

  .info-callout {
    background: var(--paper);
    border: 1px solid var(--rule);
    border-left: 3px solid var(--amber);
    padding: 0.85rem 1rem;
  }
  .info-list {
    list-style: none; padding: 0; margin: 0;
    display: flex; flex-direction: column; gap: 0.4rem;
    font-size: 0.875rem; color: var(--ink-2); line-height: 1.5;
  }
  .info-list li {
    position: relative; padding-left: 1rem;
  }
  .info-list li::before {
    content: ''; position: absolute; left: 0; top: 0.55rem;
    width: 5px; height: 5px; background: var(--amber);
  }
  .info-list strong { color: var(--ink); font-weight: 700; }

  .player-pick-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }
  .player-pick {
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    padding: 1.25rem 1rem;
    cursor: pointer;
    text-align: left;
    font-family: var(--font-sans);
  }
  .player-pick:hover {
    border-color: var(--accent);
    background: rgba(163, 11, 30, 0.03);
  }
  .player-pick:disabled { opacity: 0.5; cursor: not-allowed; }
  .pick-eyebrow {
    font-size: 0.625rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.16em;
    color: var(--ink-3); margin-bottom: 0.4rem;
  }
  .pick-name {
    font-weight: 800; font-size: 1.0625rem;
    letter-spacing: -0.014em; color: var(--ink);
    margin-bottom: 0.65rem;
  }
  .pick-cta {
    font-size: 0.75rem; font-weight: 700;
    color: var(--accent); border-bottom: 1px solid var(--accent);
    display: inline-block; padding-bottom: 1px;
  }

  .modal-actions {
    display: flex; justify-content: flex-end; gap: 0.5rem;
    padding-top: 0.85rem; border-top: 1px solid var(--rule);
  }
  .btn-secondary {
    padding: 0.55rem 1rem; background: transparent;
    border: 1px solid var(--rule-strong); color: var(--ink);
    font-family: var(--font-sans); font-weight: 600; font-size: 0.875rem;
    cursor: pointer; min-height: 44px;
  }
  .btn-secondary:hover { border-color: var(--ink); }
  .btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }

  @media (max-width: 640px) {
    .player-pick-grid { grid-template-columns: 1fr; }
  }
</style>
