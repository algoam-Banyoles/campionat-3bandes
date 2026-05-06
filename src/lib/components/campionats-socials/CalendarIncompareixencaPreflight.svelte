<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { PendingMatchSummary } from '$lib/services/calendarMutationsService';
  import { formatDate } from '$lib/services/calendarTimelineService';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  /**
   * Modal de confirmació previa al registre d'incompareixença.
   *
   * Mostra a l'admin l'impacte real abans de confirmar:
   *  - Nom del jugador absent
   *  - Comptador d'incompareixences (actual → futur)
   *  - Si el futur és 2: avís de desqualificació + llista de partides
   *    pendents que quedaran anul·lades
   */

  export let open = false;
  export let playerName: string = '';
  export let currentCount: number = 0;
  /** El llindar a partir del qual el jugador queda eliminat (per defecte 2). */
  export let disqualificationThreshold: number = 2;
  export let pendingMatches: PendingMatchSummary[] = [];
  export let loading: boolean = false;

  const dispatch = createEventDispatcher<{
    confirm: void;
    cancel: void;
  }>();

  $: futureCount = currentCount + 1;
  $: willDisqualify = futureCount >= disqualificationThreshold;

  function close() {
    if (loading) return;
    dispatch('cancel');
  }

  function confirmAction() {
    if (loading) return;
    dispatch('confirm');
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div
    class="modal-root"
    role="dialog"
    aria-modal="true"
    aria-labelledby="incompareixenca-preflight-title"
  >
    <button
      type="button"
      class="modal-overlay"
      aria-label="Tancar diàleg"
      on:click={close}
    ></button>

    <div class="modal-card modal-card-lg" class:modal-card-danger={willDisqualify} class:modal-card-warn={!willDisqualify}>
      <div class="modal-head">
        <div>
          <div class="editorial-eyebrow" class:danger={willDisqualify} class:warn={!willDisqualify}>
            {willDisqualify ? 'Desqualificació' : 'Incompareixença'}
          </div>
          <h3 id="incompareixenca-preflight-title" class="modal-title">
            {willDisqualify ? 'Confirmar incompareixença + desqualificació' : 'Confirmar incompareixença'}
          </h3>
        </div>
      </div>

      <div class="modal-body">
        <div class="player-info">
          <div class="info-eyebrow">Jugador absent</div>
          <div class="info-value">{formatarNomJugador(playerName)}</div>
        </div>

        <div class="counter-strip">
          <div class="counter-cell">
            <div class="counter-label">Actual</div>
            <div class="counter-num tabular-nums">{currentCount}</div>
          </div>
          <div class="counter-arrow">→</div>
          <div class="counter-cell counter-cell-future" class:counter-future-danger={willDisqualify}>
            <div class="counter-label">Després</div>
            <div class="counter-num tabular-nums">{futureCount}</div>
          </div>
        </div>

        <div class="threshold-note">
          Llindar de desqualificació: <strong>{disqualificationThreshold}</strong> incompareixences
        </div>

        {#if willDisqualify}
          <div class="callout callout-danger">
            <div class="callout-title">Aquesta acció desqualificarà el jugador</div>
            <p class="callout-text">
              <strong>{formatarNomJugador(playerName)}</strong> arribarà a {futureCount} incompareixences i quedarà <strong>eliminat del campionat</strong>.
              {#if pendingMatches.length > 0}
                Les <strong>{pendingMatches.length}</strong> partides pendents següents quedaran <strong>anul·lades</strong>:
              {:else}
                No hi ha partides pendents per anul·lar.
              {/if}
            </p>
          </div>

          {#if pendingMatches.length > 0}
            <div class="pending-block">
              <div class="pending-head">
                Partides que s'anul·laran ({pendingMatches.length})
              </div>
              <ul class="pending-list">
                {#each pendingMatches as m (m.id)}
                  <li class="pending-row">
                    <span class="pending-vs">
                      vs <span class="pending-rival">{formatarNomJugador(`${m.rivalNom ?? ''} ${m.rivalCognoms ?? ''}`.trim())}</span>
                    </span>
                    <span class="pending-meta tabular-nums">
                      {#if m.data_programada}
                        {formatDate(new Date(m.data_programada))}
                        {#if m.hora_inici} · {m.hora_inici}{/if}
                        {#if m.taula_assignada} · B{m.taula_assignada}{/if}
                      {:else}
                        Sense programar
                      {/if}
                    </span>
                  </li>
                {/each}
              </ul>
            </div>
          {/if}
        {:else}
          <div class="callout callout-warn">
            <p class="callout-text">
              <strong>{formatarNomJugador(playerName)}</strong> rebrà <strong>0 punts</strong> i <strong>50 entrades</strong> en aquesta partida.
              Després d'aquesta serà la seva incompareixença <strong>número {futureCount}</strong>.
            </p>
            {#if futureCount === disqualificationThreshold - 1}
              <p class="callout-text" style="margin-top: 0.5rem;">
                Una incompareixença més comportarà la desqualificació automàtica.
              </p>
            {/if}
          </div>
        {/if}
      </div>

      <div class="modal-actions">
        <button
          type="button"
          on:click={close}
          disabled={loading}
          class="btn-secondary"
        >
          Cancel·lar
        </button>
        <button
          type="button"
          on:click={confirmAction}
          disabled={loading}
          class="btn-primary"
          class:btn-danger={willDisqualify}
          class:btn-warn={!willDisqualify}
        >
          {#if loading}
            Aplicant…
          {:else if willDisqualify}
            Confirmar i desqualificar
          {:else}
            Confirmar incompareixença
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-root { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 1rem; }
  .modal-overlay { position: absolute; inset: 0; background: rgba(26, 24, 20, 0.55); border: none; cursor: default; }
  .modal-card {
    position: relative; z-index: 10; max-width: 28rem; width: 100%;
    background: var(--paper-elevated); border: 1px solid var(--rule);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.18);
    max-height: 90vh; overflow-y: auto;
    font-family: var(--font-sans); color: var(--ink);
    display: flex; flex-direction: column;
  }
  .modal-card-lg { max-width: 38rem; }
  .modal-card-danger { border-top: 3px solid var(--accent); }
  .modal-card-warn { border-top: 3px solid var(--amber); }
  .modal-head {
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
  }
  .editorial-eyebrow {
    font-size: 0.6875rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.16em;
    color: var(--ink-3);
  }
  .editorial-eyebrow.danger { color: var(--accent); }
  .editorial-eyebrow.warn { color: var(--amber); }
  .modal-title {
    font-weight: 800; font-size: 1.125rem;
    letter-spacing: -0.02em; margin: 0.3rem 0 0;
  }
  .modal-body {
    padding: 1.25rem 1.5rem;
    display: flex; flex-direction: column; gap: 1rem;
    flex: 1; overflow-y: auto;
  }

  .player-info {
    background: var(--paper);
    border: 1px solid var(--rule);
    padding: 0.85rem 1rem;
  }
  .info-eyebrow {
    font-size: 0.625rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.14em;
    color: var(--ink-3); margin-bottom: 0.25rem;
  }
  .info-value {
    font-weight: 800; font-size: 1.125rem;
    letter-spacing: -0.018em; color: var(--ink);
  }

  .counter-strip {
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    gap: 0.75rem;
    align-items: center;
  }
  .counter-cell {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 0.75rem;
    text-align: center;
  }
  .counter-cell-future { border: 2px solid var(--amber); }
  .counter-cell.counter-future-danger { border-color: var(--accent); }
  .counter-label {
    font-size: 0.625rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.14em;
    color: var(--ink-3); margin-bottom: 0.3rem;
  }
  .counter-num {
    font-weight: 800; font-size: 1.5rem;
    letter-spacing: -0.025em; color: var(--ink);
    line-height: 1;
  }
  .counter-future-danger .counter-num { color: var(--accent); }
  .counter-cell-future:not(.counter-future-danger) .counter-num { color: var(--amber); }
  .counter-arrow {
    font-size: 1.5rem; color: var(--ink-3); text-align: center;
  }

  .threshold-note {
    font-size: 0.75rem;
    color: var(--ink-3);
    text-align: center;
  }
  .threshold-note strong { color: var(--ink); font-weight: 700; }

  .callout {
    background: var(--paper);
    border: 1px solid var(--rule);
    padding: 0.85rem 1rem;
    border-left: 3px solid;
  }
  .callout-danger { border-left-color: var(--accent); }
  .callout-warn { border-left-color: var(--amber); }
  .callout-title {
    font-weight: 700;
    color: var(--accent);
    font-size: 0.9375rem;
    margin-bottom: 0.4rem;
    letter-spacing: -0.012em;
  }
  .callout-text {
    margin: 0;
    font-size: 0.875rem;
    color: var(--ink-2);
    line-height: 1.5;
  }
  .callout-text strong { color: var(--ink); font-weight: 700; }

  .pending-block {
    border: 1px solid var(--rule);
    overflow: hidden;
  }
  .pending-head {
    padding: 0.5rem 1rem;
    background: var(--paper);
    border-bottom: 1px solid var(--rule);
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ink-2);
  }
  .pending-list {
    list-style: none; padding: 0; margin: 0;
    max-height: 16rem; overflow-y: auto;
  }
  .pending-row {
    padding: 0.55rem 1rem;
    border-bottom: 1px solid var(--rule);
    display: flex;
    justify-content: space-between;
    gap: 0.75rem;
    font-size: 0.875rem;
    color: var(--ink);
  }
  .pending-row:last-child { border-bottom: none; }
  .pending-rival { font-weight: 700; letter-spacing: -0.012em; }
  .pending-meta {
    color: var(--ink-3);
    font-size: 0.75rem;
    white-space: nowrap;
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    padding: 1rem 1.5rem;
    border-top: 1px solid var(--rule);
  }
  .btn-secondary {
    padding: 0.55rem 1rem; background: transparent;
    border: 1px solid var(--rule-strong); color: var(--ink);
    font-family: var(--font-sans); font-weight: 600; font-size: 0.875rem;
    cursor: pointer; min-height: 44px;
  }
  .btn-secondary:hover { border-color: var(--ink); }
  .btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary {
    padding: 0.55rem 1rem;
    border: 1px solid; color: white;
    font-family: var(--font-sans); font-weight: 600; font-size: 0.875rem;
    cursor: pointer; min-height: 44px;
  }
  .btn-primary.btn-danger {
    background: var(--accent); border-color: var(--accent);
  }
  .btn-primary.btn-warn {
    background: var(--amber); border-color: var(--amber);
  }
  .btn-primary:hover { opacity: 0.92; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
