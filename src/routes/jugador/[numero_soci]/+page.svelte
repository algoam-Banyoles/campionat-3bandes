<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabaseClient';
  import { formatarNomJugador } from '$lib/utils/playerUtils';
  import MyUpcomingMatchesWidget from '$lib/components/general/MyUpcomingMatchesWidget.svelte';

  type Soci = {
    numero_soci: number;
    nom: string;
    cognoms: string;
  };

  type MitjanaRow = {
    year: number;
    modalitat: string;
    mitjana: number;
  };

  type EventParticipation = {
    event_id: string;
    event_nom: string;
    temporada: string;
    modalitat: string;
    tipus_competicio: string;
    estat_competicio: string;
    categoria_nom: string | null;
  };

  const numeroSoci = parseInt($page.params.numero_soci, 10);

  let loading = true;
  let error: string | null = null;
  let soci: Soci | null = null;
  let mitjanes: MitjanaRow[] = [];
  let events: EventParticipation[] = [];
  let totalMatches = 0;

  $: nomComplet = soci ? formatarNomJugador(`${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim()) : '';
  $: nomComplerSencer = soci ? `${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim() : '';

  // Mitjanes per modalitat
  $: mitjanesByModalitat = (() => {
    const grouped: Record<string, MitjanaRow[]> = {};
    for (const m of mitjanes) {
      if (!grouped[m.modalitat]) grouped[m.modalitat] = [];
      grouped[m.modalitat].push(m);
    }
    // Sort each modality by year asc
    for (const mod in grouped) {
      grouped[mod].sort((a, b) => a.year - b.year);
    }
    return grouped;
  })();

  // Events per tipus
  $: eventsByTipus = (() => {
    const grouped: Record<string, EventParticipation[]> = {};
    for (const e of events) {
      if (!grouped[e.tipus_competicio]) grouped[e.tipus_competicio] = [];
      grouped[e.tipus_competicio].push(e);
    }
    // Sort each by temporada desc
    for (const t in grouped) {
      grouped[t].sort((a, b) => b.temporada.localeCompare(a.temporada));
    }
    return grouped;
  })();

  // Format temporada (year) → "X/Y"
  function formatSeason(year: number): string {
    return `${year - 1}/${year}`;
  }

  function formatTemporada(temporada: string): string {
    // 2024-2025 → 2024/2025
    return temporada.replace('-', '/');
  }

  function modalityLabel(m: string): string {
    if (m === '3 BANDES' || m === 'tres_bandes') return '3 Bandes';
    if (m === 'LLIURE' || m === 'lliure') return 'Lliure';
    if (m === 'BANDA' || m === 'banda') return 'Banda';
    return m;
  }

  function tipusLabel(t: string): string {
    if (t === 'lliga_social') return 'Campionats socials';
    if (t === 'continu') return 'Rànquing continu';
    if (t === 'handicap') return 'Hàndicap';
    return t;
  }

  onMount(async () => {
    if (isNaN(numeroSoci)) {
      error = 'Número de soci no vàlid';
      loading = false;
      return;
    }
    try {
      // 1) Soci — només camps no-PII (email/data_naixement no s'exposen en perfil públic)
      const { data: sociData, error: sociErr } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .eq('numero_soci', numeroSoci)
        .maybeSingle();
      if (sociErr) throw sociErr;
      if (!sociData) {
        error = 'No s\'ha trobat aquest soci';
        loading = false;
        return;
      }
      soci = sociData;

      // 2) Mitjanes històriques
      const { data: mitData, error: mitErr } = await supabase
        .from('mitjanes_historiques')
        .select('year, modalitat, mitjana')
        .eq('soci_id', numeroSoci)
        .order('year', { ascending: false });
      if (mitErr) throw mitErr;
      mitjanes = mitData || [];

      // 3) Events on ha participat (via inscripcions)
      const { data: inscData, error: inscErr } = await supabase
        .from('inscripcions')
        .select('event_id, categoria_assignada_id')
        .eq('soci_numero', numeroSoci);
      if (inscErr) throw inscErr;
      const eventIds = [...new Set((inscData || []).map((i: any) => i.event_id).filter(Boolean))];

      if (eventIds.length > 0) {
        const { data: evData, error: evErr } = await supabase
          .from('events')
          .select('id, nom, temporada, modalitat, tipus_competicio, estat_competicio')
          .in('id', eventIds)
          .order('temporada', { ascending: false });
        if (evErr) throw evErr;

        // Get categoria info per event
        const categoriaIds = [...new Set((inscData || []).map((i: any) => i.categoria_assignada_id).filter(Boolean))];
        let categoriesMap = new Map<string, string>();
        if (categoriaIds.length > 0) {
          const { data: catData } = await supabase
            .from('categories')
            .select('id, nom')
            .in('id', categoriaIds);
          (catData || []).forEach((c: any) => categoriesMap.set(c.id, c.nom));
        }

        const inscByEvent = new Map<string, string | null>();
        (inscData || []).forEach((i: any) => {
          if (i.event_id) inscByEvent.set(i.event_id, i.categoria_assignada_id || null);
        });

        events = (evData || []).map((e: any) => ({
          event_id: e.id,
          event_nom: e.nom,
          temporada: e.temporada,
          modalitat: e.modalitat,
          tipus_competicio: e.tipus_competicio,
          estat_competicio: e.estat_competicio,
          categoria_nom: inscByEvent.get(e.id) ? categoriesMap.get(inscByEvent.get(e.id)!) ?? null : null
        }));
      }

      // 4) Total matches (count partides on aquest jugador apareix)
      const { count: matchCount } = await supabase
        .from('calendari_partides')
        .select('id', { count: 'exact', head: true })
        .or(`jugador1_soci_numero.eq.${numeroSoci},jugador2_soci_numero.eq.${numeroSoci}`)
        .eq('estat', 'jugada');
      totalMatches = matchCount ?? 0;
    } catch (e: any) {
      console.error('Error loading player profile:', e);
      error = e?.message ?? 'Error carregant el perfil';
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>{soci ? `${nomComplet} — Perfil` : 'Perfil del jugador'}</title>
</svelte:head>

<div class="prof-root">
  {#if loading}
    <p class="prof-loading">Carregant perfil…</p>
  {:else if error}
    <div class="prof-error">{error}</div>
  {:else if soci}
    <header class="prof-mast">
      <div class="editorial-eyebrow">Foment Martinenc · Jugador</div>
      <h1 class="prof-title">{nomComplet}</h1>
      <p class="prof-fullname">{nomComplerSencer}</p>
      <div class="prof-stats">
        <div class="prof-stat">
          <div class="prof-stat-eyebrow">Partides jugades</div>
          <div class="prof-stat-value tabular-nums">{totalMatches}</div>
        </div>
        <div class="prof-stat">
          <div class="prof-stat-eyebrow">Temporades amb mitjana</div>
          <div class="prof-stat-value tabular-nums">{new Set(mitjanes.map(m => m.year)).size}</div>
        </div>
        <div class="prof-stat">
          <div class="prof-stat-eyebrow">Events participats</div>
          <div class="prof-stat-value tabular-nums">{events.length}</div>
        </div>
      </div>
    </header>

    <!-- Properes partides programades del jugador -->
    <MyUpcomingMatchesWidget sociNumero={numeroSoci} limit={5} />

    <!-- Mitjanes històriques per modalitat -->
    {#if Object.keys(mitjanesByModalitat).length > 0}
      <section class="prof-section">
        <div class="prof-section-head">
          <div class="editorial-eyebrow">01</div>
          <h2 class="prof-section-title">Mitjanes per temporada</h2>
        </div>
        <div class="prof-modality-grid">
          {#each Object.entries(mitjanesByModalitat) as [modalitat, rows]}
            <div class="prof-modality-card">
              <h3 class="prof-modality-name">{modalityLabel(modalitat)}</h3>
              <table class="prof-modality-table">
                <thead>
                  <tr>
                    <th>Temporada</th>
                    <th class="text-right">Mitjana</th>
                  </tr>
                </thead>
                <tbody>
                  {#each rows.slice().reverse() as r}
                    <tr>
                      <td class="tabular-nums">{formatSeason(r.year)}</td>
                      <td class="text-right tabular-nums">{r.mitjana.toFixed(3)}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/each}
        </div>
      </section>
    {/if}

    <!-- Events participats -->
    {#if events.length > 0}
      <section class="prof-section">
        <div class="prof-section-head">
          <div class="editorial-eyebrow">02</div>
          <h2 class="prof-section-title">Competicions</h2>
        </div>
        {#each Object.entries(eventsByTipus) as [tipus, evs]}
          <div class="prof-tipus-block">
            <h3 class="prof-tipus-name">{tipusLabel(tipus)}</h3>
            <ul class="prof-events-list">
              {#each evs as e}
                <li class="prof-event-row">
                  <div class="prof-event-info">
                    <span class="prof-event-temporada tabular-nums">{formatTemporada(e.temporada)}</span>
                    <span class="prof-event-name">{e.event_nom}</span>
                    {#if e.categoria_nom}
                      <span class="prof-event-cat">· {e.categoria_nom}</span>
                    {/if}
                  </div>
                  <div class="prof-event-actions">
                    <span class="prof-event-state" class:active={e.estat_competicio === 'en_curs'}>
                      {e.estat_competicio === 'finalitzat' ? 'Finalitzat'
                        : e.estat_competicio === 'en_curs' ? 'En curs' : e.estat_competicio}
                    </span>
                    {#if tipus === 'lliga_social'}
                      <a href={`/campionats-socials/${e.event_id}/classificacio`} class="prof-event-link">Classificació →</a>
                    {/if}
                  </div>
                </li>
              {/each}
            </ul>
          </div>
        {/each}
      </section>
    {/if}

    {#if mitjanes.length === 0 && events.length === 0}
      <p class="prof-empty">No hi ha dades disponibles per a aquest jugador.</p>
    {/if}
  {/if}
</div>

<style>
  .prof-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .prof-loading,
  .prof-empty {
    color: var(--ink-3, #807a72);
    font-size: 0.9375rem;
  }
  .prof-error {
    padding: 1rem 1.25rem;
    background: var(--paper);
    border: 1px solid var(--accent);
    color: var(--accent);
  }

  .prof-mast {
    margin-bottom: 2rem;
    padding-bottom: 1.25rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .prof-title {
    margin: 0.4rem 0 0.2rem;
    font-size: clamp(2rem, 3vw, 3rem);
    font-weight: 800;
    letter-spacing: -0.024em;
    line-height: 1.05;
  }
  .prof-fullname {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-3, #807a72);
  }
  .prof-stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 0.75rem;
    margin-top: 1.25rem;
  }
  .prof-stat {
    padding: 0.85rem 1rem;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
  }
  .prof-stat-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .prof-stat-value {
    margin-top: 0.25rem;
    font-size: 1.5rem;
    font-weight: 800;
    letter-spacing: -0.02em;
    line-height: 1;
    color: var(--ink, #1a1814);
  }

  .tabular-nums { font-variant-numeric: tabular-nums; }

  .prof-section { margin-top: 2.25rem; }
  .prof-section-head {
    margin-bottom: 1rem;
    padding-bottom: 0.65rem;
    border-bottom: 1px solid var(--rule-strong, #b8b3a8);
  }
  .prof-section-title {
    margin: 0.3rem 0 0;
    font-size: 1.25rem;
    font-weight: 800;
    letter-spacing: -0.018em;
  }

  /* Mitjanes per modalitat */
  .prof-modality-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1rem;
  }
  .prof-modality-card {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
    padding: 1rem 1.1rem;
  }
  .prof-modality-name {
    margin: 0 0 0.6rem;
    font-size: 0.875rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--ink-2, #4a443e);
  }
  .prof-modality-table {
    width: 100%;
    font-size: 0.875rem;
    border-collapse: collapse;
  }
  .prof-modality-table th,
  .prof-modality-table td {
    padding: 0.4rem 0;
    text-align: left;
    border-bottom: 1px solid var(--rule, #e6e3dc);
  }
  .prof-modality-table th {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .prof-modality-table .text-right { text-align: right; }

  /* Events */
  .prof-tipus-block { margin-bottom: 1.5rem; }
  .prof-tipus-name {
    margin: 0 0 0.5rem;
    font-size: 0.8125rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--ink-2, #4a443e);
  }
  .prof-events-list {
    list-style: none;
    padding: 0;
    margin: 0;
    border-top: 1px solid var(--rule, #e6e3dc);
  }
  .prof-event-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    padding: 0.7rem 0;
    border-bottom: 1px solid var(--rule, #e6e3dc);
    flex-wrap: wrap;
  }
  .prof-event-info {
    display: flex;
    align-items: baseline;
    gap: 0.5rem;
    flex-wrap: wrap;
    flex: 1;
    min-width: 0;
  }
  .prof-event-temporada {
    font-size: 0.8125rem;
    font-weight: 700;
    color: var(--ink-3, #807a72);
    min-width: 5.5rem;
  }
  .prof-event-name {
    font-size: 0.9375rem;
    color: var(--ink, #1a1814);
    font-weight: 600;
  }
  .prof-event-cat {
    font-size: 0.875rem;
    color: var(--ink-2, #4a443e);
  }
  .prof-event-actions {
    display: flex;
    align-items: center;
    gap: 0.85rem;
  }
  .prof-event-state {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    padding: 0.2rem 0.5rem;
    background: var(--paper, #fbfaf6);
    color: var(--ink-3, #807a72);
    border: 1px solid var(--rule, #e6e3dc);
  }
  .prof-event-state.active {
    background: var(--green, #1f7a3a);
    color: var(--paper, #fbfaf6);
    border-color: var(--green, #1f7a3a);
  }
  .prof-event-link {
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--ink, #1a1814);
    text-decoration: none;
    border-bottom: 1px solid var(--ink, #1a1814);
  }
  .prof-event-link:hover { color: var(--accent, #a30b1e); border-color: var(--accent, #a30b1e); }
</style>
