<script lang="ts">
  import { onMount } from 'svelte';
  import PlayerEvolutionModal from '$lib/components/PlayerEvolutionModal.svelte';

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
    onCooldown?: boolean;
    canReptar?: boolean;
    reptable?: boolean;
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
          onCooldown: false,
          canReptar: false,
          reptable: false
        }));

        const eventId = base[0]?.event_id as string | undefined;
        await evaluateBadges(supabase, rows, eventId);

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
    eventId: string | undefined
  ): Promise<void> {
    if (!eventId) return;

    const MAX_UP_CHALLENGE = 2;
    const COOLDOWN_DAYS = 7;

    const byId = new Map<string, Row>();
    rows.forEach((r) => byId.set(r.player_id, r));

    // Active challenges
    const { data: active } = await supabase
      .from('challenges')
      .select('challenger_id, challenged_id')
      .eq('event_id', eventId)
      .in('status', ['PENDING', 'ACCEPTED']);
    const activeIds = new Set<string>();
    (active as any[] ?? []).forEach((c) => {
      activeIds.add((c as any).challenger_id);
      activeIds.add((c as any).challenged_id);
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
      r.onCooldown = false;
      if (lc?.last_challenge_date) {
        const dt = new Date(lc.last_challenge_date);
        const diff = (now - dt.getTime()) / (1000 * 60 * 60 * 24);
        if (diff < COOLDOWN_DAYS) {
          if (!(lc.last_challenge_outcome === 'REFUSED' && lc.was_challenger)) {
            r.onCooldown = true;
          }
        }
      }
    });

    const byPos = new Map<number, Row>();
    const ranking = rows.filter((r) => r.posicio != null && r.posicio <= 20);
    ranking.forEach((r) => byPos.set(r.posicio as number, r));

    // Determine who can challenge
    ranking.forEach((r) => {
      if (r.hasActiveChallenge || r.onCooldown) return;
      for (let d = 1; d <= MAX_UP_CHALLENGE; d++) {
        const opp = byPos.get((r.posicio as number) - d);
        if (!opp) continue;
        if (!opp.hasActiveChallenge && !opp.onCooldown) {
          r.canReptar = true;
          break;
        }
      }
    });

    // Determine who can be challenged
    ranking.forEach((r) => {
      if (r.hasActiveChallenge || r.onCooldown) return;
      for (let d = 1; d <= MAX_UP_CHALLENGE; d++) {
        const challenger = byPos.get((r.posicio as number) + d);
        if (!challenger) continue;
        if (!challenger.hasActiveChallenge && !challenger.onCooldown) {
          r.reptable = true;
          break;
        }
      }
    });

    // Waiting list vs position 20
    const waiting = rows.filter((r) => r.posicio == null || r.posicio > 20);
    const firstWaiting = waiting[0];
    const pos20 = byPos.get(20);
    if (
      firstWaiting &&
      pos20 &&
      !firstWaiting.hasActiveChallenge &&
      !firstWaiting.onCooldown &&
      !pos20.hasActiveChallenge &&
      !pos20.onCooldown
    ) {
      firstWaiting.canReptar = true;
      pos20.reptable = true;
    }
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
              {#if r.hasActiveChallenge}
                <span
                  title="Té repte actiu"
                  class="ml-1 inline-block rounded bg-red-500 px-1 text-xs font-semibold text-white align-middle"
                  >Té repte actiu</span
                >
              {/if}
              {#if !r.hasActiveChallenge && r.onCooldown}
                <span
                  title="No pot reptar (cooldown)"
                  class="ml-1 inline-block rounded bg-yellow-300 px-1 text-xs font-semibold text-slate-900 align-middle"
                  >No pot reptar</span
                >
              {/if}
              {#if !r.hasActiveChallenge && !r.onCooldown && r.canReptar}
                <span
                  title="Pot reptar"
                  class="ml-1 inline-block rounded bg-green-500 px-1 text-xs font-semibold text-white align-middle"
                  >Pot reptar</span
                >
              {/if}
              {#if !r.hasActiveChallenge && !r.onCooldown && r.reptable}
                <span
                  title="Reptable"
                  class="ml-1 inline-block rounded bg-blue-500 px-1 text-xs font-semibold text-white align-middle"
                  >Reptable</span
                >
              {/if}
              {#if r.isMe}
                <span
                  title="Tu"
                  class="ml-1 inline-block rounded bg-yellow-400 px-1 text-xs font-semibold text-slate-900 align-middle"
                  >Tu</span
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
      <span class="inline-block rounded bg-red-500 px-1 text-xs font-semibold text-white">Té repte actiu</span>
      <span>té repte actiu</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded bg-yellow-300 px-1 text-xs font-semibold text-slate-900">No pot reptar</span>
      <span>no pot reptar (cooldown)</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded bg-green-500 px-1 text-xs font-semibold text-white">Pot reptar</span>
      <span>pot reptar</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded bg-blue-500 px-1 text-xs font-semibold text-white">Reptable</span>
      <span>reptable</span>
    </div>
    <div class="flex items-center gap-1">
      <span class="inline-block rounded bg-yellow-400 px-1 text-xs font-semibold text-slate-900">Tu</span>
      <span>tu</span>
    </div>
  </div>

{/if}

