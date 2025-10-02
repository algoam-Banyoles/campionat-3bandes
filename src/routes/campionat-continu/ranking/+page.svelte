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
    import { getPlayerChallengeHistory, type ChallengeResult } from '$lib/stores/playerChallengeHistory';

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
  let myPlayerId: string | null = null;
  let myPos: number | null = null;
  let eventId: string | null = null;
  let unsub: (() => void) | null = null;
  let modalPlayer: { id: string; name: string } | null = null;
  let supabaseClient: any;
  let penalModal = false;
  let selA: number | null = null;
  let selB: number | null = null;
  let penaltyError: string | null = null;
  let penaltyBusy = false;
  let highlightIds = new Set<string>();
  let shouldFetchBadges = !badgesLoaded;
  let badgeMap = new Map<string, VPlayerBadges>();
  let playerHistoryMap = new Map<string, ChallengeResult[]>();
  let intervalRef: NodeJS.Timeout;

  $: if (badgesLoaded) {
    badgeMap = new Map(badges.map((b) => [b.player_id, b]));
    shouldFetchBadges = false;
  }

  onMount(async () => {
    const refreshId = performanceMonitor.startMeasurement('ranking_page_load', 'component');
    
    try {
      const { supabase } = await import('$lib/supabaseClient');
      supabaseClient = supabase;

      // Subscriure's al store optimitzat
      unsub = ranking.subscribe((base) => {
        const rdata = base.slice(0, 20);
        rows = rdata.map((r) => ({
          ...r,
          canChallenge: false,
          reason: null,
          moved: highlightIds.has(r.player_id),
        }));
        
        // Si tenim dades, ja no estem carregant
        if (base.length > 0) {
          loading = false;
        }
        
        void loadBadges();
        void loadPlayerHistories();
        
        // Si ja tenim myPlayerId, evaluar challenges
        if (myPlayerId && supabaseClient) {
          void evaluateChallenges(supabaseClient);
        }
      });

      // Auth & player (optimal amb cache)
      const { data: auth } = await supabase.auth.getUser();
      if (auth?.user?.email) {
        const { data: player, error: pErr } = await supabase
          .from('players')
          .select('id')
          .eq('email', auth.user.email)
          .maybeSingle();
        if (pErr) {
          error = pErr.message;
          return;
        }
        if (player) {
          myPlayerId = player.id as string;
        }
      }

      // Event
      const { data: event, error: eErr } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .order('creat_el', { ascending: false })
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
      myPos = (get(ranking) as any).find((r: any) => r.player_id === myPlayerId)?.posicio ?? null;
      
      // Ara que tenim myPlayerId, podem evaluar els challenges
      if (myPlayerId) {
        void evaluateChallenges(supabaseClient);
      }

      // Configurar refresh automàtic cada 5 minuts
      intervalRef = setInterval(async () => {
        await refreshRanking();
        await refreshActiveChallenges();
      }, 5 * 60 * 1000);

    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
      performanceMonitor.endMeasurement(refreshId, 'ranking_page_load', 'component');
    }
  });

  onDestroy(() => {
    unsub?.();
    if (typeof intervalRef !== 'undefined') {
      clearInterval(intervalRef);
    }
  });

  async function evaluateChallenges(supabase: any) {
    myPos = rows.find((r) => r.player_id === myPlayerId)?.posicio ?? null;
    if (!(myPlayerId && myPos && eventId)) return;
    
    for (const r of rows) {
      if (r.player_id === myPlayerId) continue;
      
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
      const chk = await canCreateChallenge(supabase, eventId, myPlayerId, r.player_id);
      r.canChallenge = chk.ok;
      r.reason = chk.ok ? chk.warning : chk.reason;
    }
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
      const historyPromises = rows.map(async (row) => {
        const history = await getPlayerChallengeHistory(row.player_id, eventId!, 6);
        return { playerId: row.player_id, history };
      });
      
      const results = await Promise.all(historyPromises);
      const newHistoryMap = new Map<string, ChallengeResult[]>();
      
      results.forEach(({ playerId, history }) => {
        newHistoryMap.set(playerId, history);
      });
      
      playerHistoryMap = newHistoryMap;
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

  function reptar(id: string) {
    goto(`/reptes/nou?opponent=${id}`);
  }

  async function handleRefresh() {
    await Promise.all([
      refreshRanking(true), // Force refresh
      refreshActiveChallenges(),
      loadBadges(true)
    ]);
    await loadPlayerHistories();
  }

  function openEvolution(id: string, name: string) {
    modalPlayer = { id, name };
  }

  const fmtMitjana = (m: number | null) => (m == null ? '-' : String(m));
  const fmtEstat = (e: string | undefined | null) => (e ? e.replace('_', ' ') : '');

  async function applyPenalty() {
    if (!(eventId && selA && selB && Math.abs(selA - selB) === 1)) return;
    penaltyBusy = true;
    penaltyError = null;
    try {
      const before = get(ranking);
      const playerA = (before as any).find((r: any) => r.posicio === selA)?.player_id;
      const playerB = (before as any).find((r: any) => r.posicio === selB)?.player_id;
      if (!(playerA && playerB)) throw new Error('Selecció invàlida');
      await applyDisagreementDrop(supabaseClient, eventId, playerA, playerB);
      await refreshRanking();
      await loadBadges(true);
      await loadPlayerHistories();
      const after = get(ranking);
      const beforeMap = new Map((before as any).map((r: any) => [r.player_id, r.posicio]));
      highlightIds = new Set(
        (after as any)
          .filter((r: any) => beforeMap.get(r.player_id) !== r.posicio)
          .map((r) => r.player_id)
      );
      rows = (after as any).slice(0, 20).map((r: any) => ({
        ...r,
        canChallenge: false,
        reason: null,
        moved: highlightIds.has(r.player_id),
      }));
      await evaluateChallenges(supabaseClient);
      penalModal = false;
      setTimeout(() => {
        highlightIds = new Set();
        rows = rows.map((r) => ({ ...r, moved: false }));
      }, 3000);
    } catch (e: any) {
      penaltyError = e?.message ?? 'Error desconegut';
    } finally {
      penaltyBusy = false;
    }
  }
</script>

<svelte:head><title>Rànquing</title></svelte:head>

<PullToRefresh onRefresh={handleRefresh}>
<h1 class="text-xl font-semibold mb-4">Rànquing</h1>
{#if $adminStore}
  <button
    class="mb-4 rounded border px-3 py-1 text-sm"
    on:click={() => {
      penalModal = true;
      selA = selB = null;
      penaltyError = null;
    }}
  >
    Penalitzar desacord
  </button>
{/if}

{#if loading}
  <p class="text-slate-500">Carregant rànquing…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">Error: {error}</div>
{:else if rows.length === 0}
  <p class="text-slate-500">Encara no hi ha posicions al rànquing.</p>
{:else}
  <div class="overflow-x-auto rounded-xl border border-slate-200 shadow-sm">
    <table class="min-w-full">
      <thead class="bg-gradient-to-r from-blue-50 to-slate-50 border-b border-slate-200">
        <tr>
          <th class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left font-bold text-base sm:text-lg lg:text-xl xl:text-2xl text-slate-800">Pos.</th>
          <th class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left font-bold text-base sm:text-lg lg:text-xl xl:text-2xl text-slate-800">Jugador</th>
          {#if myPlayerId}
            <th class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left font-bold text-base sm:text-lg lg:text-xl xl:text-2xl text-slate-800 hidden sm:table-cell">Mitjana</th>
            <th class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left font-bold text-base sm:text-lg lg:text-xl xl:text-2xl text-slate-800 hidden sm:table-cell">Estat</th>
            <th class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left font-bold text-base sm:text-lg lg:text-xl xl:text-2xl text-slate-800">Accions</th>
          {:else}
            <th class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left font-bold text-base sm:text-lg lg:text-xl xl:text-2xl text-slate-800">Evolució</th>
          {/if}
        </tr>
      </thead>
      <tbody class="divide-y divide-slate-100">
        {#each rows as r, index}
          {@const badge = badgeMap.get(r.player_id)}
          {@const badgeView = getBadgeView(badge)}
          {@const displayName = r.nom ? formatPlayerDisplayName(r.nom, r.cognoms) : 'Desconegut'}
          {@const fullName = r.nom && r.cognoms ? `${r.nom} ${r.cognoms}` : r.nom || 'Desconegut'}
          {@const isTopThree = r.posicio <= 3}
          {@const isCurrentUser = r.player_id === myPlayerId}
          <tr class="hover:bg-slate-50 transition-colors duration-150" 
              class:bg-yellow-50={r.moved} 
              class:bg-blue-50={isCurrentUser}
              class:border-l-4={isTopThree}
              class:border-l-yellow-400={r.posicio === 1}
              class:border-l-gray-400={r.posicio === 2}
              class:border-l-orange-400={r.posicio === 3}>
            <td class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4">
              <span class="text-sm sm:text-base lg:text-lg font-bold" class:text-yellow-600={r.posicio === 1} class:text-gray-600={r.posicio === 2} class:text-orange-600={r.posicio === 3}>
                {r.posicio}
              </span>
            </td>
            <td class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4">
              <div class="flex items-center gap-2 sm:gap-3">
                <button
                  class="text-blue-700 hover:text-blue-900 hover:underline text-base sm:text-lg lg:text-xl xl:text-2xl font-semibold transition-colors"
                  on:click={() => openEvolution(r.player_id, fullName)}
                  class:font-bold={r.player_id === myPlayerId}
                  class:text-blue-900={isCurrentUser}
                  title={fullName}
                >
                  {displayName}
                </button>

                <!-- Badge només per identificar el jugador logat -->
                {#if r.player_id === myPlayerId}
                  <span
                    class="px-2 py-1 text-sm sm:text-base rounded-full bg-blue-100 text-blue-900 font-bold border-2 border-blue-300"
                    title="Aquest ets tu"
                  >
                    <span class="hidden sm:inline">Tu</span>
                    <span class="sm:hidden">👤</span>
                  </span>
                {/if}
              </div>
            </td>
            {#if myPlayerId}
              <td class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-base sm:text-lg lg:text-xl xl:text-2xl font-bold text-slate-800 hidden sm:table-cell">{fmtMitjana(r.mitjana)}</td>
              <td class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-base sm:text-lg lg:text-xl xl:text-2xl font-bold text-slate-800 capitalize hidden sm:table-cell">{fmtEstat(r.estat)}</td>
              <td class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4">
                {#if r.player_id !== myPlayerId}
                  <button
                    class="rounded-lg border-2 px-3 sm:px-4 py-2 text-sm sm:text-base lg:text-lg xl:text-xl font-bold transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                    class:border-green-500={r.canChallenge}
                    class:bg-green-50={r.canChallenge}
                    class:text-green-800={r.canChallenge}
                    class:hover:bg-green-100={r.canChallenge}
                    class:border-slate-300={!r.canChallenge}
                    class:bg-slate-50={!r.canChallenge}
                    class:text-slate-500={!r.canChallenge}
                    disabled={!r.canChallenge}
                    title={r.canChallenge ? 'Clic per reptar aquest jugador' : r.reason || 'No pots reptar aquest jugador'}
                    on:click={() => reptar(r.player_id)}
                  >
                    <span class="hidden sm:inline">⚔️ Reptar</span>
                    <span class="sm:hidden">⚔️</span>
                  </button>
                {/if}
              </td>
            {:else}
              <td class="px-3 sm:px-4 lg:px-6 py-3 sm:py-4">
                <PlayerEvolutionBadges results={playerHistoryMap.get(r.player_id) || []} />
              </td>
            {/if}
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
  {#if modalPlayer}
    <PlayerEvolutionModal
      playerId={modalPlayer.id}
      playerName={modalPlayer.name}
      on:close={() => (modalPlayer = null)}
    />
  {/if}
  {#if penalModal}
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div class="w-full max-w-sm rounded bg-white p-4">
        <h2 class="mb-2 font-semibold">Penalitzar desacord</h2>
        {#if penaltyError}
          <div class="mb-2 rounded border border-red-200 bg-red-50 p-2 text-red-700">
            {penaltyError}
          </div>
        {/if}
        <div class="mb-2">
          <label class="block text-sm mb-1" for="penal-a">Posició A</label>
          <select id="penal-a" bind:value={selA} class="w-full rounded border p-1">
            <option value={null} disabled selected>Selecciona posició</option>
            {#each rows as r}
              {@const displayName = r.nom ? formatPlayerDisplayName(r.nom, r.cognoms) : 'Desconegut'}
              {@const fullName = r.nom && r.cognoms ? `${r.nom} ${r.cognoms}` : r.nom || 'Desconegut'}
              <option value={r.posicio} title={fullName}>
                {r.posicio} - {displayName}
              </option>
            {/each}
          </select>
        </div>
        <div class="mb-2">
          <label class="block text-sm mb-1" for="penal-b">Posició B</label>
          <select id="penal-b" bind:value={selB} class="w-full rounded border p-1">
            <option value={null} disabled selected>Selecciona posició</option>
            {#each rows as r}
              {@const displayName = r.nom ? formatPlayerDisplayName(r.nom, r.cognoms) : 'Desconegut'}
              {@const fullName = r.nom && r.cognoms ? `${r.nom} ${r.cognoms}` : r.nom || 'Desconegut'}
              <option value={r.posicio} title={fullName}>
                {r.posicio} - {displayName}
              </option>
            {/each}
          </select>
        </div>
        <p class="mb-2 text-sm text-slate-500">Han de ser consecutives</p>
        <div class="flex justify-end gap-2">
          <button class="px-3 py-1" on:click={() => (penalModal = false)}>Cancel·lar</button>
          <button
            class="rounded border px-3 py-1 disabled:opacity-50"
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
</PullToRefresh>
