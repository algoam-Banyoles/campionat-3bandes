<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { get } from 'svelte/store';
  import { canCreateChallenge } from '$lib/canCreateChallenge';
  import { ranking, refreshRanking, type RankingRow } from '$lib/rankingStore';
  import PlayerEvolutionModal from '$lib/components/PlayerEvolutionModal.svelte';
  import { adminStore } from '$lib/roles';
  import { applyDisagreementDrop } from '$lib/applyDisagreementDrop';

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

  onMount(async () => {
    try {
      const { supabase } = await import('$lib/supabaseClient');
      supabaseClient = supabase;

      unsub = ranking.subscribe((base) => {
        const rdata = base.slice(0, 20);
        rows = rdata.map((r) => ({
          ...r,
          canChallenge: false,
          reason: null,
          moved: highlightIds.has(r.player_id),
        }));
        void evaluateChallenges(supabaseClient);
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
      await evaluateChallenges(supabaseClient);
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

  function openEvolution(id: string, name: string) {
    modalPlayer = { id, name };
  }

  const fmtMitjana = (m: number | null) => (m == null ? '-' : String(m));
  const fmtEstat = (e: string) => e.replace('_', ' ');

  async function applyPenalty() {
    if (!(eventId && selA && selB && Math.abs(selA - selB) === 1)) return;
    penaltyBusy = true;
    penaltyError = null;
    try {
      const before = get(ranking);
      const playerA = before.find((r) => r.posicio === selA)?.player_id;
      const playerB = before.find((r) => r.posicio === selB)?.player_id;
      if (!(playerA && playerB)) throw new Error('Selecció invàlida');
      await applyDisagreementDrop(supabaseClient, eventId, playerA, playerB);
      await refreshRanking();
      const after = get(ranking);
      const beforeMap = new Map(before.map((r) => [r.player_id, r.posicio]));
      highlightIds = new Set(
        after
          .filter((r) => beforeMap.get(r.player_id) !== r.posicio)
          .map((r) => r.player_id)
      );
      rows = after.slice(0, 20).map((r) => ({
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
          <tr class="border-t" class:bg-yellow-100={r.moved}>
            <td class="px-3 py-2">{r.posicio}</td>
            <td class="px-3 py-2">
              <button
                class="text-blue-600 hover:underline"
                on:click={() => openEvolution(r.player_id, r.nom)}
              >
                {r.nom}
              </button>
            </td>
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
              <option value={r.posicio}>{r.posicio} - {r.nom}</option>
            {/each}
          </select>
        </div>
        <div class="mb-2">
          <label class="block text-sm mb-1" for="penal-b">Posició B</label>
          <select id="penal-b" bind:value={selB} class="w-full rounded border p-1">
            <option value={null} disabled selected>Selecciona posició</option>
            {#each rows as r}
              <option value={r.posicio}>{r.posicio} - {r.nom}</option>
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
