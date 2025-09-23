<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { canCreateChallenge } from '$lib/canCreateChallenge';
  import { formatPlayerDisplayName } from '$lib/utils/playerName';

  type Row = {
    posicio: number;
    player_id: string;
    nom: string;
    cognoms: string | null;
    mitjana: number | null;
    estat: string;
    event_id?: string;
    // Si vols afegir camps extra, afegeix-los aquí i a la funció SQL
    isMe?: boolean;
    hasActiveChallenge?: boolean;
    cooldownToChallenge?: boolean;
    cooldownToBeChallenged?: boolean;
    reptable?: boolean;
    canChallenge?: boolean;
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

      const { data, error: err } = await supabase.rpc('get_ranking');

      if (err) error = err.message;
      else {
        const base = (data as Row[]) ?? [];
        rows = base.map((r) => ({
          ...r,
          cognoms: r.cognoms ?? null,
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

        const eventId = base[0]?.event_id as string | undefined;

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

    // Last challenge info
    const { data: last } = await supabase
      .from('player_last_challenge')
      .select('player_id, last_challenge_date, last_challenge_outcome, was_challenger')
      .eq('event_id', eventId);
    const lastMap = new Map<string, any>();
    (last as any[] ?? []).forEach((l) => lastMap.set(l.player_id, l));

    const now = Date.now();
    rows.forEach((r) => {
      const lc = lastMap.get(r.player_id);
      r.cooldownToChallenge = false;
      r.cooldownToBeChallenged = false;
      if (lc?.last_challenge_date) {
        const dt = new Date(lc.last_challenge_date);
        const diff = (now - dt.getTime()) / (1000 * 60 * 60 * 24);
        if (diff < COOLDOWN_DAYS) {
          r.cooldownToChallenge = true;
          r.cooldownToBeChallenged = true;
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

    rows.forEach((r) => {
      if (r.player_id === myPlayerId) return;
      r.reptable = false;
      r.canChallenge = false;
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

<h1 class="text-xl font-semibold mb-4">Classificació</h1>

{#if loading}
  <p class="text-slate-500">Carregant rànquing…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">
    Error: {error}
  </div>
{:else if rows.length === 0}
  <p class="text-slate-500">Encara no hi ha posicions al rànquing.</p>
{:else}
  <div class="overflow-x-auto rounded-lg border border-slate-200">
    <table class="min-w-full text-sm">
      <thead class="bg-slate-50">
        <tr>
          <th class="px-3 py-2 text-left font-semibold">Pos.</th>
          <th class="px-3 py-2 text-left font-semibold">Jugador</th>
          <th class="px-3 py-2 text-left font-semibold">Mitjana</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr class="border-t">
            <td class="px-3 py-2">{r.posicio}</td>
            <td class="px-3 py-2">
              <div class="flex items-center gap-2">
                <span
                  class="font-medium text-gray-900"
                  title={r.cognoms ? `${r.nom} ${r.cognoms}` : r.nom}
                >
                  {formatPlayerDisplayName(r.nom, r.cognoms)}
                </span>
                
                <!-- Badges d'estat -->
                {#if r.isMe}
                  <span class="inline-block rounded-full bg-yellow-400 px-2 py-0.5 text-xs font-medium text-gray-900">Tu</span>
                {/if}
                {#if r.hasActiveChallenge}
                  <span class="inline-block rounded-full bg-red-600 px-2 py-0.5 text-xs font-medium text-white">Repte actiu</span>
                {/if}
                {#if r.cooldownToChallenge}
                  <span class="inline-block rounded-full bg-yellow-300 px-2 py-0.5 text-xs font-medium text-gray-900">Cooldown</span>
                {/if}
                {#if r.protected}
                  <span class="inline-block rounded-full bg-gray-400 px-2 py-0.5 text-xs font-medium text-white">Protegit</span>
                {/if}
                {#if r.outside}
                  <span class="inline-block rounded-full bg-gray-200 px-2 py-0.5 text-xs font-medium text-gray-800">Fora rànquing</span>
                {/if}
                {#if r.reptable && r.canChallenge}
                  <span class="inline-block rounded-full bg-blue-600 px-2 py-0.5 text-xs font-medium text-white">Reptable</span>
                {/if}

                <!-- Botó reptar -->
                {#if r.reptable}
                  <button
                    class="ml-1 px-2 py-1 rounded bg-green-600 text-white text-xs hover:bg-green-700 disabled:bg-gray-300 disabled:text-gray-500 disabled:cursor-not-allowed transition-colors"
                    disabled={!r.canChallenge}
                    title={r.canChallenge ? (r.reason ?? 'Reptar aquest jugador') : (r.reason ?? 'No pots reptar aquest jugador')}
                    on:click={() => reptar(r.player_id)}
                  >Reptar</button>
                {/if}
              </div>
            </td>
            <td class="px-3 py-2">
              {#if r.mitjana !== null}
                <span class="font-mono text-sm">{r.mitjana.toFixed(3)}</span>
              {:else if r.mitjanaHistorica !== null}
                <span class="font-mono text-sm text-gray-600" title="Mitjana d'accés (millor entre 2024-2025)">
                  {r.mitjanaHistorica.toFixed(3)}*
                </span>
              {:else}
                <span class="text-gray-400 text-sm">—</span>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
  
  <div class="mt-4 p-3 bg-blue-50 rounded-lg border border-blue-200">
    <p class="text-sm text-blue-800">
      <strong>Llegenda mitjanes:</strong> Les mitjanes marcades amb * són mitjanes d'accés 
      (millor mitjana entre 2024-2025 a 3 Bandes que va permetre l'entrada al rànquing).
    </p>
  </div>

  <div class="mt-2 flex flex-wrap gap-4 text-sm">
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-red-600 px-2.5 py-1 text-xs font-medium text-white">Té repte actiu</span>
      <span>té repte actiu</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-yellow-300 px-2.5 py-1 text-xs font-medium text-gray-900">No pot reptar</span>
      <span>no pot reptar (període d'espera)</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-green-600 px-2.5 py-1 text-xs font-medium text-white">Pot reptar</span>
      <span>pot reptar</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-blue-600 px-2.5 py-1 text-xs font-medium text-white">Reptable</span>
      <span>reptable</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-gray-400 px-2.5 py-1 text-xs font-medium text-white">Protegit</span>
      <span>protegit (no reptable)</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-gray-200 px-2.5 py-1 text-xs font-medium text-gray-800">Fora de rànquing actiu</span>
      <span>fora de rànquing actiu</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-yellow-400 px-2.5 py-1 text-xs font-medium text-gray-900">Tu</span>
      <span>tu</span>
    </div>
  </div>

{/if}

