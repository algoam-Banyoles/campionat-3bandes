<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';
  import { formatDate } from '$lib/services/calendarTimelineService';

  export let match: any | null = null;
  export let categoryName: string = '';
  export let saving: boolean = false;

  const dispatch = createEventDispatcher<{
    save: {
      caramboles_jugador1: number;
      caramboles_jugador2: number;
      entrades: number;
      observacions: string;
    };
    close: void;
  }>();

  let form = {
    caramboles_jugador1: 0,
    caramboles_jugador2: 0,
    entrades: 0,
    observacions: ''
  };

  // Reset cada cop que es mostra una nova partida.
  $: if (match) {
    form = {
      caramboles_jugador1: match.caramboles_jugador1 ?? 0,
      caramboles_jugador2: match.caramboles_jugador2 ?? 0,
      entrades: match.entrades ?? 0,
      observacions: match.observacions ?? ''
    };
  }

  function handleSubmit() {
    dispatch('save', { ...form });
  }

  function handleClose() {
    dispatch('close');
  }
</script>

{#if match}
  <div class="modal-root" role="dialog" aria-modal="true">
    <div class="modal-overlay" on:click={handleClose} role="presentation"></div>
    <div class="modal-card modal-card-lg">
      <div class="modal-head">
        <div>
          <div class="editorial-eyebrow">Introduir resultat</div>
          <h3 class="modal-title">Partida</h3>
        </div>
        <button
          type="button"
          on:click={handleClose}
          class="modal-close"
          aria-label="Tancar modal de resultat"
        >×</button>
      </div>

      <div class="modal-body">
        <!-- Info partida -->
        <div class="match-info-grid">
          <div>
            <div class="info-eyebrow">Jugador 1</div>
            <div class="info-value">{formatPlayerName(match.jugador1)}</div>
          </div>
          <div>
            <div class="info-eyebrow">Jugador 2</div>
            <div class="info-value">{formatPlayerName(match.jugador2)}</div>
          </div>
          <div>
            <div class="info-eyebrow">Data</div>
            <div class="info-value tabular-nums">
              {match.data_programada ? formatDate(new Date(match.data_programada)) : '—'}
              {#if match.hora_inici}· {match.hora_inici}{/if}
            </div>
          </div>
          <div>
            <div class="info-eyebrow">Categoria</div>
            <div class="info-value">{match.categoria_nom || categoryName || '—'}</div>
          </div>
        </div>

        <form on:submit|preventDefault={handleSubmit}>
          <div class="form-grid form-grid-3">
            <div class="form-field">
              <label for="result-car1">Caramboles {formatPlayerName(match.jugador1)}</label>
              <input
                id="result-car1"
                type="number"
                min="0"
                bind:value={form.caramboles_jugador1}
                class="filter-input num-input"
                required
              />
            </div>
            <div class="form-field">
              <label for="result-car2">Caramboles {formatPlayerName(match.jugador2)}</label>
              <input
                id="result-car2"
                type="number"
                min="0"
                bind:value={form.caramboles_jugador2}
                class="filter-input num-input"
                required
              />
            </div>
            <div class="form-field">
              <label for="result-entrades">Entrades</label>
              <input
                id="result-entrades"
                type="number"
                min="0"
                bind:value={form.entrades}
                class="filter-input num-input"
                required
              />
            </div>
          </div>

          <!-- Guanyador calculat -->
          <div class="winner-banner">
            <div class="info-eyebrow">Guanyador</div>
            <div class="winner-text">
              {#if form.caramboles_jugador1 > form.caramboles_jugador2}
                <strong>{formatPlayerName(match.jugador1)}</strong>
              {:else if form.caramboles_jugador2 > form.caramboles_jugador1}
                <strong>{formatPlayerName(match.jugador2)}</strong>
              {:else}
                <span class="muted">Empat — introdueix caramboles diferents</span>
              {/if}
            </div>
          </div>

          <div class="form-field">
            <label for="result-obs">Observacions (opcional)</label>
            <textarea
              id="result-obs"
              bind:value={form.observacions}
              rows="3"
              class="filter-input"
              placeholder="Incidències, comentaris…"
            ></textarea>
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
            <button
              type="submit"
              class="btn-primary btn-success"
              disabled={saving}
            >
              {saving ? 'Guardant…' : 'Guardar resultat'}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-root {
    position: fixed;
    inset: 0;
    z-index: 50;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
  }
  .modal-overlay {
    position: absolute;
    inset: 0;
    background: rgba(26, 24, 20, 0.55);
  }
  .modal-card {
    position: relative;
    z-index: 10;
    max-width: 28rem;
    width: 100%;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.18);
    max-height: 90vh;
    overflow-y: auto;
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .modal-card-lg { max-width: 38rem; }
  .modal-head {
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
  }
  .editorial-eyebrow {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
  }
  .modal-title {
    font-weight: 800;
    font-size: 1.25rem;
    letter-spacing: -0.022em;
    margin: 0.25rem 0 0;
  }
  .modal-close {
    background: transparent;
    border: none;
    color: var(--ink-3);
    font-size: 1.5rem;
    width: 2rem;
    height: 2rem;
    cursor: pointer;
  }
  .modal-close:hover { color: var(--ink); }
  .modal-body {
    padding: 1.25rem 1.5rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .match-info-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.85rem 1.25rem;
    background: var(--paper);
    border: 1px solid var(--rule);
    padding: 0.85rem 1rem;
  }
  .info-eyebrow {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    margin-bottom: 0.25rem;
  }
  .info-value {
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.012em;
    font-size: 0.9375rem;
  }

  .form-grid {
    display: grid;
    gap: 0.85rem;
  }
  .form-grid-3 { grid-template-columns: repeat(3, 1fr); }
  .form-field { display: flex; flex-direction: column; gap: 0.35rem; }
  .form-field label {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ink-2);
  }
  .filter-input {
    width: 100%;
    padding: 0.55rem 0.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    font-family: var(--font-sans);
    font-size: 0.9375rem;
    font-weight: 500;
    min-height: 44px;
  }
  .filter-input:focus {
    outline: 2px solid var(--ink);
    outline-offset: 1px;
    border-color: var(--ink);
  }
  .num-input {
    text-align: center;
    font-weight: 800;
    font-size: 1.125rem;
    font-feature-settings: 'tnum' 1, 'lnum' 1;
  }
  textarea.filter-input {
    resize: vertical;
    min-height: 4.5rem;
  }

  .winner-banner {
    background: var(--paper);
    border: 1px solid var(--rule);
    border-left: 3px solid var(--green);
    padding: 0.75rem 1rem;
    margin-top: 0.85rem;
  }
  .winner-text {
    margin-top: 0.25rem;
    font-size: 1rem;
    color: var(--ink);
  }
  .winner-text strong {
    font-weight: 800;
    color: var(--green);
    letter-spacing: -0.014em;
  }
  .winner-text .muted { color: var(--ink-3); }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    margin-top: 1rem;
    padding-top: 0.85rem;
    border-top: 1px solid var(--rule);
  }
  .btn-secondary {
    padding: 0.55rem 1rem;
    background: transparent;
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .btn-secondary:hover { border-color: var(--ink); }
  .btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary {
    padding: 0.55rem 1rem;
    background: var(--ink);
    border: 1px solid var(--ink);
    color: var(--paper);
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .btn-primary:hover { opacity: 0.92; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary.btn-success {
    background: var(--green);
    border-color: var(--green);
  }

  @media (max-width: 640px) {
    .form-grid-3 { grid-template-columns: 1fr; }
    .match-info-grid { grid-template-columns: 1fr; }
    .modal-head { padding: 0.85rem 1rem; }
    .modal-body { padding: 1rem; }
  }
</style>
