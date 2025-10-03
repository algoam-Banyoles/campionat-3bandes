<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { canCreateChallenge } from '$lib/canCreateChallenge';
  import { formatPlayerDisplayName } from '$lib/utils/playerName';
  import { ranking, refreshRanking, type RankingRow } from '$lib/stores/rankingStore';
  import { get } from 'svelte/store';

  type Row = RankingRow & {
    event_id?: string;
    // Si vols afegir camps extra, afegeix-los aquí i a la funció SQL
    isMe?: boolean;
    hasActiveChallenge?: boolean;
    cooldownToChallenge?: boolean;
    cooldownToBeChallenged?: boolean;
    cooldownDaysLeft?: number;
    reptable?: boolean;
    canChallenge?: boolean;
    generallyChallengeable?: boolean;
    reason?: string | null;
    protected?: boolean;
    outside?: boolean;
    mitjanaHistorica?: number | null; // Mitjana d'accés (millor entre 2024-2025)
  };

  const fmtSafe = (iso: string | null): string => {
    if (!iso) return '—';
    const d = new Date(iso);
    return isNaN(d.getTime()) ? '—' : d.toLocaleDateString();
  };

  let loading = true;
  let error: string | null = null;
  let rows: Row[] = [];
  let myPlayerId: string | null = null;

  onMount(async () => {
    try {
      const { supabase } = await import('$lib/supabaseClient');

      const { data: auth } = await supabase.auth.getUser();
      if (auth?.user?.email) {
        const { data: player } = await supabase
          .from('players')
          .select('id')
          .eq('email', auth.user.email)
          .maybeSingle();
        myPlayerId = (player as any)?.id ?? null;
      }

      // Usar el mateix sistema que /ranking per consistència
      await refreshRanking();
      const rankingData = get(ranking);

      if ((rankingData as RankingRow[]).length === 0) {
        error = 'No hi ha dades de classificació disponibles';
      } else {
        rows = (rankingData as RankingRow[]).map((r) => ({
          ...r,
          isMe: myPlayerId === r.player_id,
          hasActiveChallenge: false,
          cooldownToChallenge: false,
          cooldownToBeChallenged: false,
          reptable: false,
          canChallenge: false,
          reason: null,
          protected: false,
          outside: r.posicio == null || r.posicio > 20
        }));

        // Obtenir event_id
        const { data: event } = await supabase
          .from('events')
          .select('id')
          .eq('actiu', true)
          .order('creat_el', { ascending: false })
          .limit(1)
          .maybeSingle();

        const eventId = event?.id;

        // Carregar mitjanes històriques per jugadors sense mitjana actual
        await loadHistoricalAverages(supabase, rows);

        await evaluateBadges(supabase, rows, eventId, myPlayerId);

        // trigger reactivity after in-place badge updates
        rows = [...rows];
      }
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });

  
  async function loadHistoricalAverages(supabase: any, rows: Row[]): Promise<void> {
    // Jugadors sense mitjana actual que necessiten mitjana històrica
    const playersNeedingHistory = rows
      .filter(r => r.mitjana === null)
      .map(r => r.player_id);

    if (playersNeedingHistory.length === 0) return;

    // Obtenir numero_soci per cada player_id
    const { data: playerSocis } = await supabase
      .from('players')
      .select('id, numero_soci')
      .in('id', playersNeedingHistory);

    if (!playerSocis) return;

    const sociIds = playerSocis
      .filter(p => p.numero_soci)
      .map(p => p.numero_soci);

    if (sociIds.length === 0) return;

    // Obtenir la millor mitjana de 3 bandes entre 2024 i 2025
    const { data: mitjanes } = await supabase
      .from('mitjanes_historiques')
      .select('soci_id, mitjana')
      .in('soci_id', sociIds)
      .eq('modalitat', '3 Bandes')
      .in('year', [2024, 2025])
      .not('mitjana', 'is', null)
      .order('mitjana', { ascending: false });

    if (!mitjanes) return;

    // Crear mapa de soci_id -> millor mitjana
    const millorsMyitjanes = new Map<number, number>();
    mitjanes.forEach(m => {
      const currentBest = millorsMyitjanes.get(m.soci_id);
      if (!currentBest || m.mitjana > currentBest) {
        millorsMyitjanes.set(m.soci_id, m.mitjana);
      }
    });

    // Crear mapa de player_id -> numero_soci
    const playerToSoci = new Map<string, number>();
    playerSocis.forEach(p => {
      if (p.numero_soci) playerToSoci.set(p.id, p.numero_soci);
    });

    // Assignar mitjanes històriques als jugadors
    rows.forEach(r => {
      if (r.mitjana === null) {
        const sociId = playerToSoci.get(r.player_id);
        if (sociId) {
          r.mitjanaHistorica = millorsMyitjanes.get(sociId) || null;
        }
      }
    });
  }


  async function evaluateBadges(
    supabase: any,
    rows: Row[],
    eventId: string | undefined,
    myPlayerId: string | null
  ): Promise<void> {
    if (!eventId) return;

    const MAX_UP_CHALLENGE = 2;
    const COOLDOWN_DAYS = 7;

    const byId = new Map<string, Row>();
    rows.forEach((r) => byId.set(r.player_id, r));

    // Active challenges
    const { data: active } = await supabase
      .from('challenges')
      .select('reptador_id, reptat_id')
      .eq('event_id', eventId)
      .in('estat', ['proposat', 'acceptat']);
    const activeIds = new Set<string>();
    (active as any[] ?? []).forEach((c) => {
      activeIds.add((c as any).reptador_id);
      activeIds.add((c as any).reptat_id);
    });
    activeIds.forEach((id) => {
      const row = byId.get(id);
      if (row) row.hasActiveChallenge = true;
    });

    // Last challenge info - simplified approach using matches table
    const { data: allMatches } = await supabase
      .from('matches')
      .select(`
        challenge_id, 
        data_partida,
        challenges!inner(
          event_id, 
          reptador_id, 
          reptat_id, 
          estat,
          data_acceptacio,
          data_proposta
        )
      `)
      .eq('challenges.event_id', eventId);
    
    const lastMap = new Map<string, any>();
    
    // Process matches to find last challenge for each player
    (allMatches as any[] ?? []).forEach((match) => {
      const c = match.challenges;
      const matchDate = match.data_partida || c.data_acceptacio || c.data_proposta;
      
      // For challenger
      const currentChallenger = lastMap.get(c.reptador_id);
      if (!currentChallenger || new Date(matchDate) > new Date(currentChallenger.last_challenge_date)) {
        lastMap.set(c.reptador_id, {
          player_id: c.reptador_id,
          last_challenge_date: matchDate,
          last_challenge_outcome: c.estat === 'refusat' ? 'REFUSED' : 'COMPLETED',
          was_challenger: true
        });
      }
      
      // For challenged
      const currentChallenged = lastMap.get(c.reptat_id);
      if (!currentChallenged || new Date(matchDate) > new Date(currentChallenged.last_challenge_date)) {
        lastMap.set(c.reptat_id, {
          player_id: c.reptat_id,
          last_challenge_date: matchDate,
          last_challenge_outcome: c.estat === 'refusat' ? 'REFUSED' : 'COMPLETED',
          was_challenger: false
        });
      }
    });

    const now = Date.now();
    rows.forEach((r) => {
      const lc = lastMap.get(r.player_id);
      r.cooldownToChallenge = false;
      r.cooldownToBeChallenged = false;
      r.cooldownDaysLeft = 0;
      if (lc?.last_challenge_date) {
        const dt = new Date(lc.last_challenge_date);
        const diff = (now - dt.getTime()) / (1000 * 60 * 60 * 24);
        if (diff < COOLDOWN_DAYS) {
          r.cooldownToChallenge = true;
          r.cooldownToBeChallenged = true;
          r.cooldownDaysLeft = Math.ceil(COOLDOWN_DAYS - diff);
          if (lc.last_challenge_outcome === 'REFUSED' && lc.was_challenger) {
            r.cooldownToChallenge = false;
          }
        }
      }
      r.protected =
        r.cooldownToBeChallenged && !r.hasActiveChallenge && !r.cooldownToChallenge;
    });

    const ranking = rows.filter((r) => r.posicio != null && r.posicio <= 20);
    const byPos = new Map<number, Row>();
    ranking.forEach((r) => byPos.set(r.posicio as number, r));
    const waiting = rows.filter((r) => r.posicio == null || r.posicio > 20);

    const myRow = myPlayerId ? byId.get(myPlayerId) : null;
    const myPos = myRow?.posicio ?? null;
    const canIChallenge = !!(
      myRow &&
      !myRow.hasActiveChallenge &&
      !myRow.cooldownToChallenge
    );

    if (myRow) {
      myRow.outside = myPos == null || myPos > 20;
    }

    // Marcar tots els jugadors amb el seu estat base
    rows.forEach((r) => {
      if (r.player_id === myPlayerId) return;
      r.reptable = false;
      r.canChallenge = false;
      
      // Marcar jugadors com a generalment reptables (per badges)
      // Tots els jugadors del rànquing són reptables excepte:
      // - Els que tenen repte actiu
      // - Els que estan en cooldown
      r.generallyChallengeable = r.posicio != null && r.posicio <= 20 && 
                                !r.hasActiveChallenge && !r.cooldownToBeChallenged;
    });

    if (myRow && myPos != null && myPos <= 20 && canIChallenge) {
      // current player inside ranking
      for (const r of ranking) {
        if (r.player_id === myPlayerId) continue;
        if (r.hasActiveChallenge || r.cooldownToBeChallenged) continue;
        if (r.posicio != null && myPos - (r.posicio as number) > 0 && myPos - (r.posicio as number) <= MAX_UP_CHALLENGE) {
          r.reptable = true;
        }
      }
    }

    if (myRow && (myPos == null || myPos > 20) && canIChallenge) {
      // waiting list first vs position 20
      const firstWaiting = waiting[0];
      const pos20 = byPos.get(20);
      if (
        firstWaiting?.player_id === myPlayerId &&
        pos20 &&
        !pos20.hasActiveChallenge &&
        !pos20.cooldownToBeChallenged
      ) {
        pos20.reptable = true;
      }
    }

    if (myPlayerId && eventId && canIChallenge) {
      for (const r of rows) {
        if (r.reptable) {
          const chk = await canCreateChallenge(
            supabase,
            eventId,
            myPlayerId,
            r.player_id
          );
          r.canChallenge = chk.ok;
          r.reason = chk.ok ? chk.warning : chk.reason;
        }
      }
    }
  }

  function reptar(id: string) {
    goto(`/reptes/nou?opponent=${id}`);
  }
</script>

<div class="mb-6">
  <h1 class="text-2xl font-bold text-slate-900 mb-2 flex items-center gap-3">
    <span class="text-3xl">🏆</span>
    Classificació del Rànquing
  </h1>
  <p class="text-slate-600 text-sm">Posicions actuals del campionat continu de 3 bandes</p>
</div>

{#if loading}
  <p class="text-slate-500">Carregant rànquing…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">
    Error: {error}
  </div>
{:else if rows.length === 0}
  <p class="text-slate-500">Encara no hi ha posicions al rànquing.</p>
{:else}
  <div class="overflow-x-auto rounded-xl bg-white shadow-sm border border-slate-200">
    <table class="min-w-full">
      <thead class="bg-gradient-to-r from-slate-50 to-slate-100 border-b border-slate-200">
        <tr>
          <th class="px-4 py-3 text-left font-semibold text-slate-700 text-sm">Posició</th>
          <th class="px-4 py-3 text-left font-semibold text-slate-700 text-sm">Jugador</th>
          <th class="px-4 py-3 text-left font-semibold text-slate-700 text-sm">Mitjana</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-slate-100">
        {#each rows as r}
          <tr class="hover:bg-slate-50 transition-colors duration-150 {r.isMe ? 'bg-blue-50' : ''}">
            <td class="px-4 py-3">
              {#if r.posicio}
                <div class="flex items-center justify-center w-10 h-10 rounded-full text-sm font-bold text-white
                  {r.posicio === 1 ? 'bg-gradient-to-r from-yellow-400 to-yellow-500 shadow-lg' :
                   r.posicio === 2 ? 'bg-gradient-to-r from-gray-300 to-gray-400 shadow-md' :
                   r.posicio === 3 ? 'bg-gradient-to-r from-amber-600 to-amber-700 shadow-md' :
                   r.posicio <= 5 ? 'bg-gradient-to-r from-emerald-500 to-emerald-600' :
                   r.posicio <= 10 ? 'bg-gradient-to-r from-blue-500 to-blue-600' :
                   'bg-gradient-to-r from-slate-400 to-slate-500'}">
                  {r.posicio}
                </div>
              {:else}
                <div class="flex items-center justify-center w-10 h-10 rounded-full text-sm font-medium text-slate-500 bg-slate-200">
                  —
                </div>
              {/if}
            </td>
            <td class="px-4 py-3">
              <div class="flex items-center gap-3">
                <span
                  class="font-medium text-slate-900 text-sm"
                  title={r.cognoms ? `${r.nom} ${r.cognoms}` : r.nom}
                >
                  {formatPlayerDisplayName(r.nom, r.cognoms)}
                </span>
                
                <!-- Badges d'estat modernitzats -->
                <div class="flex items-center gap-2 flex-wrap">
                  {#if r.isMe}
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-amber-400 to-amber-500 text-white shadow-sm">
                      ✨ Tu
                    </span>
                  {/if}
                  {#if r.hasActiveChallenge}
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-red-500 to-red-600 text-white shadow-sm">
                      🎯 Repte actiu
                    </span>
                  {/if}
                  {#if r.cooldownToChallenge}
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-orange-400 to-orange-500 text-white shadow-sm">
                      ⏳ No es pot reptar (falten {r.cooldownDaysLeft} dies)
                    </span>
                  {/if}
                  {#if r.protected}
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-slate-500 to-slate-600 text-white shadow-sm">
                      🛡️ Protegit
                    </span>
                  {/if}
                  {#if r.outside}
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-slate-300 to-slate-400 text-slate-700 shadow-sm">
                      📋 Fora rànquing
                    </span>
                  {/if}
                  {#if r.reptable && r.canChallenge}
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-emerald-500 to-emerald-600 text-white shadow-sm">
                      ⚔️ Reptable
                    </span>
                  {:else if r.generallyChallengeable}
                    <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-green-500 to-green-600 text-white shadow-sm">
                      ✅ Es pot reptar
                    </span>
                  {/if}

                  <!-- Botó reptar modernitzat -->
                  {#if myPlayerId && r.reptable}
                    <button
                      class="inline-flex items-center px-3 py-1.5 rounded-full text-xs font-medium transition-all duration-200 shadow-sm hover:shadow-md transform hover:scale-105
                        {r.canChallenge
                          ? 'bg-gradient-to-r from-green-500 to-green-600 text-white hover:from-green-600 hover:to-green-700'
                          : 'bg-slate-200 text-slate-500 cursor-not-allowed'}"
                      disabled={!r.canChallenge}
                      title={r.canChallenge ? (r.reason ?? 'Reptar aquest jugador') : (r.reason ?? 'No pots reptar aquest jugador')}
                      on:click={() => reptar(r.player_id)}
                    >
                      ⚡ Reptar
                    </button>
                  {/if}
                </div>
              </div>
            </td>
            <td class="px-4 py-3">
              {#if r.mitjana !== null}
                <div class="inline-flex items-center px-3 py-1.5 rounded-lg bg-emerald-50 border border-emerald-200">
                  <span class="font-mono text-sm font-semibold text-emerald-700">{r.mitjana.toFixed(3)}</span>
                </div>
              {:else if r.mitjanaHistorica !== null}
                <div class="inline-flex items-center px-3 py-1.5 rounded-lg bg-amber-50 border border-amber-200" title="Mitjana d'accés (millor entre 2024-2025)">
                  <span class="font-mono text-sm font-semibold text-amber-700">{r.mitjanaHistorica.toFixed(3)}</span>
                  <span class="ml-1 text-amber-600">*</span>
                </div>
              {:else}
                <span class="text-slate-400 text-sm font-medium">—</span>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

  <!-- Informació sobre mitjanes -->
  <div class="mt-6 p-4 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl border border-blue-200 shadow-sm">
    <div class="flex items-start gap-3">
      <div class="flex-shrink-0 w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
        <span class="text-blue-600 text-sm">ℹ️</span>
      </div>
      <div>
        <h3 class="font-semibold text-blue-900 text-sm mb-1">Llegenda de mitjanes</h3>
        <p class="text-sm text-blue-800">
          Les mitjanes marcades amb <span class="font-mono font-semibold">*</span> són mitjanes d'accés
          (millor mitjana entre 2024-2025 a 3 Bandes que va permetre l'entrada al rànquing).
        </p>
      </div>
    </div>
  </div>

  <!-- Llegenda d'estats modernitzada -->
  <div class="mt-4 p-4 bg-slate-50 rounded-xl border border-slate-200">
    <h3 class="font-semibold text-slate-900 text-sm mb-3 flex items-center gap-2">
      <span>🏷️</span> Llegenda d'estats
    </h3>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 text-sm">
      <div class="flex items-center gap-2">
        <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-amber-400 to-amber-500 text-white shadow-sm">✨ Tu</span>
        <span class="text-slate-700">el teu jugador</span>
      </div>
      <div class="flex items-center gap-2">
        <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-red-500 to-red-600 text-white shadow-sm">🎯 Repte actiu</span>
        <span class="text-slate-700">té repte actiu</span>
      </div>
      <div class="flex items-center gap-2">
        <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-orange-400 to-orange-500 text-white shadow-sm">⏳ Cooldown</span>
        <span class="text-slate-700">període d'espera</span>
      </div>
      <div class="flex items-center gap-2">
        <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-emerald-500 to-emerald-600 text-white shadow-sm">⚔️ Reptable</span>
        <span class="text-slate-700">pots reptar</span>
      </div>
      <div class="flex items-center gap-2">
        <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-slate-500 to-slate-600 text-white shadow-sm">🛡️ Protegit</span>
        <span class="text-slate-700">no reptable</span>
      </div>
      <div class="flex items-center gap-2">
        <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-slate-300 to-slate-400 text-slate-700 shadow-sm">📋 Fora rànquing</span>
        <span class="text-slate-700">fora del top 20</span>
      </div>
    </div>
  </div>

{/if}

