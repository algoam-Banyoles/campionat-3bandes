<script lang="ts">
  import { supabase } from '$lib/supabaseClient';
  import { onMount, onDestroy } from 'svelte';
  import PlayerResultsModal from './PlayerResultsModal.svelte';
  import SociFoto from '$lib/components/admin/SociFoto.svelte';
  import { subscribeToMatchUpdates } from '$lib/services/realtimeMatchesService';
  import { showInfo } from '$lib/stores/toastStore';

  export let event: any = null;
  export let showDetails: boolean = false;

  let classifications: any[] = [];
  let loadedCategories: any[] = [];
  let loading = false;
  let error: string | null = null;
  let selectedCategory = 'all';
  let lastMatchDate: Date | null = null;
  let lastRefreshedAt: Date | null = null;
  let expandedCategories: Set<string> = new Set();

  // Modal state
  let isModalOpen = false;
  let selectedPlayer: any = null;

  // Realtime: unsubscribe function de la subscripció a canvis de partides.
  // Es re-creem cada cop que canvia l'event (veure efecte reactiu més avall).
  let unsubscribeRealtime: (() => void) | null = null;
  let loadClassificationsCounter = 0;

  // Inicialització gestionada per l'efecte reactiu $: if (event?.id) més avall.

  onDestroy(() => {
    if (unsubscribeRealtime) {
      unsubscribeRealtime();
      unsubscribeRealtime = null;
    }
  });

  /**
   * Subscriu a canvis de partides per recarregar classificacions
   * automàticament quan un altre client introdueix un resultat.
   * Es re-crea cada cop que l'event canvia.
   */
  $: {
    if (unsubscribeRealtime) {
      unsubscribeRealtime();
      unsubscribeRealtime = null;
    }
    if (event?.id) {
      unsubscribeRealtime = subscribeToMatchUpdates(supabase, event.id, (e) => {
        if (e.type === 'result_recorded' || e.type === 'result_modified') {
          // Si el canvi ve de l'usuari local, recarreguem en silenci
          if (!e.isLocalEcho) {
            showInfo('Nou resultat introduït — actualitzant classificacions...');
          }
          loadClassifications();
        }
      });
    }
  }

  // Expand all categories by default when classifications first load.
  // Reset hasInitialized when the event changes so a new event starts expanded.
  let hasInitialized = false;
  let _lastEventId: string | null = null;
  $: if (event?.id !== _lastEventId) {
    _lastEventId = event?.id ?? null;
    hasInitialized = false;
  }
  $: if (classifications.length > 0 && !hasInitialized) {
    expandedCategories = new Set(
      Array.from(new Set(classifications.map(c => c.categoria_id)))
    );
    hasInitialized = true;
  }

  /**
   * Format relatiu en català: "fa 3 segons", "fa 2 minuts", "fa 1 hora",
   * o data absoluta si fa més d'un dia.
   */
  function formatRelativeTime(d: Date | null, now: Date): string {
    if (!d) return 'mai';
    const diffMs = now.getTime() - d.getTime();
    const sec = Math.floor(diffMs / 1000);
    if (sec < 5) return 'ara mateix';
    if (sec < 60) return `fa ${sec} segons`;
    const min = Math.floor(sec / 60);
    if (min < 60) return `fa ${min} minut${min === 1 ? '' : 's'}`;
    const hr = Math.floor(min / 60);
    if (hr < 24) return `fa ${hr} hor${hr === 1 ? 'a' : 'es'}`;
    return d.toLocaleDateString('ca-ES', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
  }

  // Tick reactive cada 30s perquè el "fa N minuts" es vagi actualitzant.
  let tick = Date.now();
  let tickInterval: ReturnType<typeof setInterval> | null = null;
  onMount(() => {
    tickInterval = setInterval(() => (tick = Date.now()), 30000);
    return () => {
      if (tickInterval) clearInterval(tickInterval);
    };
  });

  function toggleCategory(categoryId: string) {
    if (expandedCategories.has(categoryId)) {
      expandedCategories.delete(categoryId);
    } else {
      expandedCategories.add(categoryId);
    }
    expandedCategories = expandedCategories; // Trigger reactivity
  }

  $: if (event?.id) {
    loadCategories();
    loadClassifications();
  }

  async function loadCategories() {
    if (!event?.id) return;

    try {
      const { data, error: categoriesError } = await supabase
        .from('categories')
        .select('*')
        .eq('event_id', event.id)
        .order('ordre_categoria', { ascending: true });

      if (categoriesError) throw categoriesError;
      loadedCategories = data || [];
    } catch (e) {
      console.error('Error loading categories:', e);
    }
  }

  async function loadClassifications() {
    if (!event?.id) {
      return;
    }

    const myReq = ++loadClassificationsCounter;
    loading = true;
    error = null;

    try {
      // Load real-time classifications for social leagues from calendari_partides
      const { data, error: classificationsError } = await supabase
        .rpc('get_social_league_classifications', {
          p_event_id: event.id
        });

      if (myReq !== loadClassificationsCounter) return; // stale response

      if (classificationsError) throw classificationsError;

      classifications = data || [];

      // Load last match date. IMPORTANT: filtrem les files amb data_joc NULL
      // (partides sense data introduïda) i ordenem nulls al final, perquè si no
      // PostgreSQL retorna NULL primer i `new Date(null)` dóna 1970-01-01.
      const { data: lastMatch, error: lastMatchError } = await supabase
        .from('calendari_partides')
        .select('data_joc')
        .eq('event_id', event.id)
        .not('caramboles_jugador1', 'is', null)
        .not('caramboles_jugador2', 'is', null)
        .not('data_joc', 'is', null)
        .not('partida_anullada', 'is', true)
        .order('data_joc', { ascending: false, nullsFirst: false })
        .limit(1)
        .maybeSingle();

      if (!lastMatchError && lastMatch?.data_joc) {
        lastMatchDate = new Date(lastMatch.data_joc);
      } else {
        lastMatchDate = null;
      }

      lastRefreshedAt = new Date();
    } catch (e) {
      console.error('❌ Error loading classifications:', e);
      error = 'Error carregant les classificacions';
    } finally {
      loading = false;
    }
  }

  function formatPlayerName(classification: any) {
    const nom = classification.soci_nom;
    const cognoms = classification.soci_cognoms;

    if (!nom && !cognoms) return `Soci #${classification.soci_numero}`;

    // Format: inicial(s) del nom + primer cognom
    let inicials = '';
    if (nom) {
      const noms = nom.trim().split(/\s+/);
      inicials = noms.map(n => n.charAt(0).toUpperCase() + '.').join('');
    }

    const primerCognom = cognoms ? cognoms.trim().split(/\s+/)[0] : '';

    if (inicials && primerCognom) {
      return `${inicials} ${primerCognom}`;
    } else if (inicials) {
      return inicials;
    } else if (primerCognom) {
      return primerCognom;
    }

    return `Soci #${classification.soci_numero}`;
  }

  function getPositionColor(position: number) {
    if (position === 1) return 'bg-yellow-100 text-yellow-800 border-yellow-200';
    if (position === 2) return 'bg-gray-100 text-gray-800 border-gray-200';
    if (position === 3) return 'bg-orange-100 text-orange-800 border-orange-200';
    return 'bg-white text-gray-700 border-gray-200';
  }

  function getPositionIcon(position: number) {
    if (position === 1) return '🥇';
    if (position === 2) return '🥈';
    if (position === 3) return '🥉';
    return position.toString();
  }

  function openPlayerModal(classification: any) {
    selectedPlayer = {
      name: formatPlayerName(classification),
      numeroSoci: classification.soci_numero,
      eventId: event?.id,
      categoriaId: classification.categoria_id
    };
    isModalOpen = true;
  }

  // Group classifications by category
  $: classificationsByCategory = classifications.reduce((groups, classification) => {
    const categoryId = classification.categoria_id;
    if (!groups[categoryId]) {
      groups[categoryId] = [];
    }
    groups[categoryId].push(classification);
    return groups;
  }, {} as Record<string, any[]>);

  // Extract unique categories from classifications
  $: categoriesFromClassifications = Array.from(
    new Map(
      classifications
        .filter(c => c.categoria_id) // Filter out classifications without categoria_id
        .map(c => [
          c.categoria_id,
          {
            id: c.categoria_id,
            nom: c.categoria_nom,
            ordre_categoria: c.categoria_ordre,
            distancia_caramboles: c.categoria_distancia_caramboles || 0
          }
        ])
    ).values()
  ).sort((a, b) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0));

  // Use loaded categories first, then from event prop, then from classifications
  $: sortedCategories = loadedCategories.length > 0
    ? loadedCategories
    : (event?.categories && event.categories.length > 0)
    ? [...event.categories].sort((a: any, b: any) => (a.ordre_categoria || 0) - (b.ordre_categoria || 0))
    : categoriesFromClassifications;

  $: console.log('📊 SocialLeagueClassifications - Categories:', sortedCategories.length, 'Classifications:', classifications.length, 'Loaded categories:', loadedCategories.length);

  // Filter categories based on selected filter
  $: filteredCategories = selectedCategory === 'all'
    ? sortedCategories
    : sortedCategories.filter((c: any) => c.id === selectedCategory);
</script>

<div class="classifications-root">

  <!-- ────────── Header editorial ────────── -->
  <div class="cls-head">
    <div>
      <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">
        Classificacions{#if event} · Temporada {event.temporada}{/if}
      </div>
      <h2 class="cls-title">{event?.nom || 'Campionat'}</h2>
    </div>
    <div class="cls-controls">
      <select bind:value={selectedCategory} class="cls-select" aria-label="Filtrar categoria">
        <option value="all">Totes les categories</option>
        {#each sortedCategories as category}
          <option value={category.id}>{category.nom}</option>
        {/each}
      </select>
    </div>
  </div>

  <!-- Banner de freshness -->
  {#if classifications.length > 0 || lastRefreshedAt}
    {@const now = new Date(tick)}
    <div class="cls-freshness">
      <span class="freshness-dot" title="Actualització automàtica activa" aria-hidden="true"></span>
      <span class="freshness-text">
        Actualitzat <strong>{formatRelativeTime(lastRefreshedAt, now)}</strong>
        {#if lastMatchDate}
          · darrer resultat <strong>{formatRelativeTime(lastMatchDate, now)}</strong>
        {/if}
      </span>
      <button
        type="button"
        on:click={loadClassifications}
        disabled={loading}
        class="freshness-refresh"
        title="Refrescar manualment"
      >
        {loading ? '⟳ Refrescant…' : '↻ Refrescar'}
      </button>
    </div>
  {/if}

  {#if loading}
    <div class="state-empty">Carregant classificacions…</div>
  {:else if error}
    <div class="state-empty error-state">{error}</div>
  {:else if filteredCategories.length === 0}
    <div class="state-empty">
      No hi ha classificacions disponibles. Apareixeran aquí quan es juguin partides.
    </div>
  {:else}
    <!-- Classifications by category -->
    {#each filteredCategories as category (category.id)}
      {@const categoryClassifications = classificationsByCategory[category.id] || []}

      <article class="cat-block">
        <!-- Category header editorial -->
        <button
          on:click={() => toggleCategory(category.id)}
          class="cat-header"
          aria-expanded={expandedCategories.has(category.id)}
        >
          <span class="cat-toggle-icon" aria-hidden="true">{expandedCategories.has(category.id) ? '−' : '+'}</span>
          <div class="cat-name-block">
            <div class="cat-name">{category.nom}</div>
            <div class="cat-meta">
              Distància <strong>{category.distancia_caramboles || 0}</strong> caramboles
            </div>
          </div>
          <div class="cat-count-block">
            <div class="cat-count tabular-nums">{categoryClassifications.length}</div>
            <div class="cat-count-label">jugadors</div>
          </div>
        </button>

        {#if expandedCategories.has(category.id)}
          {#if categoryClassifications.length === 0}
            <div class="state-empty" style="margin: 0; border: none;">
              No hi ha classificacions per a aquesta categoria.
            </div>
          {:else}
            <!-- Desktop Table View — editorial -->
            <div class="cls-table-wrap">
              <table class="cls-table">
                <thead>
                  <tr>
                    <th class="col-pos">Pos</th>
                    <th class="col-player col-left">Jugador</th>
                    <th class="col-num">PJ</th>
                    <th class="col-num col-pts-head">Punts</th>
                    <th class="col-num">Caramboles</th>
                    <th class="col-num">Entrades</th>
                    <th class="col-num">Mitjana</th>
                    <th class="col-num">Millor mitj.</th>
                  </tr>
                </thead>
                <tbody>
                  {#each categoryClassifications as classification (classification.soci_numero + classification.categoria_id)}
                    {@const isDisqualified = classification.eliminat_per_incompareixences === true}
                    <tr class:top3={classification.posicio <= 3} class:retired={classification.estat_jugador === 'retirat'}>
                      <td class="col-pos">
                        <span class="pos-num tabular-nums">{classification.posicio.toString().padStart(2, '0')}</span>
                      </td>
                      <td class="col-player col-left">
                        <div class="player-cell">
                          <SociFoto
                            numeroSoci={classification.soci_numero}
                            size="xs"
                            alt="{classification.soci_nom ?? ''} {classification.soci_cognoms ?? ''}"
                          />
                          <button
                            on:click={() => openPlayerModal(classification)}
                            class="player-name-btn"
                            class:retired-name={classification.estat_jugador === 'retirat'}
                            title="Veure resultats de {formatPlayerName(classification)}"
                          >
                            <span class="player-name-text">{formatPlayerName(classification)}</span>
                          </button>
                          {#if classification.estat_jugador === 'retirat'}
                            <span class="retired-badge" title={classification.motiu_retirada || (isDisqualified ? 'Desqualificat' : 'Retirat')}>
                              {isDisqualified ? 'DQF' : 'Retirat'}
                            </span>
                          {/if}
                        </div>
                      </td>
                      <td class="col-num tabular-nums">{classification.partides_jugades}</td>
                      <td class="col-num col-pts-data tabular-nums">{classification.punts}</td>
                      <td class="col-num tabular-nums">{classification.caramboles_totals ?? '—'}</td>
                      <td class="col-num tabular-nums">{classification.entrades_totals ?? '—'}</td>
                      <td class="col-num tabular-nums">
                        {classification.mitjana_general != null ? Number(classification.mitjana_general).toFixed(3) : '—'}
                      </td>
                      <td class="col-num tabular-nums">
                        {classification.millor_mitjana != null ? Number(classification.millor_mitjana).toFixed(3) : '—'}
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>

            <!-- Mobile compact list — editorial -->
            <div class="cls-mobile">
              {#each categoryClassifications as classification (classification.soci_numero + classification.categoria_id)}
                {@const isDisqualified = classification.eliminat_per_incompareixences === true}
                <article class="cls-mob-row" class:top3={classification.posicio <= 3} class:retired={classification.estat_jugador === 'retirat'}>
                  <div class="cls-mob-head">
                    <div class="cls-mob-pos tabular-nums">{classification.posicio.toString().padStart(2, '0')}</div>
                    <button
                      on:click={() => openPlayerModal(classification)}
                      class="cls-mob-name-btn"
                      title="Veure resultats de {formatPlayerName(classification)}"
                    >
                      <SociFoto
                        numeroSoci={classification.soci_numero}
                        size="xs"
                        alt="{classification.soci_nom ?? ''} {classification.soci_cognoms ?? ''}"
                      />
                      <span class="cls-mob-name">{formatPlayerName(classification)}</span>
                      {#if classification.estat_jugador === 'retirat'}
                        <span class="retired-badge" title={classification.motiu_retirada || (isDisqualified ? 'Desqualificat' : 'Retirat')}>
                          {isDisqualified ? 'DQF' : 'R'}
                        </span>
                      {/if}
                    </button>
                    <div class="cls-mob-pts">
                      <span class="cls-mob-pts-num tabular-nums">{classification.punts}</span>
                      <span class="cls-mob-pts-lbl">punts</span>
                    </div>
                  </div>
                  <div class="cls-mob-stats">
                    <div>
                      <span class="cls-mob-stat-num tabular-nums">{classification.partides_jugades}</span>
                      <span class="cls-mob-stat-lbl">PJ</span>
                    </div>
                    <div>
                      <span class="cls-mob-stat-num tabular-nums">{classification.caramboles_totals ?? '—'}</span>
                      <span class="cls-mob-stat-lbl">Car.</span>
                    </div>
                    <div>
                      <span class="cls-mob-stat-num tabular-nums">{classification.entrades_totals ?? '—'}</span>
                      <span class="cls-mob-stat-lbl">Ent.</span>
                    </div>
                    <div>
                      <span class="cls-mob-stat-num tabular-nums">
                        {classification.mitjana_general != null ? Number(classification.mitjana_general).toFixed(3) : '—'}
                      </span>
                      <span class="cls-mob-stat-lbl">Mitj.</span>
                    </div>
                  </div>
                </article>
              {/each}
            </div>

          {#if showDetails}
            <!-- Category statistics — editorial stat-strip -->
            {@const totalPartides = categoryClassifications.reduce((sum, c) => sum + (c.partides_jugades ?? 0), 0) / 2}
            {@const totalCaramboles = categoryClassifications.reduce((sum, c) => sum + (c.caramboles_totals ?? 0), 0)}
            {@const totalEntrades = categoryClassifications.reduce((sum, c) => sum + (c.entrades_totals ?? 0), 0)}
            {@const mitjanaCategoria = totalEntrades > 0 ? (totalCaramboles / totalEntrades) : 0}

            <div class="cls-stats-strip">
              <div>
                <div class="cls-stat-num tabular-nums">{Math.floor(totalPartides)}</div>
                <div class="cls-stat-lbl">Partides</div>
              </div>
              <div>
                <div class="cls-stat-num tabular-nums">{totalCaramboles}</div>
                <div class="cls-stat-lbl">Caramboles</div>
              </div>
              <div>
                <div class="cls-stat-num tabular-nums">{mitjanaCategoria.toFixed(3)}</div>
                <div class="cls-stat-lbl">Mitjana cat.</div>
              </div>
              <div>
                <div class="cls-stat-num cls-stat-date">
                  {#if lastMatchDate}
                    {lastMatchDate.toLocaleDateString('ca-ES', { day: 'numeric', month: 'short' })}
                  {:else}
                    —
                  {/if}
                </div>
                <div class="cls-stat-lbl">Última partida</div>
              </div>
            </div>
          {/if}
          {/if}
        {/if}
      </article>
    {/each}

    {#if selectedCategory === 'all' && filteredCategories.length > 1}
      <!-- Overall summary -->
      {@const totalJugadors = classifications.length}
      {@const totalPartides = classifications.reduce((sum, c) => sum + c.partides_jugades, 0) / 2}
      {@const totalCaramboles = classifications.reduce((sum, c) => sum + (c.caramboles_totals ?? 0), 0)}
      {@const totalEntrades = classifications.reduce((sum, c) => sum + (c.entrades_totals ?? 0), 0)}
      {@const mitjanaGeneral = totalEntrades > 0 ? (totalCaramboles / totalEntrades) : 0}

      <section class="cls-summary">
        <div class="editorial-eyebrow" style="margin-bottom: 0.65rem;">Resum general del campionat</div>
        <div class="cls-summary-strip">
          <div>
            <div class="cls-stat-num tabular-nums">{totalJugadors}</div>
            <div class="cls-stat-lbl">Jugadors inscrits</div>
          </div>
          <div>
            <div class="cls-stat-num tabular-nums">{Math.floor(totalPartides)}</div>
            <div class="cls-stat-lbl">Partides jugades</div>
          </div>
          <div>
            <div class="cls-stat-num tabular-nums">{totalCaramboles}</div>
            <div class="cls-stat-lbl">Caramboles totals</div>
          </div>
          <div>
            <div class="cls-stat-num tabular-nums">{mitjanaGeneral.toFixed(3)}</div>
            <div class="cls-stat-lbl">Mitjana general</div>
          </div>
        </div>
      </section>
    {/if}
  {/if}
</div>

<!-- Player Results Modal -->
<PlayerResultsModal
  bind:isOpen={isModalOpen}
  playerName={selectedPlayer?.name || ''}
  playerNumeroSoci={selectedPlayer?.numeroSoci}
  eventId={selectedPlayer?.eventId}
  categoriaId={selectedPlayer?.categoriaId}
  on:close={() => {
    isModalOpen = false;
    selectedPlayer = null;
  }}
/>

<style>
  .classifications-root {
    width: 100%;
    font-family: var(--font-sans);
    color: var(--ink);
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  /* ── Header ───────────────────────────────────────── */
  .cls-head {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    gap: 1.5rem;
    padding-bottom: 1rem;
    border-bottom: 2px solid var(--ink);
    flex-wrap: wrap;
  }
  .cls-title {
    font-weight: 800;
    font-size: 1.875rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    margin: 0;
    line-height: 1.1;
    font-variation-settings: 'opsz' 32;
  }
  .cls-controls { display: flex; align-items: center; gap: 0.65rem; }
  .cls-select {
    font-family: var(--font-sans);
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--ink);
    background: var(--paper-elevated);
    border: 1px solid var(--rule-strong);
    padding: 0.5rem 0.75rem;
    min-height: 44px;
    cursor: pointer;
  }

  /* ── Banner de freshness ──────────────────────────── */
  .cls-freshness {
    display: flex;
    align-items: center;
    gap: 0.65rem;
    padding: 0.55rem 0.85rem;
    background: var(--paper);
    border: 1px solid var(--rule);
    font-size: 0.8125rem;
    color: var(--ink-2);
    flex-wrap: wrap;
  }
  .freshness-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--green);
    animation: pulse-dot 2s ease-in-out infinite;
    flex-shrink: 0;
  }
  @keyframes pulse-dot {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }
  .freshness-text { flex: 1; }
  .freshness-text strong { color: var(--ink); font-weight: 700; }
  .freshness-refresh {
    background: transparent;
    border: 1px solid var(--rule-strong);
    padding: 0.4rem 0.7rem;
    font-family: var(--font-sans);
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--ink-2);
    cursor: pointer;
    letter-spacing: -0.005em;
  }
  .freshness-refresh:hover { color: var(--ink); border-color: var(--ink); }
  .freshness-refresh:disabled { opacity: 0.5; cursor: not-allowed; }

  /* ── Estats buits ─────────────────────────────────── */
  .state-empty {
    padding: 1.5rem 1.75rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    font-size: 0.9375rem;
  }
  .state-empty.error-state { color: var(--accent); }

  /* ── Cat-block (cada categoria) ───────────────────── */
  .cat-block {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    overflow: hidden;
  }
  .cat-header {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem 1.5rem;
    background: var(--paper-elevated);
    border: none;
    border-bottom: 1px solid var(--rule);
    cursor: pointer;
    text-align: left;
    color: var(--ink);
    font-family: var(--font-sans);
    transition: background 0.15s ease;
  }
  .cat-header:hover { background: var(--paper); }
  .cat-toggle-icon {
    font-size: 1.5rem;
    font-weight: 600;
    color: var(--ink-3);
    width: 1.5rem;
    text-align: center;
    line-height: 1;
  }
  .cat-name-block { flex: 1; }
  .cat-name {
    font-weight: 800;
    font-size: 1.375rem;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .cat-meta {
    margin-top: 0.25rem;
    font-size: 0.8125rem;
    color: var(--ink-3);
    font-weight: 500;
  }
  .cat-meta strong { color: var(--ink-2); font-weight: 700; }
  .cat-count-block { text-align: right; }
  .cat-count {
    font-weight: 800;
    font-size: 1.625rem;
    letter-spacing: -0.025em;
    line-height: 1;
  }
  .cat-count-label {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin-top: 0.25rem;
  }

  /* ── Taula desktop ────────────────────────────────── */
  .cls-table-wrap { overflow-x: auto; }
  .cls-table { width: 100%; border-collapse: collapse; }
  .cls-table th {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    text-align: right;
    padding: 0.875rem 0.6rem;
    border-bottom: 1px solid var(--rule);
    white-space: nowrap;
    background: var(--paper);
  }
  .cls-table th.col-left { text-align: left; }
  .cls-table th.col-pos { width: 4rem; padding-left: 1.25rem; }
  .cls-table th.col-player { padding-left: 0; }
  .cls-table th.col-pts-head { color: var(--ink); }
  .cls-table td {
    padding: 0.85rem 0.6rem;
    border-bottom: 1px solid var(--rule);
    text-align: right;
    font-size: 0.9375rem;
    font-weight: 500;
    color: var(--ink-2);
    vertical-align: middle;
  }
  .cls-table td.col-pos {
    text-align: left;
    padding-left: 1.25rem;
  }
  .cls-table td.col-left { text-align: left; padding-left: 0; }
  .cls-table tr:last-child td { border-bottom: none; }
  .cls-table tr:hover { background: rgba(0,0,0,0.02); }
  .cls-table tr.top3 .pos-num { color: var(--accent); }
  .cls-table tr.retired { opacity: 0.55; }
  .pos-num {
    font-weight: 700;
    font-size: 1.5rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    line-height: 1;
  }
  .player-cell {
    display: flex;
    align-items: center;
    gap: 0.6rem;
  }
  .player-name-btn {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    text-align: left;
    display: flex;
    flex-direction: column;
    line-height: 1.2;
    font-family: var(--font-sans);
  }
  .player-name-btn:hover .player-name-text {
    border-bottom-color: var(--ink);
  }
  .player-name-text {
    font-weight: 700;
    font-size: 1.0625rem;
    color: var(--ink);
    letter-spacing: -0.014em;
    border-bottom: 1px solid transparent;
    transition: border-color 0.15s ease;
  }
  .retired-name .player-name-text { text-decoration: line-through; color: var(--ink-3); }
  .retired-badge {
    display: inline-block;
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--accent);
    border: 1px solid var(--accent);
    padding: 0.15rem 0.4rem;
    margin-left: 0.4rem;
  }
  .col-pts-data { font-weight: 800; color: var(--ink); font-size: 1.125rem; letter-spacing: -0.02em; }

  /* ── Mobile compact ───────────────────────────────── */
  .cls-mobile { display: none; }
  .cls-mob-row {
    border-bottom: 1px solid var(--rule);
    padding: 0.85rem 1rem;
    background: var(--paper-elevated);
  }
  .cls-mob-row:last-child { border-bottom: none; }
  .cls-mob-row.top3 .cls-mob-pos { color: var(--accent); }
  .cls-mob-row.retired { opacity: 0.55; }
  .cls-mob-row.retired .cls-mob-name { text-decoration: line-through; }
  .cls-mob-head {
    display: flex;
    align-items: center;
    gap: 0.65rem;
  }
  .cls-mob-pos {
    font-weight: 700;
    font-size: 1.5rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    line-height: 1;
    width: 2.25rem;
    flex-shrink: 0;
  }
  .cls-mob-name-btn {
    flex: 1;
    background: transparent;
    border: none;
    padding: 0;
    text-align: left;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-family: var(--font-sans);
    color: var(--ink);
    min-width: 0;
  }
  .cls-mob-name {
    font-weight: 700;
    font-size: 0.9375rem;
    letter-spacing: -0.012em;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }
  .cls-mob-pts {
    flex-shrink: 0;
    text-align: right;
    line-height: 1;
  }
  .cls-mob-pts-num {
    font-weight: 800;
    font-size: 1.5rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    display: block;
  }
  .cls-mob-pts-lbl {
    font-size: 0.5625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--ink-3);
    margin-top: 2px;
    display: block;
  }
  .cls-mob-stats {
    margin-top: 0.6rem;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 0.25rem;
    text-align: center;
  }
  .cls-mob-stat-num {
    display: block;
    font-weight: 700;
    font-size: 0.875rem;
    color: var(--ink);
    letter-spacing: -0.012em;
  }
  .cls-mob-stat-lbl {
    display: block;
    font-size: 0.5625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--ink-3);
    margin-top: 2px;
  }

  /* ── Stats strip ──────────────────────────────────── */
  .cls-stats-strip {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    border-top: 1px solid var(--rule);
    background: var(--paper);
  }
  .cls-stats-strip > div {
    padding: 1rem 1.25rem;
    border-right: 1px solid var(--rule);
  }
  .cls-stats-strip > div:last-child { border-right: none; }
  .cls-stat-num {
    font-weight: 800;
    font-size: 1.5rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    line-height: 1;
  }
  .cls-stat-num.cls-stat-date { font-size: 1.0625rem; }
  .cls-stat-lbl {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3);
    margin-top: 0.4rem;
  }

  /* ── Resum general ────────────────────────────────── */
  .cls-summary {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.25rem 1.5rem 0;
  }
  .cls-summary-strip {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
  }
  .cls-summary-strip > div {
    padding: 1rem 0 1.25rem;
    border-right: 1px solid var(--rule);
    padding-left: 1.25rem;
  }
  .cls-summary-strip > div:first-child { padding-left: 0; }
  .cls-summary-strip > div:last-child { border-right: none; }

  /* ── Responsive ───────────────────────────────────── */
  @media (max-width: 768px) {
    .cls-head { gap: 0.75rem; align-items: flex-start; flex-direction: column; }
    .cls-controls { width: 100%; }
    .cls-select { width: 100%; }
    .cls-table-wrap { display: none; }
    .cls-mobile { display: block; }
    .cls-stats-strip,
    .cls-summary-strip {
      grid-template-columns: repeat(2, 1fr);
    }
    .cls-stats-strip > div:nth-child(2),
    .cls-summary-strip > div:nth-child(2) { border-right: none; }
    .cls-stats-strip > div:nth-child(1),
    .cls-stats-strip > div:nth-child(2),
    .cls-summary-strip > div:nth-child(1),
    .cls-summary-strip > div:nth-child(2) { border-bottom: 1px solid var(--rule); }
    .cat-header { padding: 0.85rem 1rem; }
    .cat-name { font-size: 1.125rem; }
  }

  /* ── High contrast ────────────────────────────────── */
  :global(.high-contrast) .cat-block,
  :global(.high-contrast) .state-empty,
  :global(.high-contrast) .cls-summary {
    background: #ffffff !important;
    border-color: #000000 !important;
  }
  :global(.high-contrast) .pos-num,
  :global(.high-contrast) .cls-mob-pos {
    color: #000000 !important;
  }
</style>
