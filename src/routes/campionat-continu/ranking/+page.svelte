<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { goto } from '$app/navigation';
    import { get } from 'svelte/store';
    import { canCreateChallenge } from '$lib/canCreateChallenge';
    import { ranking, refreshRanking, invalidateRankingCache, type RankingRow } from '$lib/stores/rankingStore';
    import { activeChallenges, refreshActiveChallenges } from '$lib/stores/challengeStore';
    import { performanceMonitor } from '$lib/monitoring/performance';
    import { type VPlayerBadges } from '$lib/playerBadges';
    import { fetchBadgeMap, getBadgeView } from '$lib/badgeView';
    import PlayerEvolutionModal from '$lib/components/campionat-continu/PlayerEvolutionModal.svelte';
    import { adminStore } from '$lib/stores/auth';
    import { applyDisagreementDrop } from '$lib/applyDisagreementDrop';
    import PullToRefresh from '$lib/components/general/gestures/PullToRefresh.svelte';
    import { formatPlayerDisplayName } from '$lib/utils/playerName';
    import PlayerEvolutionBadges from '$lib/components/campionat-continu/PlayerEvolutionBadges.svelte';
    import { getPlayerChallengeHistoriesBatch, type ChallengeResult } from '$lib/stores/playerChallengeHistory';
    import { mySociNumero as mySociStore } from '$lib/stores/mySoci';

  export let badges: VPlayerBadges[] = [];
  export let badgesLoaded = false;

  type RowState = RankingRow & {
    canChallenge: boolean;
    reason: string | null;
    moved: boolean;
  };

  let loading = true;
  let error: string | null = null;
  let rows: RowState[] = [];
  let mySociNumero: number | null = null;
  let myPos: number | null = null;
  let eventId: string | null = null;
  let unsub: (() => void) | null = null;
  let modalPlayer: { sociNumero: number; name: string } | null = null;
  let supabaseClient: any;
  let penalModal = false;
  let selA: number | null = null;
  let selB: number | null = null;
  let penaltyError: string | null = null;
  let penaltyBusy = false;
  let highlightSociNums = new Set<number>();
  let shouldFetchBadges = !badgesLoaded;
  let badgeMap = new Map<number, VPlayerBadges>();
  let playerHistoryMap = new Map<number, ChallengeResult[]>();
  let intervalRef: NodeJS.Timeout;
  let cancelled = false;
  let realtimeChannel: ReturnType<typeof import('$lib/supabaseClient').supabase.channel> | null = null;

  $: if (badgesLoaded) {
    badgeMap = new Map(badges.map((b) => [b.soci_numero, b]));
    shouldFetchBadges = false;
  }

  onMount(async () => {
    const refreshId = performanceMonitor.startMeasurement('ranking_page_load', 'component');
    
    try {
      const { supabase } = await import('$lib/supabaseClient');
      supabaseClient = supabase;

      // Subscriure's al store optimitzat
      unsub = ranking.subscribe((base) => {
        if (cancelled) return;
        const rdata = base.slice(0, 20);
        rows = rdata.map((r) => ({
          ...r,
          canChallenge: false,
          reason: null,
          moved: highlightSociNums.has(r.soci_numero),
        }));

        // Si tenim dades, ja no estem carregant
        if (base.length > 0) {
          loading = false;
        }

        void loadBadges();
        void loadPlayerHistories();

        // Si ja tenim mySociNumero, evaluar challenges
        if (mySociNumero && supabaseClient) {
          void evaluateChallenges(supabaseClient);
        }
      });

      // Auth & soci_numero — usem el store centralitzat (resol via socis.email)
      mySociNumero = get(mySociStore);
      // Si encara no està resolt (login recent), espera la propera emissió
      if (mySociNumero == null) {
        await new Promise<void>((resolve) => {
          const u = mySociStore.subscribe((v) => {
            if (v != null) {
              mySociNumero = v;
              u();
              resolve();
            }
          });
          // Timeout per no bloquejar si l'usuari no està loggat
          setTimeout(() => { u(); resolve(); }, 2000);
        });
      }

      // Event
      const { data: event, error: eErr } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .eq('tipus_competicio', 'ranking_continu')
        .order('data_inici', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (eErr) {
        error = eErr.message;
        return;
      }
      if (!event) {
        error = 'No hi ha cap esdeveniment actiu';
        return;
      }
      eventId = event.id as string;

      // Carregar dades inicials amb cache optimitzat
      await Promise.all([
        refreshRanking(),
        refreshActiveChallenges()
      ]);
      
      void loadBadges();
      myPos = (get(ranking) as any).find((r: any) => r.soci_numero === mySociNumero)?.posicio ?? null;

      // Ara que tenim mySociNumero, podem evaluar els challenges
      if (mySociNumero) {
        void evaluateChallenges(supabaseClient);
      }

      // Realtime: subscriu-se a canvis de posició perquè el ranking es
      // refresqui immediatament quan algú entra un resultat (en lloc d'esperar
      // el setInterval de 5 min). Mantenim el setInterval com a fallback.
      realtimeChannel = supabase
        .channel(`ranking-${eventId}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'history_position_changes',
            filter: `event_id=eq.${eventId}`
          },
          () => {
            if (cancelled) return;
            void refreshRanking();
          }
        )
        .subscribe();

      // Fallback: refresh automàtic cada 5 minuts (per si la connexió realtime cau)
      intervalRef = setInterval(async () => {
        if (cancelled) return;
        await refreshRanking();
        if (cancelled) return;
        await refreshActiveChallenges();
      }, 5 * 60 * 1000);

    } catch (e: any) {
      if (!cancelled) error = e?.message ?? 'Error desconegut';
    } finally {
      if (!cancelled) loading = false;
      performanceMonitor.endMeasurement(refreshId, 'ranking_page_load', 'component');
    }
  });

  onDestroy(() => {
    cancelled = true;
    unsub?.();
    unsub = null;
    if (typeof intervalRef !== 'undefined') {
      clearInterval(intervalRef);
    }
    realtimeChannel?.unsubscribe();
    realtimeChannel = null;
  });

  async function evaluateChallenges(supabase: any) {
    myPos = rows.find((r) => r.soci_numero === mySociNumero)?.posicio ?? null;
    if (!(mySociNumero && myPos && eventId)) return;

    for (const r of rows) {
      if (r.soci_numero === mySociNumero) continue;
      
      // Verificar restriccions de posició
      if (r.posicio >= myPos) {
        r.canChallenge = false;
        r.reason = 'Només pots reptar jugadors per sobre teu al rànquing';
        continue;
      }
      
      if (myPos - r.posicio > 2) {
        r.canChallenge = false;
        r.reason = 'Només fins a 2 posicions per sobre';
        continue;
      }
      
      // Verificar altres restriccions (cooldown, etc.)
      const chk = await canCreateChallenge(supabase, eventId, mySociNumero, r.soci_numero);
      r.canChallenge = chk.ok;
      r.reason = chk.ok ? chk.warning : chk.reason;
    }
    // Força reactivitat de Svelte (mutació in-place no la detecta)
    rows = rows;
  }

  async function loadBadges(force = false): Promise<void> {
    if (!force && !shouldFetchBadges) {
      return;
    }
    try {
      badgeMap = await fetchBadgeMap();
      shouldFetchBadges = false;
    } catch {
      if (force || shouldFetchBadges) {
        shouldFetchBadges = true;
      }
    }
  }

  async function loadPlayerHistories(): Promise<void> {
    if (!eventId || rows.length === 0) return;

    try {
      // Una sola query batch per a tots els 20 jugadors del top, en lloc de 20 queries paral·leles.
      const sociNumeros = rows.map((r) => r.soci_numero);
      playerHistoryMap = await getPlayerChallengeHistoriesBatch(sociNumeros, eventId, 6);
    } catch (error) {
      console.error('Error loading player histories:', error);
    }
  }

  // Forçar refresh complet amb invalidació de cache
  async function forceRefresh(): Promise<void> {
    try {
      loading = true;
      error = null;
      
      // Invalidar tots els caches relacionats
      invalidateRankingCache();
      
      // Actualitzar dades
      await Promise.all([
        refreshRanking(true), // Force refresh
        refreshActiveChallenges(),
        loadBadges(true)
      ]);
      
      await loadPlayerHistories();
      
    } catch (e: any) {
      error = e?.message ?? 'Error actualitzant dades';
    } finally {
      loading = false;
    }
  }

  const badgeTooltip = (badge: VPlayerBadges | undefined): string | undefined => {
    if (!badge || badge.days_since_last == null) return undefined;
    if (badge.days_since_last === 0) return "Últim repte: avui";
    if (badge.days_since_last === 1) return "Últim repte: fa 1 dia";
    return `Últim repte: fa ${badge.days_since_last} dies`;
  };

  function reptar(sociNumero: number) {
    goto(`/campionat-continu/reptes/nou?opponent_soci=${sociNumero}`);
  }

  async function handleRefresh() {
    await Promise.all([
      refreshRanking(true), // Force refresh
      refreshActiveChallenges(),
      loadBadges(true)
    ]);
    await loadPlayerHistories();
  }

  function openEvolution(sociNumero: number, name: string) {
    modalPlayer = { sociNumero, name };
  }

  const fmtMitjana = (m: number | null) => (m == null ? '-' : String(m));
  const fmtEstat = (e: string | undefined | null) => (e ? e.replace('_', ' ') : '');

  async function applyPenalty() {
    if (!(eventId && selA && selB && Math.abs(selA - selB) === 1)) return;
    penaltyBusy = true;
    penaltyError = null;
    try {
      const before = get(ranking);
      const sociA = (before as any).find((r: any) => r.posicio === selA)?.soci_numero;
      const sociB = (before as any).find((r: any) => r.posicio === selB)?.soci_numero;
      if (!(sociA && sociB)) throw new Error('Selecció invàlida');
      await applyDisagreementDrop(supabaseClient, eventId, sociA, sociB);
      await refreshRanking();
      await loadBadges(true);
      await loadPlayerHistories();
      const after = get(ranking);
      const beforeMap = new Map((before as any).map((r: any) => [r.soci_numero, r.posicio]));
      highlightSociNums = new Set(
        (after as any)
          .filter((r: any) => beforeMap.get(r.soci_numero) !== r.posicio)
          .map((r: any) => r.soci_numero)
      );
      rows = (after as any).slice(0, 20).map((r: any) => ({
        ...r,
        canChallenge: false,
        reason: null,
        moved: highlightSociNums.has(r.soci_numero),
      }));
      await evaluateChallenges(supabaseClient);
      penalModal = false;
      setTimeout(() => {
        highlightSociNums = new Set<number>();
        rows = rows.map((r) => ({ ...r, moved: false }));
      }, 3000);
    } catch (e: any) {
      penaltyError = e?.message ?? 'Error desconegut';
    } finally {
      penaltyBusy = false;
    }
  }
</script>

<svelte:head><title>Rànquing — Campionat Continu</title></svelte:head>

<PullToRefresh onRefresh={handleRefresh}>
<div class="ranking-root">
  <header class="page-mast">
    <div>
      <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Campionat continu</div>
      <h1 class="page-title">Rànquing</h1>
    </div>
    {#if $adminStore}
      <button
        class="btn-action"
        on:click={() => {
          penalModal = true;
          selA = selB = null;
          penaltyError = null;
        }}
      >
        Penalitzar desacord
      </button>
    {/if}
  </header>

  {#if loading}
    <div class="state-empty">Carregant rànquing…</div>
  {:else if error}
    <div class="state-empty error-state">Error: {error}</div>
  {:else if rows.length === 0}
    <div class="state-empty">Encara no hi ha posicions al rànquing.</div>
  {:else}
    <div class="ranking-table-wrap">
      <table class="ranking-table">
        <thead>
          <tr>
            <th class="col-pos">Pos</th>
            <th class="col-left">Jugador</th>
            <th class="col-left">Evolució</th>
            {#if mySociNumero}
              <th class="col-actions">Accions</th>
            {/if}
          </tr>
        </thead>
        <tbody>
          {#each rows as r}
            {@const badge = badgeMap.get(r.soci_numero)}
            {@const badgeView = getBadgeView(badge)}
            {@const displayName = r.nom ? formatPlayerDisplayName(r.nom, r.cognoms) : 'Desconegut'}
            {@const fullName = r.nom && r.cognoms ? `${r.nom} ${r.cognoms}` : r.nom || 'Desconegut'}
            {@const isCurrentUser = r.soci_numero === mySociNumero}
            <tr
              class:row-moved={r.moved}
              class:row-mine={isCurrentUser}
              class:row-top1={r.posicio === 1}
              class:row-top2={r.posicio === 2}
              class:row-top3={r.posicio === 3}
            >
              <td class="col-pos">
                <span class="pos-num tabular-nums">{r.posicio.toString().padStart(2, '0')}</span>
              </td>
              <td class="col-left">
                <div class="player-cell">
                  <button
                    class="player-name-btn"
                    on:click={() => openEvolution(r.soci_numero, fullName)}
                    class:is-mine={isCurrentUser}
                    title={fullName}
                  >
                    {displayName}
                  </button>
                  {#if isCurrentUser}
                    <span class="badge-mine" title="Aquest ets tu">Tu</span>
                  {/if}
                </div>
              </td>
              <td class="col-left">
                <PlayerEvolutionBadges results={playerHistoryMap.get(r.soci_numero) || []} />
              </td>
              {#if mySociNumero}
                <td class="col-actions">
                  {#if r.soci_numero !== mySociNumero}
                    <button
                      class="btn-challenge"
                      class:can={r.canChallenge}
                      disabled={!r.canChallenge}
                      title={r.canChallenge ? 'Clic per reptar aquest jugador' : r.reason || 'No pots reptar aquest jugador'}
                      on:click={() => reptar(r.soci_numero)}
                    >
                      Reptar →
                    </button>
                  {/if}
                </td>
              {/if}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if modalPlayer}
      <PlayerEvolutionModal
        sociNumero={modalPlayer.sociNumero}
        playerName={modalPlayer.name}
        on:close={() => (modalPlayer = null)}
      />
    {/if}

    {#if penalModal}
      <div class="modal-root">
        <div class="modal-overlay" on:click={() => (penalModal = false)} role="presentation"></div>
        <div class="modal-card">
          <div class="modal-head">
            <div>
              <div class="editorial-eyebrow">Admin</div>
              <h2 class="modal-title">Penalitzar desacord</h2>
            </div>
          </div>
          <div class="modal-body">
            {#if penaltyError}
              <div class="msg-error">{penaltyError}</div>
            {/if}
            <div class="form-field">
              <label for="penal-a">Posició A</label>
              <select id="penal-a" bind:value={selA} class="filter-input">
                <option value={null} disabled selected>Selecciona posició</option>
                {#each rows as r}
                  {@const displayName = r.nom ? formatPlayerDisplayName(r.nom, r.cognoms) : 'Desconegut'}
                  {@const fullName = r.nom && r.cognoms ? `${r.nom} ${r.cognoms}` : r.nom || 'Desconegut'}
                  <option value={r.posicio} title={fullName}>
                    {r.posicio} — {displayName}
                  </option>
                {/each}
              </select>
            </div>
            <div class="form-field">
              <label for="penal-b">Posició B</label>
              <select id="penal-b" bind:value={selB} class="filter-input">
                <option value={null} disabled selected>Selecciona posició</option>
                {#each rows as r}
                  {@const displayName = r.nom ? formatPlayerDisplayName(r.nom, r.cognoms) : 'Desconegut'}
                  {@const fullName = r.nom && r.cognoms ? `${r.nom} ${r.cognoms}` : r.nom || 'Desconegut'}
                  <option value={r.posicio} title={fullName}>
                    {r.posicio} — {displayName}
                  </option>
                {/each}
              </select>
            </div>
            <p class="modal-note">Han de ser posicions consecutives.</p>
          </div>
          <div class="modal-actions">
            <button class="btn-secondary" on:click={() => (penalModal = false)}>Cancel·lar</button>
            <button
              class="btn-primary btn-danger"
              on:click={applyPenalty}
              disabled={!selA || !selB || Math.abs(selA - selB) !== 1 || penaltyBusy}
            >
              {penaltyBusy ? 'Aplicant…' : 'Aplicar penalització'}
            </button>
          </div>
        </div>
      </div>
    {/if}
  {/if}
</div>
</PullToRefresh>

<style>
  .ranking-root {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }

  /* Mast-head */
  .page-mast {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    gap: 1rem;
    padding-bottom: 1rem;
    border-bottom: 2px solid var(--ink);
    flex-wrap: wrap;
  }
  .editorial-eyebrow {
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.16em;
    text-transform: uppercase;
    color: var(--sec-continu);
  }
  .page-title {
    font-weight: 800;
    font-size: 2rem;
    letter-spacing: -0.025em;
    line-height: 1.05;
    margin: 0;
    color: var(--ink);
  }
  .btn-action {
    background: transparent;
    color: var(--ink);
    border: 1px solid var(--rule-strong);
    padding: 0.5rem 0.9rem;
    font-family: var(--font-sans);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    min-height: 40px;
  }
  .btn-action:hover { border-color: var(--ink); }

  /* Estats */
  .state-empty {
    padding: 1.75rem 2rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    text-align: center;
  }
  .state-empty.error-state { color: var(--accent); border-color: var(--accent); }

  /* Taula del rànquing */
  .ranking-table-wrap {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    overflow-x: auto;
  }
  .ranking-table {
    width: 100%;
    border-collapse: collapse;
  }
  .ranking-table th {
    font-size: 0.625rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--ink-3);
    padding: 0.85rem;
    border-bottom: 1px solid var(--rule);
    white-space: nowrap;
    background: var(--paper);
  }
  .ranking-table th.col-left { text-align: left; }
  .ranking-table th.col-pos { text-align: left; width: 4rem; padding-left: 1.25rem; }
  .ranking-table th.col-actions { text-align: right; }
  .ranking-table td {
    padding: 0.85rem;
    border-bottom: 1px solid var(--rule);
    font-size: 0.9375rem;
    color: var(--ink);
    vertical-align: middle;
  }
  .ranking-table td.col-pos { padding-left: 1.25rem; }
  .ranking-table td.col-actions { text-align: right; }
  .ranking-table tr:last-child td { border-bottom: none; }
  .ranking-table tr:hover { background: var(--paper); }

  /* Estats de fila */
  .ranking-table tr.row-moved {
    background: linear-gradient(90deg, rgba(163, 107, 28, 0.1), transparent 60%);
  }
  .ranking-table tr.row-mine {
    background: linear-gradient(90deg, rgba(163, 11, 30, 0.05), transparent 65%);
  }
  .ranking-table tr.row-top1 td.col-pos .pos-num { color: var(--accent); }
  .ranking-table tr.row-top2 td.col-pos .pos-num { color: var(--ink); }
  .ranking-table tr.row-top3 td.col-pos .pos-num { color: var(--amber); }

  .pos-num {
    font-weight: 800;
    font-size: 1.5rem;
    letter-spacing: -0.025em;
    color: var(--ink);
    line-height: 1;
  }

  .player-cell {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    flex-wrap: wrap;
  }
  .player-name-btn {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: var(--font-sans);
    font-weight: 700;
    font-size: 1.0625rem;
    color: var(--ink);
    letter-spacing: -0.014em;
    text-align: left;
    border-bottom: 1px solid transparent;
  }
  .player-name-btn:hover { border-bottom-color: var(--ink); }
  .player-name-btn.is-mine { color: var(--accent); }
  .badge-mine {
    display: inline-block;
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.14em;
    color: var(--accent);
    border: 1px solid var(--accent);
    padding: 0.18rem 0.45rem;
  }

  .btn-challenge {
    background: transparent;
    border: 1px solid var(--rule);
    color: var(--ink-3);
    padding: 0.45rem 0.85rem;
    font-family: var(--font-sans);
    font-weight: 700;
    font-size: 0.8125rem;
    letter-spacing: -0.005em;
    cursor: pointer;
    min-height: 40px;
  }
  .btn-challenge.can {
    color: var(--green);
    border-color: var(--green);
  }
  .btn-challenge.can:hover {
    background: var(--green);
    color: white;
  }
  .btn-challenge:disabled { cursor: not-allowed; opacity: 0.4; }

  /* Modal */
  .modal-root { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 1rem; }
  .modal-overlay { position: absolute; inset: 0; background: rgba(26, 24, 20, 0.55); }
  .modal-card {
    position: relative; z-index: 10; max-width: 26rem; width: 100%;
    background: var(--paper-elevated); border: 1px solid var(--rule);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.18);
    max-height: 90vh; overflow-y: auto;
    font-family: var(--font-sans); color: var(--ink);
  }
  .modal-head {
    padding: 1rem 1.5rem;
    border-bottom: 2px solid var(--ink);
  }
  .modal-title {
    font-weight: 800; font-size: 1.125rem;
    letter-spacing: -0.018em; margin: 0.25rem 0 0;
  }
  .modal-body {
    padding: 1.25rem 1.5rem;
    display: flex; flex-direction: column; gap: 1rem;
  }
  .form-field { display: flex; flex-direction: column; gap: 0.35rem; }
  .form-field label { font-size: 0.75rem; font-weight: 600; color: var(--ink-2); }
  .filter-input {
    padding: 0.55rem 0.75rem;
    background: var(--paper-elevated); border: 1px solid var(--rule-strong);
    color: var(--ink); font-family: var(--font-sans);
    font-size: 0.9375rem; min-height: 44px;
  }
  .filter-input:focus { outline: 2px solid var(--ink); outline-offset: 1px; border-color: var(--ink); }
  .modal-note { margin: 0; font-size: 0.8125rem; color: var(--ink-3); }
  .msg-error {
    padding: 0.65rem 0.85rem;
    color: var(--accent);
    border-left: 3px solid var(--accent);
    background: rgba(163, 11, 30, 0.05);
    font-size: 0.875rem;
  }
  .modal-actions {
    display: flex; justify-content: flex-end; gap: 0.5rem;
    padding: 1rem 1.5rem; border-top: 1px solid var(--rule);
  }
  .btn-secondary {
    padding: 0.55rem 1rem; background: transparent;
    border: 1px solid var(--rule-strong); color: var(--ink);
    font-family: var(--font-sans); font-weight: 600; font-size: 0.875rem;
    cursor: pointer; min-height: 44px;
  }
  .btn-secondary:hover { border-color: var(--ink); }
  .btn-primary {
    padding: 0.55rem 1rem;
    background: var(--ink); border: 1px solid var(--ink);
    color: var(--paper); font-family: var(--font-sans);
    font-weight: 600; font-size: 0.875rem; cursor: pointer; min-height: 44px;
  }
  .btn-primary:hover { opacity: 0.92; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary.btn-danger {
    background: var(--accent); border-color: var(--accent);
  }

  @media (max-width: 640px) {
    .page-title { font-size: 1.625rem; }
    .ranking-table th, .ranking-table td { padding: 0.6rem 0.5rem; }
    .ranking-table th.col-pos, .ranking-table td.col-pos { padding-left: 0.85rem; }
    .pos-num { font-size: 1.25rem; }
    .player-name-btn { font-size: 0.9375rem; }
  }
</style>
