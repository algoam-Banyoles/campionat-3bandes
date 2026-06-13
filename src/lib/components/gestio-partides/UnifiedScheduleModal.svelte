<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { SupabaseClient } from '@supabase/supabase-js';
  import type {
    UnifiedMatch,
    UnifiedSlot,
    SocialMeta,
    ContinuMeta,
    HandicapMeta
  } from '$lib/services/matchManagement/types';
  import { findBillarConflict } from '$lib/services/calendarMutationsService';
  import { showConfirm } from '$lib/stores/confirmDialogStore';

  // ── Props ─────────────────────────────────────────────────────────────────────

  export let match: UnifiedMatch | null = null;
  export let saving: boolean = false;
  export let supabase: SupabaseClient;
  /**
   * Destí de l'enllaç "planificador complet" (només hàndicap). Si és null,
   * l'enllaç es converteix en un botó que emet `openPlanner` en lloc de
   * navegar — així la pàgina /handicap/partides pot expandir el slot-picker
   * ric en línia. Per defecte navega a /handicap/partides (comportament de
   * /admin/partides, intacte).
   */
  export let plannerHref: string | null = '/handicap/partides';

  // ── Dispatcher ────────────────────────────────────────────────────────────────

  const dispatch = createEventDispatcher<{
    save: UnifiedSlot;
    unschedule: void;
    openPlanner: void;
    close: void;
  }>();

  // ── Formulari ─────────────────────────────────────────────────────────────────

  let data: string = '';
  let hora: string = '';
  let billar: number | null = null;

  let conflictError: string = '';
  let validationError: string = '';
  let checkingConflict: boolean = false;

  // ── Reset quan canvia la partida ──────────────────────────────────────────────

  $: if (match) {
    resetForm();
  }

  function resetForm() {
    data = match?.slot?.dataIso ?? '';
    hora = match?.slot?.hora ?? '';
    billar = match?.slot?.billar ?? null;
    conflictError = '';
    validationError = '';
  }

  // ── Metadades tipades ─────────────────────────────────────────────────────────

  $: socialMeta  = match?.source === 'social'   ? (match.meta as SocialMeta)   : null;
  $: continuMeta = match?.source === 'continu'  ? (match.meta as ContinuMeta)  : null;
  $: handicapMeta = match?.source === 'handicap' ? (match.meta as HandicapMeta) : null;

  // ── Pista de disponibilitat (hàndicap) ───────────────────────────────────

  function formatPref(pref: { dies: string[]; hores: string[] } | null | undefined): string {
    if (!pref) return 'sense restriccions';
    const dies = pref.dies?.length ? pref.dies.join(', ') : null;
    const hores = pref.hores?.length ? pref.hores.join(', ') : null;
    if (!dies && !hores) return 'sense restriccions';
    const parts: string[] = [];
    if (dies) parts.push(`dies ${dies}`);
    if (hores) parts.push(`hores ${hores}`);
    return parts.join(' · ');
  }

  $: availabilityHint = (() => {
    if (match?.source !== 'handicap' || !handicapMeta) return null;
    const p1 = formatPref(handicapMeta.player1Preferencies);
    const p2 = formatPref(handicapMeta.player2Preferencies);
    return `Preferències: ${match.player1.displayName} ${p1} — ${match.player2.displayName} ${p2}`;
  })();

  // ── Billar visible (ocult per al continu) ─────────────────────────────────────

  $: showBillar = match?.source !== 'continu';

  // ── Badge de competició ───────────────────────────────────────────────────────

  $: competicioBadge = match?.source === 'social'
    ? 'Social'
    : match?.source === 'continu'
    ? 'Continu'
    : 'Hàndicap';

  // ── Data actual programada formatada ──────────────────────────────────────────

  $: slotActualText = match?.slot
    ? (() => {
        const d = new Date(match.slot!.dataIso + 'T' + match.slot!.hora);
        if (isNaN(d.getTime())) return match.slot!.dataIso + ' ' + match.slot!.hora;
        const dateStr = d.toLocaleDateString('ca-ES', { day: '2-digit', month: 'short', year: 'numeric' });
        const billarStr = match.slot!.billar != null ? ` · Billar ${match.slot!.billar}` : '';
        return `${dateStr} ${match.slot!.hora}${billarStr}`;
      })()
    : null;

  // ── Validació i submit ────────────────────────────────────────────────────────

  async function handleSubmit() {
    if (!match) return;
    conflictError = '';
    validationError = '';

    // Validació bàsica
    if (!data) { validationError = 'Cal indicar la data.'; return; }
    if (!hora) { validationError = "Cal indicar l'hora."; return; }
    if (showBillar && (billar == null || isNaN(billar))) {
      validationError = 'Cal seleccionar el billar.';
      return;
    }

    // Comprovació de conflicte de billar (social i hàndicap)
    if (showBillar && billar != null) {
      checkingConflict = true;
      try {
        // Determina l'ID a excloure (la pròpia partida de calendari_partides)
        let excludeMatchId: string | undefined;
        if (match.source === 'social') {
          excludeMatchId = match.id;
        } else if (match.source === 'handicap' && handicapMeta?.calendariPartidaId) {
          excludeMatchId = handicapMeta.calendariPartidaId;
        }

        const hasConflict = await findBillarConflict(supabase, {
          dia: data,
          hora,
          billar,
          excludeMatchId
        });

        if (hasConflict) {
          conflictError = 'Ja hi ha una partida en aquest billar a aquesta hora.';
          return;
        }
      } catch {
        conflictError = "No s'ha pogut verificar el conflicte de billar. Torna-ho a intentar.";
        return;
      } finally {
        checkingConflict = false;
      }
    }

    dispatch('save', { dataIso: data, hora, billar: showBillar ? billar : null });
  }

  async function handleUnschedule() {
    if (!match) return;
    const confirmed = await showConfirm({
      title: 'Desprogramar partida',
      message: `Estàs segur que vols treure la programació d'aquesta partida (${match.player1.displayName} vs ${match.player2.displayName})? La partida tornarà a estar pendent de programació.`,
      confirmLabel: 'Desprogramar',
      cancelLabel: 'Cancel·lar',
      severity: 'danger'
    });
    if (confirmed) {
      dispatch('unschedule');
    }
  }

  function handleClose() {
    dispatch('close');
  }

  // ── Botó Desar desactivat ─────────────────────────────────────────────────────

  $: canSave = !!data && !!hora && (!showBillar || (billar != null && !isNaN(billar)));
</script>

{#if match}
  <div class="modal-root" role="dialog" aria-modal="true">
    <div class="modal-overlay" on:click={handleClose} role="presentation"></div>
    <div class="modal-card">

      <!-- Capçalera -->
      <div class="modal-head">
        <div>
          <div class="head-row">
            <span class="badge badge-{match.source}">{competicioBadge}</span>
            <span class="editorial-eyebrow">Programar partida</span>
          </div>
          <h3 class="modal-title">
            {match.player1.displayName} vs {match.player2.displayName}
          </h3>
          {#if slotActualText}
            <div class="meta-line">Actual: {slotActualText}</div>
          {/if}
        </div>
        <button
          type="button"
          on:click={handleClose}
          class="modal-close"
          aria-label="Tancar modal de programació"
        >×</button>
      </div>

      <div class="modal-body">

        <!-- Info contextual per origen -->
        {#if continuMeta}
          <div class="info-box">
            <span class="info-eyebrow">Reprogramacions</span>
            <span class="info-value">
              {continuMeta.reprogramCount} — els administradors no tenen límit
            </span>
          </div>
        {/if}

        {#if handicapMeta}
          <div class="info-box">
            {#if plannerHref}
              <a href={plannerHref} class="info-link">
                Obrir el planificador complet →
              </a>
            {:else}
              <button type="button" class="info-link info-link-btn" on:click={() => dispatch('openPlanner')}>
                Obrir el planificador complet →
              </button>
            {/if}
          </div>
        {/if}

        {#if availabilityHint}
          <div class="avail-hint">{availabilityHint}</div>
        {/if}

        <form on:submit|preventDefault={handleSubmit}>
          <div class="form-grid form-grid-2">
            <!-- Data -->
            <div class="form-field">
              <label for="us-data">Data <span class="req" aria-hidden="true">*</span></label>
              <input
                id="us-data"
                type="date"
                bind:value={data}
                class="filter-input"
                required
                on:change={() => { conflictError = ''; validationError = ''; }}
              />
            </div>

            <!-- Hora -->
            <div class="form-field">
              <label for="us-hora">Hora <span class="req" aria-hidden="true">*</span></label>
              <input
                id="us-hora"
                type="time"
                step="900"
                bind:value={hora}
                class="filter-input"
                required
                on:change={() => { conflictError = ''; validationError = ''; }}
              />
            </div>

            <!-- Billar (ocult per al continu) -->
            {#if showBillar}
              <div class="form-field">
                <label for="us-billar">Billar <span class="req" aria-hidden="true">*</span></label>
                <select
                  id="us-billar"
                  bind:value={billar}
                  class="filter-input"
                  required
                  on:change={() => { conflictError = ''; validationError = ''; }}
                >
                  <option value={null} disabled>Selecciona…</option>
                  <option value={1}>Billar 1</option>
                  <option value={2}>Billar 2</option>
                  <option value={3}>Billar 3</option>
                </select>
              </div>
            {/if}
          </div>

          {#if validationError}
            <div class="validation-error" role="alert">{validationError}</div>
          {/if}

          {#if conflictError}
            <div class="validation-error" role="alert">{conflictError}</div>
          {/if}

          <!-- Accions -->
          <div class="modal-actions">
            {#if match.capabilities.canUnschedule}
              <button
                type="button"
                on:click={handleUnschedule}
                class="btn-danger"
                disabled={saving || checkingConflict}
              >
                Desprogramar
              </button>
            {/if}
            <div class="actions-right">
              <button
                type="button"
                on:click={handleClose}
                class="btn-secondary"
                disabled={saving || checkingConflict}
              >
                Cancel·lar
              </button>
              <button
                type="submit"
                class="btn-primary"
                disabled={saving || checkingConflict || !canSave}
              >
                {#if checkingConflict}
                  Verificant…
                {:else if saving}
                  Desant…
                {:else}
                  Desar
                {/if}
              </button>
            </div>
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
    max-width: 32rem;
    width: 100%;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.18);
    max-height: 90vh;
    overflow-y: auto;
    font-family: var(--font-sans);
    color: var(--ink);
  }
  .modal-head {
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
  }
  .head-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.35rem;
  }
  .badge {
    display: inline-block;
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    padding: 0.15rem 0.5rem;
    border: 1px solid currentColor;
  }
  .badge-social  { color: var(--blue, #1a56db); }
  .badge-continu { color: var(--green, #1a6b2e); }
  .badge-handicap { color: var(--sec-handicap, #6b21a8); }

  .editorial-eyebrow {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
  }
  .modal-title {
    font-weight: 800;
    font-size: 1.125rem;
    letter-spacing: -0.02em;
    margin: 0.15rem 0 0;
    line-height: 1.25;
  }
  .meta-line {
    font-size: 0.8125rem;
    color: var(--ink-3);
    margin-top: 0.2rem;
  }
  .modal-close {
    background: transparent;
    border: none;
    color: var(--ink-3);
    font-size: 1.5rem;
    width: 2.5rem;
    height: 2.5rem;
    min-height: 48px;
    min-width: 48px;
    cursor: pointer;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .modal-close:hover { color: var(--ink); }

  .modal-body {
    padding: 1.25rem 1.5rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  /* Info box (continu/handicap extras) */
  .info-box {
    padding: 0.65rem 0.85rem;
    background: var(--paper);
    border: 1px solid var(--rule);
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }
  .info-eyebrow {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
  }
  .info-value {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink);
  }
  .info-link {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink);
    text-decoration: underline;
  }
  .info-link:hover { opacity: 0.75; }
  .info-link-btn {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: var(--font-sans);
    text-align: left;
  }

  /* Pista de disponibilitat (hàndicap) */
  .avail-hint {
    font-size: 0.8125rem;
    color: var(--ink-3);
    line-height: 1.45;
  }

  /* Formulari */
  .form-grid {
    display: grid;
    gap: 0.85rem;
  }
  .form-grid-2 { grid-template-columns: 1fr 1fr; }
  .form-field {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }
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
  .req { color: var(--accent, #b03030); margin-left: 0.2rem; font-weight: 700; }

  /* Errors */
  .validation-error {
    padding: 0.6rem 0.85rem;
    background: color-mix(in srgb, var(--accent, #b03030) 8%, transparent);
    border: 1px solid var(--accent, #b03030);
    color: var(--accent, #b03030);
    font-size: 0.8125rem;
    font-weight: 600;
    line-height: 1.4;
  }

  /* Accions */
  .modal-actions {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-top: 0.5rem;
    padding-top: 0.85rem;
    border-top: 1px solid var(--rule);
  }
  .actions-right {
    display: flex;
    gap: 0.5rem;
    margin-left: auto;
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
    padding: 0.55rem 1.25rem;
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
  .btn-danger {
    padding: 0.55rem 1rem;
    background: transparent;
    border: 1px solid var(--accent, #b03030);
    color: var(--accent, #b03030);
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 44px;
  }
  .btn-danger:hover {
    background: color-mix(in srgb, var(--accent, #b03030) 8%, transparent);
  }
  .btn-danger:disabled { opacity: 0.5; cursor: not-allowed; }

  @media (max-width: 640px) {
    .form-grid-2 { grid-template-columns: 1fr; }
    .modal-head { padding: 0.85rem 1rem; }
    .modal-body { padding: 1rem; }
    .modal-actions { flex-wrap: wrap; }
    .actions-right { width: 100%; justify-content: flex-end; }
  }
</style>
