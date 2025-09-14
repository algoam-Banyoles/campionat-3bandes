<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { get } from 'svelte/store';
  import { canCreateChallenge } from '$lib/canCreateChallenge';
  import { ranking, refreshRanking, type RankingRow } from '$lib/rankingStore';

  type RowState = RankingRow & { canChallenge: boolean; reason: string | null };

  let loading = true;
  let error: string | null = null;
  let rows: RowState[] = [];
  let myPlayerId: string | null = null;
  let myPos: number | null = null;
  let eventId: string | null = null;
  let unsub: (() => void) | null = null;

  onMount(async () => {
    try {
      const { supabase } = await import('$lib/supabaseClient');

      unsub = ranking.subscribe((base) => {
        const rdata = base.slice(0, 20);
        rows = rdata.map((r) => ({ ...r, canChallenge: false, reason: null }));
        void evaluateChallenges(supabase);
      });

      // Auth & player (opcional)
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

      await refreshRanking();
      myPos = get(ranking).find((r) => r.player_id === myPlayerId)?.posicio ?? null;
      await evaluateChallenges(supabase);
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });

  onDestroy(() => {
    unsub?.();
  });

  async function evaluateChallenges(supabase: any) {
    myPos = rows.find((r) => r.player_id === myPlayerId)?.posicio ?? null;
    if (!(myPlayerId && myPos && eventId)) return;
    for (const r of rows) {
      if (r.player_id === myPlayerId) continue;
      if (r.posicio >= myPos || myPos - r.posicio > 2) {
        r.canChallenge = false;
        r.reason = 'Només fins a 2 posicions per sobre';
        continue;
      }
      const chk = await canCreateChallenge(supabase, eventId, myPlayerId, r.player_id);
      r.canChallenge = chk.ok;
      r.reason = chk.ok ? chk.warning : chk.reason;
    }
  }

  function reptar(id: string) {
    goto(`/reptes/nou?opponent=${id}`);
  }

  const fmtMitjana = (m: number | null) => (m == null ? '-' : String(m));
  const fmtEstat = (e: string) => e.replace('_', ' ');
</script>

<svelte:head><title>Rànquing</title></svelte:head>

<h1 class="text-xl font-semibold mb-4">Rànquing</h1>

{#if loading}
  <p class="text-slate-500">Carregant rànquing…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">Error: {error}</div>
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
          <th class="px-3 py-2 text-left font-semibold"></th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr class="border-t">
            <td class="px-3 py-2">{r.posicio}</td>
            <td class="px-3 py-2">{r.nom}</td>
            <td class="px-3 py-2">{fmtMitjana(r.mitjana)}</td>
            <td class="px-3 py-2 capitalize">{fmtEstat(r.estat)}</td>
            <td class="px-3 py-2">
              {#if myPlayerId && r.player_id !== myPlayerId}
                <button
                  class="rounded-2xl border px-3 py-1 text-sm disabled:opacity-50"
                  disabled={!r.canChallenge}
                  title={r.canChallenge ? '' : r.reason || 'No pots reptar'}
                  on:click={() => reptar(r.player_id)}
                >
                  Reptar
                </button>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}
