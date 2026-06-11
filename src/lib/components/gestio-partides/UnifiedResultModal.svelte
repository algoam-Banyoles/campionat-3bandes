<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { SupabaseClient } from '@supabase/supabase-js';
  import type {
    UnifiedMatch,
    ResultInput,
    SocialMeta,
    ContinuMeta,
    HandicapMeta
  } from '$lib/services/matchManagement/types';
  import { getPlayerIncompareixencesCount } from '$lib/services/calendarMutationsService';
  import HandicapMatchResult from '$lib/components/handicap/HandicapMatchResult.svelte';

  // ── Props ────────────────────────────────────────────────────────────────────

  export let match: UnifiedMatch | null = null;
  export let saving: boolean = false;
  export let supabase: SupabaseClient;

  // ── Dispatcher ───────────────────────────────────────────────────────────────

  const dispatch = createEventDispatcher<{
    save: ResultInput;
    close: void;
  }>();

  // ── Mode (social: resultat | incompareixença) ────────────────────────────────

  let mode: 'resultat' | 'incompareixenca' = 'resultat';

  // ── Social — resultat ────────────────────────────────────────────────────────

  let caramboles1: number = 0;
  let caramboles2: number = 0;
  let entrades: number = 0;
  let observacions: string = '';

  // ── Social — incompareixença ─────────────────────────────────────────────────

  let absentPlayer: 1 | 2 = 1;
  let incompCount1: number | null = null;
  let incompCount2: number | null = null;
  let loadingIncomp: boolean = false;

  // ── Continu ──────────────────────────────────────────────────────────────────

  type TipusResultat = 'normal' | 'incompareixenca_reptador' | 'incompareixenca_reptat';
  let tipusResultat: TipusResultat = 'normal';
  let dataJocLocal: string = '';
  let carR: number = 0;
  let carT: number = 0;
  let entradesC: number = 0;
  let serieR: number = 0;
  let serieT: number = 0;
  let tbR: number | '' = '';
  let tbT: number | '' = '';

  // ── Validació ────────────────────────────────────────────────────────────────

  let validationError: string = '';

  // ── Reset quan canvia la partida ─────────────────────────────────────────────

  $: if (match) {
    resetForm();
  }

  function resetForm() {
    mode = 'resultat';
    caramboles1 = 0;
    caramboles2 = 0;
    entrades = 0;
    observacions = '';
    absentPlayer = 1;
    incompCount1 = null;
    incompCount2 = null;
    tipusResultat = 'normal';
    dataJocLocal = match?.slot?.dataIso
      ? `${match.slot.dataIso}T${match.slot.hora ?? '00:00'}`
      : toLocalInput(new Date().toISOString());
    carR = 0;
    carT = 0;
    entradesC = 0;
    serieR = 0;
    serieT = 0;
    tbR = '';
    tbT = '';
    validationError = '';
  }

  // ── Helpers de data ──────────────────────────────────────────────────────────

  function toLocalInput(iso: string): string {
    const d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function parseLocalToIso(local: string): string | null {
    if (!local) return null;
    const m = local.trim().match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/);
    if (!m) {
      const dt = new Date(local);
      return isNaN(dt.getTime()) ? null : dt.toISOString();
    }
    const [, y, mo, d, h, mi] = m;
    const dt = new Date(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi));
    return isNaN(dt.getTime()) ? null : dt.toISOString();
  }

  // ── Metadades tipades ────────────────────────────────────────────────────────

  $: socialMeta = match?.source === 'social' ? (match.meta as SocialMeta) : null;
  $: continuMeta = match?.source === 'continu' ? (match.meta as ContinuMeta) : null;
  $: handicapMeta = match?.source === 'handicap' ? (match.meta as HandicapMeta) : null;

  // ── Badge de competició ──────────────────────────────────────────────────────

  $: competicioBadge = match?.source === 'social'
    ? 'Social'
    : match?.source === 'continu'
    ? 'Continu'
    : 'Hàndicap';

  // ── Data formatada ───────────────────────────────────────────────────────────

  $: dataFormated = match?.slot
    ? (() => {
        const d = new Date(match.slot!.dataIso + 'T' + match.slot!.hora);
        if (isNaN(d.getTime())) return match.slot!.dataIso;
        return d.toLocaleDateString('ca-ES', { day: '2-digit', month: 'short', year: 'numeric' }) +
          ' ' + match.slot!.hora;
      })()
    : null;

  // ── Càrrega incompareixences (lazy, en canviar a mode incompareixença) ────────

  async function loadIncompareixences() {
    if (!match || !socialMeta) return;
    loadingIncomp = true;
    try {
      const [c1, c2] = await Promise.all([
        match.player1.sociNumero !== null
          ? getPlayerIncompareixencesCount(supabase, socialMeta.eventId, match.player1.sociNumero)
          : Promise.resolve(0),
        match.player2.sociNumero !== null
          ? getPlayerIncompareixencesCount(supabase, socialMeta.eventId, match.player2.sociNumero)
          : Promise.resolve(0)
      ]);
      incompCount1 = c1;
      incompCount2 = c2;
    } catch {
      incompCount1 = null;
      incompCount2 = null;
    } finally {
      loadingIncomp = false;
    }
  }

  function onModeChange(newMode: 'resultat' | 'incompareixenca') {
    mode = newMode;
    validationError = '';
    if (newMode === 'incompareixenca' && incompCount1 === null) {
      loadIncompareixences();
    }
  }

  // ── Tie-break visible ────────────────────────────────────────────────────────

  $: allowTiebreakContinu = continuMeta?.allowTiebreak ?? false;

  $: showTiebreak = tipusResultat === 'normal' && carR === carT && allowTiebreakContinu;

  // ── Validació social resultat ────────────────────────────────────────────────

  function validateSocial(): string | null {
    if (entrades <= 0) return "Cal indicar les entrades (ha de ser > 0).";
    if (caramboles1 < 0 || caramboles2 < 0) return "Les caramboles no poden ser negatives.";
    if (socialMeta?.distanciaCaramboles != null) {
      if (caramboles1 > socialMeta.distanciaCaramboles) {
        return `Les caramboles del Jugador 1 superen la distància (${socialMeta.distanciaCaramboles}).`;
      }
      if (caramboles2 > socialMeta.distanciaCaramboles) {
        return `Les caramboles del Jugador 2 superen la distància (${socialMeta.distanciaCaramboles}).`;
      }
    }
    return null;
  }

  // ── Validació continu ─────────────────────────────────────────────────────────

  function validateContinu(): string | null {
    const parsedIso = parseLocalToIso(dataJocLocal);
    if (!parsedIso) return 'Cal indicar la data de joc.';
    if (tipusResultat !== 'normal') return null;
    if (!Number.isInteger(carR) || carR < 0) return 'Caramboles (reptador) ha de ser un enter ≥ 0.';
    if (!Number.isInteger(carT) || carT < 0) return 'Caramboles (reptat) ha de ser un enter ≥ 0.';
    if (!Number.isInteger(entradesC) || entradesC < 0) return 'Entrades ha de ser un enter ≥ 0.';
    if (!Number.isInteger(serieR) || serieR < 0) return 'Sèrie màxima (reptador) ha de ser un enter ≥ 0.';
    if (!Number.isInteger(serieT) || serieT < 0) return 'Sèrie màxima (reptat) ha de ser un enter ≥ 0.';
    if (serieR > carR) return 'Sèrie màxima (reptador) no pot superar les caramboles.';
    if (serieT > carT) return 'Sèrie màxima (reptat) no pot superar les caramboles.';
    if (continuMeta) {
      if (carR > continuMeta.carambolesObjectiu || carT > continuMeta.carambolesObjectiu) {
        return `Les caramboles no poden superar l'objectiu (${continuMeta.carambolesObjectiu}).`;
      }
      if (entradesC > continuMeta.maxEntrades) {
        return `Les entrades no poden superar el màxim (${continuMeta.maxEntrades}).`;
      }
    }
    if (carR === carT) {
      if (!allowTiebreakContinu) return 'Empat de caramboles i el tie-break està desactivat a Configuració.';
      if (tbR === '' || tbT === '') return 'Cal indicar el resultat del tie-break.';
      if (Number(tbR) < 0 || Number(tbT) < 0) return 'Els resultats del tie-break no poden ser negatius.';
      if (Number(tbR) === Number(tbT)) return 'El tie-break no pot acabar en empat.';
    }
    return null;
  }

  // ── Mapa tipus UI → endpoint ─────────────────────────────────────────────────

  function tipusToEndpoint(
    tipus: TipusResultat
  ): 'normal' | 'walkover_reptador' | 'walkover_reptat' {
    if (tipus === 'incompareixenca_reptador') return 'walkover_reptador';
    if (tipus === 'incompareixenca_reptat') return 'walkover_reptat';
    return 'normal';
  }

  // ── Submit ────────────────────────────────────────────────────────────────────

  function handleSubmitSocial() {
    if (mode === 'resultat') {
      const err = validateSocial();
      if (err) { validationError = err; return; }
      dispatch('save', {
        kind: 'social',
        caramboles_jugador1: caramboles1,
        caramboles_jugador2: caramboles2,
        entrades,
        observacions
      });
    } else {
      dispatch('save', { kind: 'social-noshow', absentPlayer });
    }
  }

  function handleSubmitContinu() {
    const err = validateContinu();
    if (err) { validationError = err; return; }
    const parsedIso = parseLocalToIso(dataJocLocal);
    if (!parsedIso) { validationError = 'Data invàlida.'; return; }
    const isTie = tipusResultat === 'normal' && carR === carT;
    dispatch('save', {
      kind: 'continu',
      data_iso: parsedIso,
      tipusResultat: tipusToEndpoint(tipusResultat),
      carR: tipusResultat === 'normal' ? carR : 0,
      carT: tipusResultat === 'normal' ? carT : 0,
      entrades: tipusResultat === 'normal' ? entradesC : 0,
      serieR: tipusResultat === 'normal' ? serieR : 0,
      serieT: tipusResultat === 'normal' ? serieT : 0,
      tbR: isTie && tbR !== '' ? Number(tbR) : null,
      tbT: isTie && tbT !== '' ? Number(tbT) : null
    });
  }

  function handleHandicapConfirm(event: CustomEvent<{
    isWalkover: boolean;
    caramboles1: number | null;
    caramboles2: number | null;
    entrades: number | null;
    winnerParticipantId: string;
    loserParticipantId: string;
  }>) {
    const detail = event.detail;
    dispatch('save', {
      kind: 'handicap',
      isWalkover: detail.isWalkover,
      caramboles1: detail.caramboles1,
      caramboles2: detail.caramboles2,
      entrades: detail.entrades,
      winnerParticipantId: detail.winnerParticipantId,
      loserParticipantId: detail.loserParticipantId
    });
  }

  function handleHandicapCancel() {
    dispatch('close');
  }

  function handleClose() {
    dispatch('close');
  }

  // ── Incompareixences: càlcul "portarà N" ─────────────────────────────────────

  $: incompNext1 = incompCount1 !== null ? incompCount1 + 1 : null;
  $: incompNext2 = incompCount2 !== null ? incompCount2 + 1 : null;
</script>

{#if match}
  <div class="modal-root" role="dialog" aria-modal="true">
    <div class="modal-overlay" on:click={handleClose} role="presentation"></div>
    <div class="modal-card">

      <!-- Capçalera comuna -->
      <div class="modal-head">
        <div>
          <div class="head-row">
            <span class="badge badge-{match.source}">{competicioBadge}</span>
            <span class="editorial-eyebrow">Introduir resultat</span>
          </div>
          <h3 class="modal-title">
            {match.player1.displayName} vs {match.player2.displayName}
          </h3>
          {#if dataFormated}
            <div class="meta-line">{dataFormated}{match.slot?.billar ? ' · Billar {match.slot.billar}' : ''}</div>
          {/if}
          {#if socialMeta}
            <div class="meta-line">{socialMeta.categoriaNom}{socialMeta.distanciaCaramboles != null ? ` · ${socialMeta.distanciaCaramboles} car.` : ''}</div>
          {/if}
          {#if continuMeta}
            <div class="meta-line">
              Reptador #{continuMeta.posReptador ?? '—'} · Reptat #{continuMeta.posReptat ?? '—'}
            </div>
          {/if}
          {#if handicapMeta}
            <div class="meta-line">
              {handicapMeta.matchCode}
              {#if handicapMeta.player1Distancia != null || handicapMeta.player2Distancia != null}
                · {handicapMeta.player1Distancia ?? '?'} / {handicapMeta.player2Distancia ?? '?'} car.
              {/if}
            </div>
          {/if}
        </div>
        <button
          type="button"
          on:click={handleClose}
          class="modal-close"
          aria-label="Tancar modal de resultat"
        >×</button>
      </div>

      <div class="modal-body">

        <!-- ── SOCIAL ─────────────────────────────────────────────────────── -->
        {#if match.source === 'social'}
          <!-- Toggle mode -->
          <div class="mode-toggle" role="group" aria-label="Mode d'entrada">
            <button
              type="button"
              class="toggle-btn {mode === 'resultat' ? 'toggle-active' : ''}"
              on:click={() => onModeChange('resultat')}
            >Resultat</button>
            <button
              type="button"
              class="toggle-btn {mode === 'incompareixenca' ? 'toggle-active' : ''}"
              on:click={() => onModeChange('incompareixenca')}
            >Incompareixença</button>
          </div>

          {#if mode === 'resultat'}
            <form on:submit|preventDefault={handleSubmitSocial}>
              <div class="form-grid form-grid-3">
                <div class="form-field">
                  <label for="ur-car1">Car. {match.player1.displayName}</label>
                  <input
                    id="ur-car1"
                    type="number"
                    min="0"
                    bind:value={caramboles1}
                    class="filter-input num-input"
                    required
                  />
                </div>
                <div class="form-field">
                  <label for="ur-car2">Car. {match.player2.displayName}</label>
                  <input
                    id="ur-car2"
                    type="number"
                    min="0"
                    bind:value={caramboles2}
                    class="filter-input num-input"
                    required
                  />
                </div>
                <div class="form-field">
                  <label for="ur-entrades">Entrades <span class="req" aria-hidden="true">*</span></label>
                  <input
                    id="ur-entrades"
                    type="number"
                    min="1"
                    bind:value={entrades}
                    class="filter-input num-input"
                    required
                  />
                </div>
              </div>

              {#if socialMeta?.distanciaCaramboles != null}
                <p class="hint">Distància: {socialMeta.distanciaCaramboles} car.</p>
              {/if}

              <div class="form-field">
                <label for="ur-obs">Observacions (opcional)</label>
                <textarea
                  id="ur-obs"
                  bind:value={observacions}
                  rows="2"
                  class="filter-input"
                  placeholder="Incidències, comentaris…"
                ></textarea>
              </div>

              {#if validationError}
                <div class="validation-error" role="alert">{validationError}</div>
              {/if}

              <div class="modal-actions">
                <button type="button" on:click={handleClose} class="btn-secondary" disabled={saving}>
                  Cancel·lar
                </button>
                <button type="submit" class="btn-primary" disabled={saving}>
                  {saving ? 'Desant…' : 'Desar resultat'}
                </button>
              </div>
            </form>

          {:else}
            <!-- Incompareixença -->
            <form on:submit|preventDefault={handleSubmitSocial}>
              <fieldset class="radio-group">
                <legend class="form-field-label">Qui no s'ha presentat?</legend>
                <label class="radio-option">
                  <input
                    type="radio"
                    name="absent"
                    value={1}
                    bind:group={absentPlayer}
                    class="radio-input"
                  />
                  <span>{match.player1.displayName}</span>
                </label>
                <label class="radio-option">
                  <input
                    type="radio"
                    name="absent"
                    value={2}
                    bind:group={absentPlayer}
                    class="radio-input"
                  />
                  <span>{match.player2.displayName}</span>
                </label>
              </fieldset>

              {#if loadingIncomp}
                <p class="hint">Carregant incompareixences…</p>
              {:else if incompCount1 !== null && incompCount2 !== null}
                {#if absentPlayer === 1}
                  <div class="incomp-warning {incompNext1 && incompNext1 >= 2 ? 'incomp-danger' : 'incomp-info'}">
                    {#if incompNext1 !== null}
                      Portarà {incompNext1} incompareixença{incompNext1 !== 1 ? 's' : ''}.
                      {#if incompNext1 >= 2}
                        <strong>Atenció: 2 incompareixences → eliminació del campionat.</strong>
                      {/if}
                    {/if}
                  </div>
                {:else}
                  <div class="incomp-warning {incompNext2 && incompNext2 >= 2 ? 'incomp-danger' : 'incomp-info'}">
                    {#if incompNext2 !== null}
                      Portarà {incompNext2} incompareixença{incompNext2 !== 1 ? 's' : ''}.
                      {#if incompNext2 >= 2}
                        <strong>Atenció: 2 incompareixences → eliminació del campionat.</strong>
                      {/if}
                    {/if}
                  </div>
                {/if}
              {/if}

              {#if validationError}
                <div class="validation-error" role="alert">{validationError}</div>
              {/if}

              <div class="modal-actions">
                <button type="button" on:click={handleClose} class="btn-secondary" disabled={saving}>
                  Cancel·lar
                </button>
                <button type="submit" class="btn-primary btn-danger" disabled={saving}>
                  {saving ? 'Desant…' : 'Registrar incompareixença'}
                </button>
              </div>
            </form>
          {/if}

        <!-- ── CONTINU ──────────────────────────────────────────────────────── -->
        {:else if match.source === 'continu'}
          <form on:submit|preventDefault={handleSubmitContinu}>
            <div class="form-field">
              <label for="ur-tipus">Tipus de resultat</label>
              <select
                id="ur-tipus"
                bind:value={tipusResultat}
                class="filter-input"
                on:change={() => { validationError = ''; }}
              >
                <option value="normal">Partida normal</option>
                <option value="incompareixenca_reptador">Incompareixença del reptador (guanya reptat)</option>
                <option value="incompareixenca_reptat">Incompareixença del reptat (guanya reptador)</option>
              </select>
            </div>

            <div class="form-field">
              <label for="ur-data">Data del joc <span class="req" aria-hidden="true">*</span></label>
              <input
                id="ur-data"
                type="datetime-local"
                step="60"
                bind:value={dataJocLocal}
                class="filter-input"
                required
              />
            </div>

            {#if tipusResultat === 'normal'}
              <div class="form-grid form-grid-2">
                <div class="form-field">
                  <label for="ur-carR">Car. {match.player1.displayName} (reptador)</label>
                  <input
                    id="ur-carR"
                    type="number"
                    min="0"
                    bind:value={carR}
                    class="filter-input num-input"
                  />
                </div>
                <div class="form-field">
                  <label for="ur-carT">Car. {match.player2.displayName} (reptat)</label>
                  <input
                    id="ur-carT"
                    type="number"
                    min="0"
                    bind:value={carT}
                    class="filter-input num-input"
                  />
                </div>
                <div class="form-field">
                  <label for="ur-entr">Entrades</label>
                  <input
                    id="ur-entr"
                    type="number"
                    min="0"
                    bind:value={entradesC}
                    class="filter-input num-input"
                  />
                </div>
              </div>

              <div class="form-grid form-grid-2">
                <div class="form-field">
                  <label for="ur-serR">Sèrie màx. reptador</label>
                  <input
                    id="ur-serR"
                    type="number"
                    min="0"
                    bind:value={serieR}
                    class="filter-input num-input"
                  />
                </div>
                <div class="form-field">
                  <label for="ur-serT">Sèrie màx. reptat</label>
                  <input
                    id="ur-serT"
                    type="number"
                    min="0"
                    bind:value={serieT}
                    class="filter-input num-input"
                  />
                </div>
              </div>

              {#if showTiebreak}
                <div class="tiebreak-section">
                  <div class="info-eyebrow">Tie-break (empat de caramboles)</div>
                  <div class="form-grid form-grid-2">
                    <div class="form-field">
                      <label for="ur-tbR">Tie-break reptador</label>
                      <input
                        id="ur-tbR"
                        type="number"
                        min="0"
                        bind:value={tbR}
                        class="filter-input num-input"
                      />
                    </div>
                    <div class="form-field">
                      <label for="ur-tbT">Tie-break reptat</label>
                      <input
                        id="ur-tbT"
                        type="number"
                        min="0"
                        bind:value={tbT}
                        class="filter-input num-input"
                      />
                    </div>
                  </div>
                </div>
              {/if}
            {/if}

            {#if validationError}
              <div class="validation-error" role="alert">{validationError}</div>
            {/if}

            <div class="modal-actions">
              <button type="button" on:click={handleClose} class="btn-secondary" disabled={saving}>
                Cancel·lar
              </button>
              <button type="submit" class="btn-primary" disabled={saving || !!validateContinu()}>
                {saving ? 'Desant…' : 'Desar resultat'}
              </button>
            </div>
          </form>

        <!-- ── HÀNDICAP ─────────────────────────────────────────────────────── -->
        {:else if match.source === 'handicap' && handicapMeta}
          <HandicapMatchResult
            player1Name={match.player1.displayName}
            player2Name={match.player2.displayName}
            player1Distancia={handicapMeta.player1Distancia}
            player2Distancia={handicapMeta.player2Distancia}
            player1ParticipantId={handicapMeta.player1ParticipantId ?? ''}
            player2ParticipantId={handicapMeta.player2ParticipantId ?? ''}
            sistemaPuntuacio={handicapMeta.sistemaPuntuacio}
            limitEntrades={handicapMeta.limitEntrades}
            {saving}
            on:confirm={handleHandicapConfirm}
            on:cancel={handleHandicapCancel}
          />
        {/if}

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
    max-width: 38rem;
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

  /* Mode toggle */
  .mode-toggle {
    display: flex;
    border: 1px solid var(--rule-strong);
  }
  .toggle-btn {
    flex: 1;
    padding: 0.5rem 0.75rem;
    background: transparent;
    border: none;
    font-family: var(--font-sans);
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink-2);
    cursor: pointer;
    min-height: 44px;
    transition: background 0.1s, color 0.1s;
  }
  .toggle-btn + .toggle-btn {
    border-left: 1px solid var(--rule-strong);
  }
  .toggle-active {
    background: var(--ink);
    color: var(--paper);
  }

  /* Formulari */
  .form-grid {
    display: grid;
    gap: 0.85rem;
  }
  .form-grid-2 { grid-template-columns: 1fr 1fr; }
  .form-grid-3 { grid-template-columns: repeat(3, 1fr); }

  .form-field {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }
  .form-field-label,
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
  textarea.filter-input {
    resize: vertical;
    min-height: 4rem;
  }
  .num-input {
    text-align: center;
    font-weight: 800;
    font-size: 1.125rem;
    font-feature-settings: 'tnum' 1, 'lnum' 1;
  }
  .req { color: var(--accent, #b03030); margin-left: 0.2rem; font-weight: 700; }
  .hint { font-size: 0.8125rem; color: var(--ink-3); margin: 0; }

  /* Radio group */
  .radio-group {
    border: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  .radio-option {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    font-size: 0.9375rem;
    font-weight: 600;
    color: var(--ink);
    cursor: pointer;
    min-height: 44px;
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--rule);
    background: var(--paper);
  }
  .radio-option:has(.radio-input:checked) {
    border-color: var(--ink);
    background: var(--paper-elevated);
  }
  .radio-input {
    width: 1.25rem;
    height: 1.25rem;
    accent-color: var(--ink);
  }

  /* Incompareixença avís */
  .incomp-warning {
    padding: 0.65rem 1rem;
    border: 1px solid;
    font-size: 0.875rem;
    line-height: 1.45;
  }
  .incomp-info {
    background: color-mix(in srgb, var(--blue, #1a56db) 8%, transparent);
    border-color: var(--blue, #1a56db);
    color: var(--ink);
  }
  .incomp-danger {
    background: color-mix(in srgb, var(--accent, #b03030) 8%, transparent);
    border-color: var(--accent, #b03030);
    color: var(--accent, #b03030);
  }

  /* Tie-break */
  .tiebreak-section {
    padding: 0.85rem 1rem;
    border: 1px solid var(--rule);
    background: var(--paper);
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .info-eyebrow {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
  }

  /* Validation error */
  .validation-error {
    padding: 0.6rem 0.85rem;
    background: color-mix(in srgb, var(--accent, #b03030) 8%, transparent);
    border: 1px solid var(--accent, #b03030);
    color: var(--accent, #b03030);
    font-size: 0.8125rem;
    font-weight: 600;
    line-height: 1.4;
  }

  /* Modal actions */
  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    margin-top: 0.5rem;
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
    background: var(--accent, #b03030);
    border-color: var(--accent, #b03030);
  }

  @media (max-width: 640px) {
    .form-grid-2 { grid-template-columns: 1fr; }
    .form-grid-3 { grid-template-columns: 1fr; }
    .modal-head { padding: 0.85rem 1rem; }
    .modal-body { padding: 1rem; }
  }
</style>
