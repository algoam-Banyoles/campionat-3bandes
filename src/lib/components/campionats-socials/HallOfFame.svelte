<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabaseClient';
  import { fkOne, normalizeSociFromFK } from '$lib/utils/supabaseJoins';
  import { formatarNomJugador } from '$lib/utils/playerUtils';

  let loading = true;
  let error: string | null = null;
  let selectedSeason = '';
  
  // Dades
  let winners: any[] = [];
  let allPlayers: any[] = [];
  let seasons: string[] = [];
  let lastLoadedSeasonKey: string | null = null;

  function parseSeason(value: string): { start: string; end: string } | null {
    const match = value?.trim().match(/^(\d{4})\D+(\d{4})$/);
    if (!match) return null;
    return { start: match[1], end: match[2] };
  }

  function normalizeSeason(value: string): string {
    const parsed = parseSeason(value);
    return parsed ? `${parsed.start}/${parsed.end}` : value?.trim() ?? '';
  }

  function seasonVariants(value: string): string[] {
    const trimmed = value?.trim();
    if (!trimmed) return [];
    const parsed = parseSeason(trimmed);
    if (!parsed) return [trimmed];
    return [`${parsed.start}/${parsed.end}`, `${parsed.start}-${parsed.end}`];
  }

  function getCurrentSeasonLabel(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const startYear = month >= 8 ? year : year - 1;
    return `${startYear}/${startYear + 1}`;
  }

  async function reloadFilteredData(force = false) {
    const seasonKey = selectedSeason ?? '';
    if (!force && seasonKey === lastLoadedSeasonKey) return;
    lastLoadedSeasonKey = seasonKey;

    await Promise.all([
      loadWinners(),
      loadAllPlayers()
    ]);
  }

  onMount(() => {
    loadData();
  });

  async function loadData() {
    loading = true;
    error = null;

    try {
      await loadSeasons();
      await reloadFilteredData(true);
    } catch (e: any) {
      console.error('Error carregant dades:', e);
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function loadSeasons() {
    const { data, error: seasonsError } = await supabase
      .from('events')
      .select('temporada')
      .eq('tipus_competicio', 'lliga_social')
      .order('temporada', { ascending: false });

    if (seasonsError) throw seasonsError;
    
    // Obtenir temporades úniques normalitzades (accepta 2025/2026 i 2025-2026)
    const uniqueSeasons = new Set<string>();
    (data || []).forEach((event: any) => {
      if (event?.temporada) {
        uniqueSeasons.add(normalizeSeason(event.temporada));
      }
    });
    seasons = Array.from(uniqueSeasons).sort((a, b) => b.localeCompare(a));
    
    // Seleccionar per defecte la temporada en curs
    if (seasons.length > 0) {
      const currentSeason = getCurrentSeasonLabel();
      selectedSeason = seasons.includes(currentSeason) ? currentSeason : seasons[0];
    }
  }

  async function loadWinners() {
    let query = supabase
      .from('classificacions')
      .select(`
        id,
        event_id,
        soci_numero,
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        caramboles_favor,
        caramboles_contra,
        mitjana_particular,
        events!inner (
          id,
          nom,
          temporada,
          modalitat,
          data_inici,
          data_fi
        ),
        categories!inner (
          id,
          nom,
          ordre_categoria
        ),
        socis:socis!classificacions_soci_numero_fkey (
          numero_soci,
          nom,
          cognoms
        )
      `)
      .lte('posicio', 3)
      .eq('events.estat_competicio', 'finalitzat');

    // Aplicar filtre per temporada si està seleccionat
    if (selectedSeason) {
      query = query.in('events.temporada', seasonVariants(selectedSeason));
    }

    const { data, error: winnersError } = await query;

    if (winnersError) throw winnersError;
    
    // Normalitzar joins (events/categories poden venir com a array o objecte)
    // i ordenar per temporada (desc) + data fi (desc).
    winners = (data || [])
      .map((w: any) => ({
        ...w,
        events: fkOne(w.events),
        categories: fkOne(w.categories)
      }))
      .sort((a: any, b: any) => {
        const tempA = a.events?.temporada || '';
        const tempB = b.events?.temporada || '';
        if (tempA !== tempB) {
          return tempB.localeCompare(tempA);
        }
        const dateA = a.events?.data_fi ? new Date(a.events.data_fi).getTime() : 0;
        const dateB = b.events?.data_fi ? new Date(b.events.data_fi).getTime() : 0;
        return dateB - dateA;
      });
  }

  async function loadAllPlayers() {
    // Obtenir tots els jugadors que han participat en campionats socials
    let query = supabase
      .from('inscripcions')
      .select(`
        event_id,
        soci_numero,
        socis (
          nom,
          cognoms,
          numero_soci
        ),
        events (
          id,
          temporada,
          modalitat
        )
      `)
      .eq('events.tipus_competicio', 'lliga_social')
      .eq('events.estat_competicio', 'finalitzat');

    // Aplicar filtre de temporada al llistat de participants
    if (selectedSeason) {
      query = query.in('events.temporada', seasonVariants(selectedSeason));
    }

    const { data, error: playersError } = await query;

    if (playersError) throw playersError;

    // Crear un conjunt únic de jugadors
    const uniquePlayers = new Map();
    
    (data || []).forEach((inscripcio: any) => {
      const key = inscripcio.soci_numero;
      const soci = normalizeSociFromFK(inscripcio.socis);
      const evt = fkOne(inscripcio.events) as any;
      if (!uniquePlayers.has(key)) {
        uniquePlayers.set(key, {
          numero_soci: inscripcio.soci_numero,
          nom: soci.nom || '',
          cognoms: soci.cognoms || '',
          participations: [],
          participationKeys: new Set<string>()
        });
      }

      // Afegir participació
      if (evt) {
        const participation = {
          temporada: evt?.temporada || '',
          modalitat: evt?.modalitat || ''
        };

        const eventKey = String(inscripcio.event_id || evt?.id || `${participation.temporada}-${participation.modalitat}`);
        const player = uniquePlayers.get(key);

        if (!player.participationKeys.has(eventKey)) {
          player.participationKeys.add(eventKey);
          player.participations.push(participation);
        }
      }
    });

    allPlayers = Array.from(uniquePlayers.values())
      .map(player => ({
        ...player,
        totalParticipations: player.participations.length,
        uniqueSeasons: [...new Set(player.participations.map((p: any) => p.temporada))].length
      }))
      .sort((a, b) => b.totalParticipations - a.totalParticipations);
  }

  // Recarregar quan canvien els filtres
  $: if (selectedSeason !== undefined && seasons.length > 0) {
    void reloadFilteredData();
  }

  // Agrupar guanyadors per torneig (events/categories ja normalitzats a loadWinners)
  $: winnersByEvent = winners.reduce((acc: any, winner: any) => {
    const eventKey = `${winner.event_id}-${winner.categories?.id ?? ''}`;
    if (!acc[eventKey]) {
      acc[eventKey] = {
        event: winner.events,
        category: winner.categories,
        winners: []
      };
    }
    acc[eventKey].winners.push(winner);
    return acc;
  }, {});

  function getModalityLabel(modality: string) {
    const modalities: Record<string, string> = {
      'tres_bandes': '3 Bandes',
      'lliure': 'Lliure',
      'banda': 'Banda'
    };
    return modalities[modality] || modality;
  }

  function getMedalEmoji(position: number) {
    if (position === 1) return '🥇';
    if (position === 2) return '🥈';
    if (position === 3) return '🥉';
    return '';
  }

  /**
   * Estadístiques agregades a partir de winners + allPlayers.
   * Sumen títols (1r), top-3 i mostren el rànquing de jugadors més
   * laureats. Es calcula reactivament al canviar la temporada.
   */
  $: stats = (() => {
    if (winners.length === 0) {
      return {
        totalChampionships: 0,
        topChampions: [] as { numero_soci: number; nom: string; cognoms: string; titles: number; podiums: number }[],
        bestMitjana: null as null | { player: string; mitjana: number; categoria: string; modalitat: string; temporada: string },
        mostParticipations: [] as typeof allPlayers
      };
    }

    const championsCount = new Map<number, { nom: string; cognoms: string; titles: number; podiums: number }>();

    for (const w of winners as any[]) {
      const numeroSoci = w.soci_numero;
      if (numeroSoci == null) continue;
      const sociRaw = Array.isArray(w.socis) ? w.socis[0] : w.socis;
      const nom = sociRaw?.nom ?? '';
      const cognoms = sociRaw?.cognoms ?? '';
      const existing = championsCount.get(numeroSoci) ?? {
        nom,
        cognoms,
        titles: 0,
        podiums: 0
      };
      if (w.posicio === 1) existing.titles++;
      if (w.posicio <= 3) existing.podiums++;
      championsCount.set(numeroSoci, existing);
    }

    const topChampions = Array.from(championsCount.entries())
      .map(([numero_soci, info]) => ({ numero_soci, ...info }))
      .sort((a, b) => b.titles - a.titles || b.podiums - a.podiums)
      .slice(0, 5);

    const mostParticipations = [...allPlayers]
      .sort((a, b) => b.totalParticipations - a.totalParticipations || b.uniqueSeasons - a.uniqueSeasons)
      .slice(0, 5);

    // Millor mitjana: cerquem entre els winners (que carreguem amb mitjana_particular)
    type BestMitjana = { player: string; mitjana: number; categoria: string; modalitat: string; temporada: string };
    let bestMitjana: BestMitjana | null = null;
    for (const w of winners as any[]) {
      if (typeof w.mitjana_particular === 'number' && w.mitjana_particular > 0) {
        if (!bestMitjana || w.mitjana_particular > bestMitjana.mitjana) {
          const sociRaw = Array.isArray(w.socis) ? w.socis[0] : w.socis;
          bestMitjana = {
            player: `${sociRaw?.nom ?? ''} ${sociRaw?.cognoms ?? ''}`.trim() || `Soci #${w.soci_numero}`,
            mitjana: w.mitjana_particular,
            categoria: w.categories?.nom ?? '',
            modalitat: w.events?.modalitat ?? '',
            temporada: w.events?.temporada ?? ''
          };
        }
      }
    }

    return {
      totalChampionships: winners.filter((w: any) => w.posicio === 1).length,
      topChampions,
      bestMitjana,
      mostParticipations
    };
  })();
</script>

<div class="hof-root">
  <!-- Filtres editorial -->
  <div class="hof-filters">
    <label for="season-filter" class="filter-legend">Temporada</label>
    <select
      id="season-filter"
      bind:value={selectedSeason}
      class="filter-input"
    >
      <option value="">Totes les temporades</option>
      {#each seasons as season}
        <option value={season}>{season}</option>
      {/each}
    </select>
  </div>

  {#if loading}
    <div class="state-empty">Carregant dades…</div>
  {:else if error}
    <div class="state-empty error-state">{error}</div>
  {:else}
    <!-- Quadre d'Honor -->
    <section class="hof-section">
      <header class="hof-section-head">
        <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Quadre d'honor</div>
        <h2 class="hof-section-title">Campions per categoria</h2>
      </header>

      {#if Object.keys(winnersByEvent).length === 0}
        <div class="state-empty" style="margin: 0; border: none;">
          No hi ha classificacions disponibles amb els filtres seleccionats.
        </div>
      {:else}
        <div class="hof-events">
          {#each Object.entries(winnersByEvent) as [_, eventData]}
            {@const typedEventData = eventData as any}
            <article class="hof-event">
              <header class="hof-event-head">
                <h3 class="hof-event-title">{typedEventData.event.nom}</h3>
                <div class="hof-event-tags">
                  <span class="hof-tag">{getModalityLabel(typedEventData.event.modalitat)}</span>
                  <span class="hof-tag hof-tag-muted">Temporada {typedEventData.event.temporada}</span>
                  <span class="hof-tag hof-tag-cat">{typedEventData.category.nom}</span>
                </div>
              </header>

              <div class="hof-podium">
                {#each typedEventData.winners.sort((a: any, b: any) => a.posicio - b.posicio) as winner}
                  {@const winnerSoci = normalizeSociFromFK(winner.socis)}
                  <div class="hof-spot" data-pos={winner.posicio}>
                    <div class="hof-pos tabular-nums">{String(winner.posicio).padStart(2, '0')}</div>
                    <div class="hof-name">
                      {#if winnerSoci.numero_soci}
                        <a href={`/jugador/${winnerSoci.numero_soci}`} class="hof-link">
                          {formatarNomJugador(`${winnerSoci.nom ?? ''} ${winnerSoci.cognoms ?? ''}`.trim())}
                        </a>
                      {:else}
                        {formatarNomJugador(`${winnerSoci.nom ?? ''} ${winnerSoci.cognoms ?? ''}`.trim())}
                      {/if}
                    </div>
                    <div class="hof-place">
                      {winner.posicio === 1 ? 'Primer lloc' : winner.posicio === 2 ? 'Segon lloc' : 'Tercer lloc'}
                    </div>
                  </div>
                {/each}
              </div>
            </article>
          {/each}
        </div>
      {/if}
    </section>

    <!-- Llistat de participants -->
    <section class="hof-section">
      <header class="hof-section-head">
        <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Participants</div>
        <h2 class="hof-section-title">Tots els participants <span class="hof-section-count tabular-nums">({allPlayers.length})</span></h2>
      </header>

      <div class="hof-table-wrap">
        <table class="hof-table">
          <thead>
            <tr>
              <th class="col-left">Jugador</th>
              <th class="col-num">Participacions</th>
              <th class="col-num">Temporades</th>
            </tr>
          </thead>
          <tbody>
            {#each allPlayers as player}
              <tr>
                <td class="col-left">
                  {#if player.numero_soci}
                    <a href={`/jugador/${player.numero_soci}`} class="hof-link player-name">
                      {formatarNomJugador(`${player.nom ?? ''} ${player.cognoms ?? ''}`.trim())}
                    </a>
                  {:else}
                    <span class="player-name">{formatarNomJugador(`${player.nom ?? ''} ${player.cognoms ?? ''}`.trim())}</span>
                  {/if}
                </td>
                <td class="col-num tabular-nums">{player.totalParticipations}</td>
                <td class="col-num tabular-nums">{player.uniqueSeasons}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </section>
  {/if}
</div>

<style>
  .hof-root {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }

  /* Filtres */
  .hof-filters {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1rem 1.5rem;
    display: flex;
    align-items: center;
    gap: 0.85rem;
  }
  .filter-legend {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .filter-input {
    padding: 0.5rem 0.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    color: var(--ink);
    font-family: var(--font-sans);
    font-size: 0.9375rem;
    font-weight: 500;
    min-height: 40px;
    min-width: 14rem;
  }
  .filter-input:focus {
    outline: 2px solid var(--ink);
    outline-offset: 1px;
    border-color: var(--ink);
  }

  /* Estats */
  .state-empty {
    padding: 1.75rem 2rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    text-align: center;
  }
  .state-empty.error-state { color: var(--accent); border-color: var(--accent); }

  /* Secció */
  .hof-section {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.5rem 1.75rem;
  }
  .hof-section-head {
    margin-bottom: 1.25rem;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid var(--ink);
  }
  .hof-section-title {
    font-weight: 800;
    font-size: 1.5rem;
    letter-spacing: -0.022em;
    margin: 0;
    line-height: 1.15;
  }
  .hof-section-count {
    color: var(--ink-3);
    font-weight: 500;
    font-size: 1rem;
    margin-left: 0.4rem;
  }

  /* Events */
  .hof-events {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  .hof-event {
    border: 1px solid var(--rule);
    background: var(--paper);
    padding: 1.25rem 1.5rem;
  }
  .hof-event-head {
    margin-bottom: 1rem;
    padding-bottom: 0.65rem;
    border-bottom: 1px solid var(--rule);
  }
  .hof-event-title {
    font-weight: 700;
    font-size: 1.125rem;
    letter-spacing: -0.018em;
    margin: 0 0 0.5rem;
    color: var(--ink);
  }
  .hof-event-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
  }
  .hof-tag {
    display: inline-block;
    padding: 0.18rem 0.55rem;
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    border: 1px solid var(--ink);
    color: var(--ink);
  }
  .hof-tag.hof-tag-muted {
    color: var(--ink-3);
    border-color: var(--rule-strong);
  }
  .hof-tag.hof-tag-cat {
    color: var(--green);
    border-color: var(--green);
  }

  /* Podium 1r/2n/3r */
  .hof-podium {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0;
    border: 1px solid var(--rule);
    background: var(--paper-elevated);
  }
  .hof-spot {
    padding: 1.25rem 1rem;
    border-right: 1px solid var(--rule);
    text-align: center;
  }
  .hof-spot:last-child { border-right: none; }
  .hof-spot[data-pos="1"] { border-top: 3px solid var(--accent); }
  .hof-spot[data-pos="2"] { border-top: 3px solid var(--ink-3); }
  .hof-spot[data-pos="3"] { border-top: 3px solid var(--amber); }
  .hof-pos {
    font-weight: 800;
    font-size: 1.875rem;
    letter-spacing: -0.03em;
    line-height: 1;
    color: var(--ink-3);
    margin-bottom: 0.65rem;
  }
  .hof-spot[data-pos="1"] .hof-pos { color: var(--accent); }
  .hof-spot[data-pos="3"] .hof-pos { color: var(--amber); }
  .hof-name {
    font-weight: 800;
    font-size: 1rem;
    letter-spacing: -0.018em;
    color: var(--ink);
    line-height: 1.2;
  }
  .hof-place {
    margin-top: 0.4rem;
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
  }

  /* Taula de participants */
  .hof-table-wrap { overflow-x: auto; }
  .hof-table { width: 100%; border-collapse: collapse; }
  .hof-table th {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    padding: 0.75rem 0.85rem;
    border-bottom: 1px solid var(--rule);
    white-space: nowrap;
    background: var(--paper);
  }
  .hof-table th.col-left { text-align: left; }
  .hof-table th.col-num { text-align: right; }
  .hof-table td {
    padding: 0.7rem 0.85rem;
    border-bottom: 1px solid var(--rule);
    font-size: 0.9375rem;
    color: var(--ink);
  }
  .hof-table td.col-left { text-align: left; }
  .hof-table td.col-num { text-align: right; }
  .hof-table td.col-narrow { color: var(--ink-3); }
  .hof-table tr:last-child td { border-bottom: none; }
  .hof-table tr:hover { background: var(--paper); }
  .player-name {
    font-weight: 700;
    color: var(--ink);
    letter-spacing: -0.012em;
  }
  .hof-link {
    color: inherit;
    text-decoration: none;
    border-bottom: 1px solid transparent;
    transition: border-color 0.15s ease, color 0.15s ease;
  }
  .hof-link:hover {
    color: var(--accent, #a30b1e);
    border-bottom-color: var(--accent, #a30b1e);
  }

  @media (max-width: 640px) {
    .hof-section { padding: 1rem 1.1rem; }
    .hof-event { padding: 1rem; }
    .hof-podium { grid-template-columns: 1fr; }
    .hof-spot { border-right: none; border-bottom: 1px solid var(--rule); }
    .hof-spot:last-child { border-bottom: none; }
    .hof-section-title { font-size: 1.25rem; }
    .hof-filters { flex-direction: column; align-items: stretch; }
    .filter-input { min-width: 0; width: 100%; }
    .hof-table .col-narrow { display: none; }
  }
</style>
