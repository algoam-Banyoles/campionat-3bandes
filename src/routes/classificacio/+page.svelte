<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { canCreateChallenge } from '$lib/canCreateChallenge';
  import type { VPlayerBadges } from '$lib/server/daoAdmin';

  export let data: { badges?: VPlayerBadges[] | null } | undefined;
  export let badges: VPlayerBadges[] | null | undefined;

  const initialBadges = (badges ?? data?.badges ?? null) as VPlayerBadges[] | null;
  const preloadedBadgeMap =
    initialBadges === null
      ? undefined
      : new Map<string, VPlayerBadges>(
          initialBadges.map((badge) => [badge.playerId, badge])
        );

  type Row = {
    event_id: string;
    posicio: number | null;
    player_id: string;
    nom: string;
    mitjana: number | null;
    estat: string;
    assignat_el: string | null;
    isMe?: boolean;
    hasActiveChallenge?: boolean;
    cooldownToChallenge?: boolean;
    cooldownToBeChallenged?: boolean;
    reptable?: boolean;
    canChallenge?: boolean;
    reason?: string | null;
    protected?: boolean;
    outside?: boolean;
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
        await evaluateBadges(supabase, rows, eventId, myPlayerId, preloadedBadgeMap);

        // trigger reactivity after in-place badge updates
        rows = [...rows];
      }
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });


  async function evaluateBadges(
    supabase: any,
    rows: Row[],
    eventId: string | undefined,
    myPlayerId: string | null,
    preloadedBadges?: Map<string, VPlayerBadges>
  ): Promise<void> {
    if (!eventId) return;

    const MAX_UP_CHALLENGE = 2;
    const COOLDOWN_DAYS = 7;

    const byId = new Map<string, Row>();
    rows.forEach((r) => byId.set(r.player_id, r));

    if (preloadedBadges) {
      for (const [playerId, badge] of preloadedBadges) {
        const row = byId.get(playerId);
        if (!row) continue;
        row.hasActiveChallenge = badge.hasActiveChallenge ?? false;
        row.cooldownToChallenge = badge.cooldownToChallenge ?? false;
        row.cooldownToBeChallenged = badge.cooldownToBeChallenged ?? false;
      }
    } else {
      const { data: active } = await supabase
        .from('challenges')
        .select('challenger_id, challenged_id')
        .eq('event_id', eventId)
        .in('status', ['PENDING', 'ACCEPTED']);
      const activeIds = new Set<string>();
      (active as any[] ?? []).forEach((c) => {
        const challengerId = (c as any)?.challenger_id as string | undefined;
        const challengedId = (c as any)?.challenged_id as string | undefined;
        if (challengerId) activeIds.add(challengerId);
        if (challengedId) activeIds.add(challengedId);
      });
      activeIds.forEach((id) => {
        const row = byId.get(id);
        if (row) row.hasActiveChallenge = true;
      });

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
      });
    }

    rows.forEach((r) => {
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
          <th class="px-3 py-2 text-left font-semibold">Estat</th>
          <th class="px-3 py-2 text-left font-semibold">Assignat</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr class="border-t">
            <td class="px-3 py-2">{r.posicio ?? '-'}</td>
            <td class="px-3 py-2">
              {r.nom}
              {#if r.isMe}
                <span
                  class="ml-1 inline-block rounded-full bg-yellow-400 px-2.5 py-1 text-xs font-medium text-gray-900 align-middle"
                  title="Tu"
                  aria-label="Tu"
                  >Tu</span
                >
              {/if}
              {#if r.hasActiveChallenge}
                <span
                  class="ml-1 inline-block rounded-full bg-red-600 px-2.5 py-1 text-xs font-medium text-white align-middle"
                  title="Aquest jugador té un repte actiu (no pot iniciar-ne cap altre)."
                  aria-label="Aquest jugador té un repte actiu (no pot iniciar-ne cap altre)."
                  >Té repte actiu</span
                >
              {:else if r.cooldownToChallenge}
                <span
                  class="ml-1 inline-block rounded-full bg-yellow-300 px-2.5 py-1 text-xs font-medium text-gray-900 align-middle"
                  title="En cooldown fins passats 7 dies del darrer repte disputat."
                  aria-label="En cooldown fins passats 7 dies del darrer repte disputat."
                  >No pot reptar</span
                >
              {:else if r.isMe}
                <span
                  class="ml-1 inline-block rounded-full bg-green-600 px-2.5 py-1 text-xs font-medium text-white align-middle"
                  title="Pots reptar fins a 2 posicions per sobre teu."
                  aria-label="Pots reptar fins a 2 posicions per sobre teu."
                  >Pot reptar</span
                >
              {:else if r.reptable}
                <button
                  class="ml-1 rounded-full bg-blue-600 px-2.5 py-1 text-xs font-medium text-white align-middle disabled:opacity-50"
                  title={r.canChallenge ? 'Aquest jugador és reptable per tu ara mateix.' : r.reason || 'No pots reptar'}
                  aria-label={r.canChallenge ? 'Aquest jugador és reptable per tu ara mateix.' : r.reason || 'No pots reptar'}
                  disabled={!r.canChallenge}
                  on:click={() => reptar(r.player_id)}
                >
                  Reptable
                </button>
              {/if}
              {#if r.protected}
                <span
                  class="ml-1 inline-block rounded-full bg-gray-400 px-2.5 py-1 text-xs font-medium text-white align-middle"
                  title="Protegit (cooldown de ser reptat)"
                  aria-label="Protegit (cooldown de ser reptat)"
                  >Protegit</span
                >
              {/if}
              {#if r.outside}
                <span
                  class="ml-1 inline-block rounded-full bg-gray-200 px-2.5 py-1 text-xs font-medium text-gray-800 align-middle"
                  title="Fora de rànquing actiu"
                  aria-label="Fora de rànquing actiu"
                  >Fora de rànquing actiu</span
                >
              {/if}
            </td>
            <td class="px-3 py-2">{r.mitjana ?? '-'}</td>
            <td class="px-3 py-2 capitalize">{r.estat.replace('_', ' ')}</td>
            <td class="px-3 py-2">{fmtSafe(r.assignat_el)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
  <div class="mt-2 flex flex-wrap gap-4 text-sm">
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-red-600 px-2.5 py-1 text-xs font-medium text-white">Té repte actiu</span>
      <span>té repte actiu</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded-full bg-yellow-300 px-2.5 py-1 text-xs font-medium text-gray-900">No pot reptar</span>
      <span>no pot reptar (cooldown)</span>
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

