<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { formatPlayerName } from '$lib/services/calendarPlayerSearchService';
  import { toLocalDateStr } from '$lib/services/calendarTimelineService';

  export let match: any | null = null;
  export let estatOptions: Array<{ value: string; label: string; color?: string }> = [];

  const dispatch = createEventDispatcher<{
    save: {
      data_programada: string;
      hora_inici: string;
      taula_assignada: number | null;
      estat: string;
      observacions_junta: string;
    };
    cancel: void;
  }>();

  let form = createEmptyForm();
  let validationError = '';

  function createEmptyForm() {
    return {
      data_programada: '',
      hora_inici: '',
      taula_assignada: null as number | null,
      estat: 'generat',
      observacions_junta: ''
    };
  }

  // Re-inicialitza el formulari cada cop que canvia la partida.
  $: if (match) {
    form = {
      data_programada: match.data_programada
        ? toLocalDateStr(new Date(match.data_programada))
        : '',
      hora_inici: match.hora_inici || '',
      taula_assignada: match.taula_assignada,
      estat: match.estat || 'generat',
      observacions_junta: match.observacions_junta || ''
    };
    validationError = '';
  }

  // Quan l'estat passa a "pendent_programar" no cal data/hora/billar:
  // mostrem els camps com a opcionals i no els validem.
  $: isUnprogrammed = form.estat === 'pendent_programar';

  function handleSubmit() {
    validationError = '';

    if (!isUnprogrammed) {
      const missing: string[] = [];
      if (!form.data_programada) missing.push('data');
      if (!form.hora_inici) missing.push('hora');
      if (form.taula_assignada == null || Number.isNaN(form.taula_assignada)) {
        missing.push('billar');
      }
      if (missing.length > 0) {
        validationError =
          `Per programar la partida cal especificar ${missing.join(', ')}. ` +
          `Si encara no es coneix la programació, marca-la com a "Pendent programar".`;
        return;
      }
    }

    dispatch('save', { ...form });
  }

  function handleCancel() {
    dispatch('cancel');
  }
</script>

{#if match}
  <div class="modal-root" role="dialog" aria-modal="true">
    <div class="modal-overlay" on:click={handleCancel} role="presentation"></div>
    <div class="modal-card">
      <div class="modal-head">
        <div>
          <div class="editorial-eyebrow">Editar partit</div>
          <h3 class="modal-title">{formatPlayerName(match.jugador1)} vs {formatPlayerName(match.jugador2)}</h3>
        </div>
      </div>

      <form on:submit|preventDefault={handleSubmit} class="modal-body">
        <div class="form-grid form-grid-2">
          <div class="form-field">
            <label for="edit-date">
              Data
              {#if !isUnprogrammed}<span class="req" aria-hidden="true">*</span>{/if}
            </label>
            <input
              id="edit-date"
              type="date"
              bind:value={form.data_programada}
              class="filter-input"
              required={!isUnprogrammed}
              aria-required={!isUnprogrammed}
            />
          </div>
          <div class="form-field">
            <label for="edit-time">
              Hora
              {#if !isUnprogrammed}<span class="req" aria-hidden="true">*</span>{/if}
            </label>
            <input
              id="edit-time"
              type="time"
              bind:value={form.hora_inici}
              class="filter-input"
              required={!isUnprogrammed}
              aria-required={!isUnprogrammed}
            />
          </div>
          <div class="form-field">
            <label for="edit-table-input">
              Billar
              {#if !isUnprogrammed}<span class="req" aria-hidden="true">*</span>{/if}
            </label>
            <input
              id="edit-table-input"
              type="number"
              min="1"
              max="10"
              bind:value={form.taula_assignada}
              class="filter-input num-input"
              required={!isUnprogrammed}
              aria-required={!isUnprogrammed}
            />
          </div>
          <div class="form-field">
            <label for="edit-status">Estat</label>
            <select id="edit-status" bind:value={form.estat} class="filter-input">
              {#each estatOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </div>
        </div>

        {#if !isUnprogrammed}
          <p class="hint">
            <strong>*</strong> Data, hora i billar són obligatoris per programar la partida.
            Si encara no es coneixen, escull l'estat <em>"Pendent programar"</em>.
          </p>
        {:else}
          <p class="hint hint-warn">
            Estat <em>"Pendent programar"</em> seleccionat — data, hora i billar es buidaran en desar.
          </p>
        {/if}

        <div class="form-field">
          <label for="edit-observations">Observacions</label>
          <textarea
            id="edit-observations"
            bind:value={form.observacions_junta}
            rows="3"
            class="filter-input"
            placeholder="Observacions opcionals…"
          ></textarea>
        </div>

        {#if validationError}
          <div class="validation-error" role="alert">{validationError}</div>
        {/if}

        <div class="modal-actions">
          <button type="button" on:click={handleCancel} class="btn-secondary">Cancel·lar</button>
          <button type="submit" class="btn-primary">Desar</button>
        </div>
      </form>
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
  .modal-head { padding: 1rem 1.5rem; border-bottom: 2px solid var(--ink); }
  .editorial-eyebrow {
    font-size: 0.6875rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.16em;
    color: var(--ink-3);
  }
  .modal-title {
    font-weight: 800; font-size: 1.0625rem;
    letter-spacing: -0.018em; margin: 0.25rem 0 0;
  }
  .modal-body {
    padding: 1.25rem 1.5rem 1.5rem;
    display: flex; flex-direction: column; gap: 1rem;
  }
  .form-grid { display: grid; gap: 0.85rem; }
  .form-grid-2 { grid-template-columns: 1fr 1fr; }
  .form-field { display: flex; flex-direction: column; gap: 0.35rem; }
  .form-field label { font-size: 0.75rem; font-weight: 600; color: var(--ink-2); }
  .filter-input {
    width: 100%; padding: 0.55rem 0.75rem;
    background: var(--paper-elevated); border: 1px solid var(--rule-strong);
    color: var(--ink); font-family: var(--font-sans);
    font-size: 0.9375rem; font-weight: 500; min-height: 44px;
  }
  .filter-input:focus { outline: 2px solid var(--ink); outline-offset: 1px; border-color: var(--ink); }
  .num-input { text-align: center; font-weight: 800; font-feature-settings: 'tnum' 1; }
  textarea.filter-input { resize: vertical; min-height: 4rem; }
  .req { color: var(--accent, #b03030); margin-left: 0.2rem; font-weight: 700; }
  .hint {
    margin: 0;
    font-size: 0.8125rem;
    color: var(--ink-3);
    line-height: 1.5;
  }
  .hint em { font-style: normal; font-weight: 700; color: var(--ink-2); }
  .hint-warn { color: var(--amber, #b8860b); }
  .validation-error {
    padding: 0.6rem 0.85rem;
    background: rgba(176, 48, 48, 0.08);
    border: 1px solid var(--accent, #b03030);
    color: var(--accent, #b03030);
    font-size: 0.8125rem;
    font-weight: 600;
    line-height: 1.4;
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
  .btn-primary {
    padding: 0.55rem 1rem; background: var(--ink); border: 1px solid var(--ink);
    color: var(--paper); font-family: var(--font-sans); font-weight: 600;
    font-size: 0.875rem; cursor: pointer; min-height: 44px;
  }
  .btn-primary:hover { opacity: 0.92; }
  @media (max-width: 640px) {
    .form-grid-2 { grid-template-columns: 1fr; }
  }
</style>
