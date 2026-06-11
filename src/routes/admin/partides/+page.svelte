<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { effectiveIsAdmin } from '$lib/stores/viewMode';
  import { adminChecked } from '$lib/stores/adminAuth';
  import { user } from '$lib/stores/auth';
  import { goto } from '$app/navigation';
  import Banner from '$lib/components/general/Banner.svelte';
  import UnifiedResultModal from '$lib/components/gestio-partides/UnifiedResultModal.svelte';
  import UnifiedScheduleModal from '$lib/components/gestio-partides/UnifiedScheduleModal.svelte';
  import { showSuccess, showError } from '$lib/stores/toastStore';
  import {
    loadAllMatches,
    adapters
  } from '$lib/services/matchManagement';
  import type {
    UnifiedMatch,
    MatchSource,
    AdapterError,
    ResultInput,
    UnifiedSlot,
    SocialMeta,
    ContinuMeta,
    HandicapMeta
  } from '$lib/services/matchManagement';

  // ── Guard ─────────────────────────────────────────────────────────────────

  $: if ($adminChecked && !$effectiveIsAdmin) {
    goto('/');
  }

  // ── Estat de càrrega ──────────────────────────────────────────────────────

  let loading = true;
  let allMatches: UnifiedMatch[] = [];
  let sourceErrors: AdapterError[] = [];

  // ── Filtres ───────────────────────────────────────────────────────────────

  type SourceFilter = 'totes' | MatchSource;
  type StatFilter = 'pendents' | 'programades' | 'jugades';

  let sourceFilter: SourceFilter = 'totes';
  let statFilter: StatFilter = 'pendents';
  let searchText = '';
  let includeJugades = false;

  // ── Modals ────────────────────────────────────────────────────────────────

  let selectedMatch: UnifiedMatch | null = null;
  let resultModalOpen = false;
  let scheduleModalOpen = false;
  let saving = false;

  // ── Càrrega inicial ───────────────────────────────────────────────────────

  onMount(async () => {
    await loadMatches();
  });

  async function loadMatches(sourceOnly?: MatchSource) {
    loading = true;
    try {
      if (sourceOnly) {
        // Recàrrega parcial: recarrega només una font i fusiona
        const adapter = adapters[sourceOnly];
        let freshMatches: UnifiedMatch[] = [];
        try {
          freshMatches = await adapter.listMatches(supabase, includeJugades);
          // Elimina l'error anterior d'aquesta font si n'hi havia
          sourceErrors = sourceErrors.filter((e) => e.source !== sourceOnly);
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          sourceErrors = [
            ...sourceErrors.filter((e) => e.source !== sourceOnly),
            { source: sourceOnly, message: msg }
          ];
        }
        allMatches = [
          ...allMatches.filter((m) => m.source !== sourceOnly),
          ...freshMatches
        ];
      } else {
        const result = await loadAllMatches(supabase, { includeJugades });
        allMatches = result.matches;
        sourceErrors = result.errors;
      }
    } finally {
      loading = false;
    }
  }

  // ── Gestió jugades (tab) ──────────────────────────────────────────────────

  async function onStatTabChange(tab: StatFilter) {
    statFilter = tab;
    const needsJugades = tab === 'jugades';
    if (needsJugades !== includeJugades) {
      includeJugades = needsJugades;
      await loadMatches();
    }
  }

  // ── Cerca accent-insensitive ──────────────────────────────────────────────

  function normalize(s: string): string {
    return s
      .toLowerCase()
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '');
  }

  // ── Partides filtrades i ordenades ────────────────────────────────────────

  $: filteredMatches = (() => {
    let list = allMatches;

    // Filtre per font
    if (sourceFilter !== 'totes') {
      list = list.filter((m) => m.source === sourceFilter);
    }

    // Filtre per estat (tab)
    if (statFilter === 'pendents') {
      list = list.filter((m) => m.status === 'pendent');
    } else if (statFilter === 'programades') {
      list = list.filter((m) => m.status === 'programada');
    } else {
      list = list.filter((m) => m.status === 'jugada' || m.status === 'altres');
    }

    // Filtre per text (cerca accent-insensitive en rawName)
    if (searchText.trim()) {
      const q = normalize(searchText.trim());
      list = list.filter(
        (m) =>
          normalize(m.player1.rawName).includes(q) ||
          normalize(m.player2.rawName).includes(q)
      );
    }

    // Ordenació: pendents primer per eventNom, programades per data, jugades per data desc
    list = [...list].sort((a, b) => {
      if (a.status === 'pendent' && b.status === 'pendent') {
        const aNom = getEventNom(a);
        const bNom = getEventNom(b);
        return aNom.localeCompare(bNom, 'ca');
      }
      if (a.status === 'programada' && b.status === 'programada') {
        const aDate = a.slot ? a.slot.dataIso + 'T' + a.slot.hora : '';
        const bDate = b.slot ? b.slot.dataIso + 'T' + b.slot.hora : '';
        return aDate.localeCompare(bDate);
      }
      // jugades: desc
      const aDate = a.slot ? a.slot.dataIso + 'T' + a.slot.hora : '';
      const bDate = b.slot ? b.slot.dataIso + 'T' + b.slot.hora : '';
      return bDate.localeCompare(aDate);
    });

    return list;
  })();

  // ── Helpers de visualització ──────────────────────────────────────────────

  function getEventNom(m: UnifiedMatch): string {
    const meta = m.meta as SocialMeta | ContinuMeta | HandicapMeta;
    if ('eventNom' in meta) return meta.eventNom;
    return 'Continu';
  }

  function getContextLine(m: UnifiedMatch): string {
    const meta = m.meta as SocialMeta | ContinuMeta | HandicapMeta;
    if (meta.source === 'social') {
      const sm = meta as SocialMeta;
      return sm.categoriaNom + (sm.distanciaCaramboles != null ? ` · ${sm.distanciaCaramboles} car.` : '');
    }
    if (meta.source === 'continu') {
      const cm = meta as ContinuMeta;
      const r = cm.posReptador != null ? `#${cm.posReptador}` : '—';
      const t = cm.posReptat != null ? `#${cm.posReptat}` : '—';
      return `Posicions ${r} vs ${t}`;
    }
    if (meta.source === 'handicap') {
      const hm = meta as HandicapMeta;
      return hm.matchCode;
    }
    return '';
  }

  function formatSlot(m: UnifiedMatch): { data: string; hora: string; billar: string } {
    if (!m.slot) return { data: '—', hora: '—', billar: '—' };
    const d = new Date(m.slot.dataIso + 'T' + m.slot.hora);
    const data = isNaN(d.getTime())
      ? m.slot.dataIso
      : d.toLocaleDateString('ca-ES', { day: '2-digit', month: 'short' });
    return {
      data,
      hora: m.slot.hora,
      billar: m.slot.billar != null ? `B${m.slot.billar}` : '—'
    };
  }

  const ESTAT_LABELS: Record<string, string> = {
    pendent: 'Pendent',
    pendent_programar: 'Pendent de programar',
    programada: 'Programada',
    jugada: 'Jugada',
    proposat: 'Proposat',
    acceptat: 'Acceptat',
    programat: 'Programat',
    jugat: 'Jugat',
    walkover: 'Walkover',
    incompareixenca: 'Incompareixença',
    cancelled: 'Cancel·lada',
    canceled: 'Cancel·lada'
  };

  function translateEstat(rawEstat: string): string {
    return ESTAT_LABELS[rawEstat] ?? rawEstat;
  }

  // ── Accions (modals) ──────────────────────────────────────────────────────

  function openResultModal(m: UnifiedMatch) {
    selectedMatch = m;
    resultModalOpen = true;
    scheduleModalOpen = false;
  }

  function openScheduleModal(m: UnifiedMatch) {
    selectedMatch = m;
    scheduleModalOpen = true;
    resultModalOpen = false;
  }

  function closeModals() {
    selectedMatch = null;
    resultModalOpen = false;
    scheduleModalOpen = false;
  }

  async function handleResultSave(event: CustomEvent<ResultInput>) {
    if (!selectedMatch) return;
    const match = selectedMatch;
    saving = true;
    try {
      const resp = await adapters[match.source].enterResult(supabase, match, event.detail);
      showSuccess(resp?.message ?? 'Resultat desat correctament.');
      closeModals();
      await loadMatches(match.source);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Error desant el resultat.';
      showError(msg);
      await loadMatches(match.source);
    } finally {
      saving = false;
    }
  }

  async function handleScheduleSave(event: CustomEvent<UnifiedSlot>) {
    if (!selectedMatch) return;
    const match = selectedMatch;
    const adapter = adapters[match.source];
    if (!adapter.schedule) return;
    saving = true;
    try {
      await adapter.schedule(supabase, match, event.detail);
      showSuccess('Partida programada correctament.');
      closeModals();
      await loadMatches(match.source);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Error programant la partida.';
      showError(msg);
      await loadMatches(match.source);
    } finally {
      saving = false;
    }
  }

  async function handleUnschedule() {
    if (!selectedMatch) return;
    const match = selectedMatch;
    const adapter = adapters[match.source];
    if (!adapter.unschedule) return;
    saving = true;
    try {
      await adapter.unschedule(supabase, match);
      showSuccess('Partida desprogramada correctament.');
      closeModals();
      await loadMatches(match.source);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Error desprogramant la partida.';
      showError(msg);
      await loadMatches(match.source);
    } finally {
      saving = false;
    }
  }

  // Helpers de recompte
  $: countPendents = allMatches.filter((m) => m.status === 'pendent').length;
  $: countProgramades = allMatches.filter((m) => m.status === 'programada').length;
  $: countJugades = allMatches.filter((m) => m.status === 'jugada' || m.status === 'altres').length;
</script>

<svelte:head>
  <title>Gestió de partides — Administració</title>
</svelte:head>

<div class="gp-root">

  <!-- ── Capçalera ─────────────────────────────────────────────────────── -->
  <header class="gp-mast">
    <a href="/admin" class="gp-back">← Tornar a l'administració</a>
    <div class="editorial-eyebrow">Administració</div>
    <h1 class="gp-title">Gestió de partides</h1>
    <p class="gp-sub">
      Resultats i programació de totes les competicions actives: socials, continu i hàndicap.
    </p>
  </header>

  <!-- ── Errors per origen ─────────────────────────────────────────────── -->
  {#if sourceErrors.length > 0}
    <div class="gp-errors">
      {#each sourceErrors as err}
        <Banner
          type="error"
          message={`No s'han pogut carregar les partides de ${err.source === 'social' ? 'socials' : err.source === 'continu' ? 'continu' : 'hàndicap'}: ${err.message}`}
        />
      {/each}
    </div>
  {/if}

  {#if $adminChecked && $effectiveIsAdmin}

    <!-- ── Filtres ────────────────────────────────────────────────────────── -->
    <div class="gp-filters">

      <!-- Chips de competició -->
      <div class="filter-row" role="group" aria-label="Filtrar per competició">
        {#each ([
          { value: 'totes', label: 'Totes' },
          { value: 'social', label: 'Socials' },
          { value: 'continu', label: 'Continu' },
          { value: 'handicap', label: 'Hàndicap' }
        ] as const) as chip}
          <button
            type="button"
            class="chip chip-{chip.value} {sourceFilter === chip.value ? 'chip-active' : ''}"
            on:click={() => { sourceFilter = chip.value; }}
          >
            {chip.label}
          </button>
        {/each}
      </div>

      <!-- Tabs d'estat -->
      <div class="filter-row" role="tablist" aria-label="Filtrar per estat">
        <button
          type="button"
          role="tab"
          aria-selected={statFilter === 'pendents'}
          class="tab {statFilter === 'pendents' ? 'tab-active' : ''}"
          on:click={() => onStatTabChange('pendents')}
        >
          Pendents
          {#if countPendents > 0}
            <span class="tab-count">{countPendents}</span>
          {/if}
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={statFilter === 'programades'}
          class="tab {statFilter === 'programades' ? 'tab-active' : ''}"
          on:click={() => onStatTabChange('programades')}
        >
          Programades
          {#if countProgramades > 0}
            <span class="tab-count">{countProgramades}</span>
          {/if}
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={statFilter === 'jugades'}
          class="tab {statFilter === 'jugades' ? 'tab-active' : ''}"
          on:click={() => onStatTabChange('jugades')}
        >
          Jugades
          {#if countJugades > 0}
            <span class="tab-count">{countJugades}</span>
          {/if}
        </button>
      </div>

      <!-- Cerca per nom -->
      <div class="search-wrap">
        <input
          type="search"
          class="search-input"
          placeholder="Cercar per nom de jugador…"
          bind:value={searchText}
          aria-label="Cercar partides per nom de jugador"
        />
      </div>
    </div>

    <!-- ── Contingut principal ────────────────────────────────────────────── -->
    {#if loading}
      <div class="gp-loading" aria-busy="true">
        <div class="loader-ring" aria-hidden="true"></div>
        <span>Carregant partides…</span>
      </div>

    {:else if filteredMatches.length === 0}
      <div class="gp-empty">
        <div class="empty-icon" aria-hidden="true">—</div>
        <p class="empty-msg">
          {#if searchText.trim()}
            Cap partida coincideix amb la cerca «{searchText.trim()}».
          {:else}
            No hi ha partides en aquest estat.
          {/if}
        </p>
        {#if searchText.trim()}
          <button type="button" class="btn-link" on:click={() => { searchText = ''; }}>
            Esborrar cerca
          </button>
        {/if}
      </div>

    {:else}

      <!-- Desktop: taula -->
      <div class="gp-table-wrap">
        <table class="gp-table" aria-label="Llista de partides">
          <thead>
            <tr>
              <th class="col-comp">Competició</th>
              <th class="col-partida">Partida</th>
              <th class="col-slot">Data · Hora · Billar</th>
              <th class="col-estat">Estat</th>
              <th class="col-accions">Accions</th>
            </tr>
          </thead>
          <tbody>
            {#each filteredMatches as m (m.source + '-' + m.id)}
              {@const slot = formatSlot(m)}
              {@const context = getContextLine(m)}
              {@const eventNom = getEventNom(m)}
              <tr class="gp-row">
                <td class="col-comp">
                  <div class="source-badge source-badge-{m.source}">
                    {m.source === 'social' ? 'Social' : m.source === 'continu' ? 'Continu' : 'Hàndicap'}
                  </div>
                  <div class="event-nom">{eventNom}</div>
                </td>
                <td class="col-partida">
                  <div class="player-vs">
                    <span class="player-name">{m.player1.displayName}</span>
                    <span class="vs-sep">vs</span>
                    <span class="player-name">{m.player2.displayName}</span>
                  </div>
                  {#if context}
                    <div class="context-line">{context}</div>
                  {/if}
                </td>
                <td class="col-slot">
                  <div class="slot-grid">
                    <span class="slot-val">{slot.data}</span>
                    <span class="slot-sep">·</span>
                    <span class="slot-val">{slot.hora}</span>
                    <span class="slot-sep">·</span>
                    <span class="slot-val">{slot.billar}</span>
                  </div>
                </td>
                <td class="col-estat">
                  <span class="estat-chip estat-chip-{m.status}">
                    {translateEstat(m.rawEstat)}
                  </span>
                </td>
                <td class="col-accions">
                  <div class="actions-row">
                    {#if m.capabilities.canEnterResult}
                      <button
                        type="button"
                        class="action-btn action-btn-primary"
                        disabled={saving}
                        on:click={() => openResultModal(m)}
                        aria-label="Introduir resultat de {m.player1.displayName} vs {m.player2.displayName}"
                      >
                        Resultat
                      </button>
                    {/if}
                    {#if m.capabilities.canSchedule}
                      <button
                        type="button"
                        class="action-btn action-btn-secondary"
                        disabled={saving}
                        on:click={() => openScheduleModal(m)}
                        aria-label="{m.slot ? 'Reprogramar' : 'Programar'} {m.player1.displayName} vs {m.player2.displayName}"
                      >
                        {m.slot ? 'Reprogramar' : 'Programar'}
                      </button>
                    {/if}
                  </div>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- Mobile: cards -->
      <div class="gp-cards">
        {#each filteredMatches as m (m.source + '-' + m.id)}
          {@const slot = formatSlot(m)}
          {@const context = getContextLine(m)}
          {@const eventNom = getEventNom(m)}
          <article class="gp-card">
            <div class="card-head">
              <span class="source-badge source-badge-{m.source}">
                {m.source === 'social' ? 'Social' : m.source === 'continu' ? 'Continu' : 'Hàndicap'}
              </span>
              <span class="estat-chip estat-chip-{m.status}">
                {translateEstat(m.rawEstat)}
              </span>
            </div>
            <div class="card-event">{eventNom}</div>
            <div class="card-players">
              <span class="player-name">{m.player1.displayName}</span>
              <span class="vs-sep">vs</span>
              <span class="player-name">{m.player2.displayName}</span>
            </div>
            {#if context}
              <div class="context-line">{context}</div>
            {/if}
            <div class="card-slot">
              {slot.data !== '—' ? `${slot.data} · ${slot.hora}` : 'Sense data'}{slot.billar !== '—' ? ` · ${slot.billar}` : ''}
            </div>
            <div class="card-actions">
              {#if m.capabilities.canEnterResult}
                <button
                  type="button"
                  class="action-btn action-btn-primary"
                  disabled={saving}
                  on:click={() => openResultModal(m)}
                >
                  Resultat
                </button>
              {/if}
              {#if m.capabilities.canSchedule}
                <button
                  type="button"
                  class="action-btn action-btn-secondary"
                  disabled={saving}
                  on:click={() => openScheduleModal(m)}
                >
                  {m.slot ? 'Reprogramar' : 'Programar'}
                </button>
              {/if}
            </div>
          </article>
        {/each}
      </div>

    {/if}

  {/if}
</div>

<!-- ── Modals ──────────────────────────────────────────────────────────── -->
{#if resultModalOpen && selectedMatch}
  <UnifiedResultModal
    match={selectedMatch}
    {saving}
    {supabase}
    on:save={handleResultSave}
    on:close={closeModals}
  />
{/if}

{#if scheduleModalOpen && selectedMatch}
  <UnifiedScheduleModal
    match={selectedMatch}
    {saving}
    {supabase}
    on:save={handleScheduleSave}
    on:unschedule={handleUnschedule}
    on:close={closeModals}
  />
{/if}

<style>
  .gp-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }

  /* ── Capçalera ─────────────────────────────────── */
  .gp-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .gp-back {
    display: inline-block;
    color: var(--ink-2, #4a443e);
    text-decoration: none;
    font-size: 0.875rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
  }
  .gp-back:hover { color: var(--ink, #1a1814); }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .gp-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .gp-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 60ch;
  }

  /* ── Errors ────────────────────────────────────── */
  .gp-errors {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-bottom: 1rem;
  }

  /* ── Filtres ───────────────────────────────────── */
  .gp-filters {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    margin-bottom: 1.25rem;
  }
  .filter-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
  }

  /* Chips competició */
  .chip {
    padding: 0.35rem 0.85rem;
    border: 1px solid var(--rule-strong, #b8b3a8);
    background: var(--paper-elevated, #fff);
    font-family: var(--font-sans, sans-serif);
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--ink-2, #4a443e);
    cursor: pointer;
    min-height: 36px;
    transition: border-color 0.1s, background 0.1s, color 0.1s;
  }
  .chip:hover { border-color: var(--ink, #1a1814); color: var(--ink, #1a1814); }
  .chip-active {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
    border-color: var(--ink, #1a1814);
  }
  .chip-social.chip-active { background: var(--blue, #1a56db); border-color: var(--blue, #1a56db); }
  .chip-continu.chip-active { background: var(--green, #1a6b2e); border-color: var(--green, #1a6b2e); }
  .chip-handicap.chip-active { background: var(--sec-handicap, #6b21a8); border-color: var(--sec-handicap, #6b21a8); }

  /* Tabs estat */
  .tab {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.35rem 0.85rem;
    border: 1px solid var(--rule-strong, #b8b3a8);
    border-bottom: 2px solid transparent;
    background: var(--paper-elevated, #fff);
    font-family: var(--font-sans, sans-serif);
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--ink-2, #4a443e);
    cursor: pointer;
    min-height: 36px;
    transition: border-color 0.1s, color 0.1s;
  }
  .tab:hover { color: var(--ink, #1a1814); border-color: var(--ink, #1a1814); }
  .tab-active {
    border-color: var(--ink, #1a1814);
    border-bottom-color: var(--ink, #1a1814);
    color: var(--ink, #1a1814);
    background: var(--paper, #fbfaf6);
  }
  .tab-count {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 1.4rem;
    height: 1.4rem;
    padding: 0 0.3rem;
    background: var(--ink-3, #807a72);
    color: var(--paper, #fbfaf6);
    font-size: 0.6875rem;
    font-weight: 700;
    border-radius: 99px;
  }

  /* Cerca */
  .search-wrap { flex: 1; }
  .search-input {
    width: 100%;
    max-width: 28rem;
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--rule-strong, #b8b3a8);
    background: var(--paper-elevated, #fff);
    font-family: var(--font-sans, sans-serif);
    font-size: 0.9375rem;
    color: var(--ink, #1a1814);
    min-height: 40px;
  }
  .search-input:focus {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }

  /* ── Loading ───────────────────────────────────── */
  .gp-loading {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 2.5rem 0;
    color: var(--ink-3, #807a72);
    font-size: 0.9375rem;
  }
  .loader-ring {
    width: 1.25rem;
    height: 1.25rem;
    border: 2px solid var(--rule-strong, #b8b3a8);
    border-top-color: var(--ink, #1a1814);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  /* ── Empty state ───────────────────────────────── */
  .gp-empty {
    padding: 3rem 1.5rem;
    text-align: center;
    border: 1px solid var(--rule, #e6e3dc);
    background: var(--paper-elevated, #fff);
  }
  .empty-icon {
    font-size: 2rem;
    color: var(--ink-3, #807a72);
    margin-bottom: 0.75rem;
  }
  .empty-msg {
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    margin: 0 0 0.75rem;
  }
  .btn-link {
    background: transparent;
    border: none;
    font-family: var(--font-sans, sans-serif);
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink, #1a1814);
    text-decoration: underline;
    cursor: pointer;
    padding: 0;
  }

  /* ── Taula (desktop) ───────────────────────────── */
  .gp-table-wrap {
    overflow-x: auto;
    border: 1px solid var(--rule, #e6e3dc);
    background: var(--paper-elevated, #fff);
  }
  .gp-table {
    width: 100%;
    border-collapse: collapse;
    font-family: var(--font-sans, sans-serif);
  }
  .gp-table thead tr {
    background: var(--paper, #fbfaf6);
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .gp-table th {
    padding: 0.65rem 0.85rem;
    font-size: 0.6875rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--ink-3, #807a72);
    text-align: left;
    white-space: nowrap;
  }
  .gp-row {
    border-bottom: 1px solid var(--rule, #e6e3dc);
  }
  .gp-row:hover { background: var(--paper, #fbfaf6); }
  .gp-row td {
    padding: 0.75rem 0.85rem;
    vertical-align: middle;
    font-size: 0.875rem;
  }
  .col-comp { width: 10rem; }
  .col-partida { min-width: 14rem; }
  .col-slot { width: 9rem; }
  .col-estat { width: 8rem; }
  .col-accions { width: 12rem; }

  /* Source badge */
  .source-badge {
    display: inline-block;
    font-size: 0.6rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    padding: 0.15rem 0.45rem;
    border: 1px solid currentColor;
    white-space: nowrap;
  }
  .source-badge-social  { color: var(--blue, #1a56db); }
  .source-badge-continu { color: var(--green, #1a6b2e); }
  .source-badge-handicap { color: var(--sec-handicap, #6b21a8); }
  .event-nom {
    margin-top: 0.25rem;
    font-size: 0.75rem;
    color: var(--ink-3, #807a72);
    max-width: 9rem;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Partida */
  .player-vs {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0.3rem;
    font-weight: 700;
    font-size: 0.9375rem;
  }
  .vs-sep {
    font-size: 0.75rem;
    font-weight: 400;
    color: var(--ink-3, #807a72);
  }
  .player-name { color: var(--ink, #1a1814); }
  .context-line {
    margin-top: 0.2rem;
    font-size: 0.75rem;
    color: var(--ink-3, #807a72);
  }

  /* Slot */
  .slot-grid {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 0.8125rem;
    font-feature-settings: 'tnum' 1;
    white-space: nowrap;
  }
  .slot-sep { color: var(--ink-3, #807a72); }
  .slot-val { font-weight: 600; color: var(--ink, #1a1814); }

  /* Estat chip */
  .estat-chip {
    display: inline-block;
    padding: 0.2rem 0.55rem;
    font-size: 0.75rem;
    font-weight: 600;
    border: 1px solid var(--rule-strong, #b8b3a8);
    background: var(--paper, #fbfaf6);
    color: var(--ink-2, #4a443e);
    white-space: nowrap;
  }
  .estat-chip-programada {
    border-color: var(--blue, #1a56db);
    color: var(--blue, #1a56db);
  }
  .estat-chip-jugada {
    border-color: var(--green, #1a6b2e);
    color: var(--green, #1a6b2e);
  }

  /* Accions */
  .actions-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
    align-items: center;
  }
  .action-btn {
    padding: 0.45rem 0.85rem;
    font-family: var(--font-sans, sans-serif);
    font-size: 0.8125rem;
    font-weight: 600;
    cursor: pointer;
    min-height: 36px;
    border: 1px solid;
    white-space: nowrap;
    transition: opacity 0.1s;
  }
  .action-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .action-btn-primary {
    background: var(--ink, #1a1814);
    color: var(--paper, #fbfaf6);
    border-color: var(--ink, #1a1814);
  }
  .action-btn-primary:hover:not(:disabled) { opacity: 0.85; }
  .action-btn-secondary {
    background: var(--paper-elevated, #fff);
    color: var(--ink, #1a1814);
    border-color: var(--rule-strong, #b8b3a8);
  }
  .action-btn-secondary:hover:not(:disabled) { border-color: var(--ink, #1a1814); }

  /* ── Cards (mobile) ────────────────────────────── */
  .gp-cards { display: none; }

  .gp-card {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    margin-bottom: 0.75rem;
  }
  .card-head {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-wrap: wrap;
  }
  .card-event {
    font-size: 0.75rem;
    color: var(--ink-3, #807a72);
    font-weight: 600;
  }
  .card-players {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0.3rem;
    font-weight: 700;
    font-size: 1rem;
  }
  .card-slot {
    font-size: 0.8125rem;
    color: var(--ink-2, #4a443e);
    font-feature-settings: 'tnum' 1;
  }
  .card-actions {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.4rem;
    flex-wrap: wrap;
  }
  .card-actions .action-btn {
    min-height: 44px;
    padding: 0.55rem 1rem;
    font-size: 0.875rem;
  }

  /* ── Responsive ────────────────────────────────── */
  @media (max-width: 767px) {
    .gp-table-wrap { display: none; }
    .gp-cards { display: block; }
    .gp-filters { gap: 0.6rem; }
    .search-input { max-width: 100%; }
  }
</style>
