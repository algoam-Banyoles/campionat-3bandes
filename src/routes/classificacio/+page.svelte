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
    canReptar?: boolean;
    canSerReptat?: boolean;
    isMe?: boolean;
    hasActiveChallenge?: boolean;

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
          canReptar: false,
          canSerReptat: false,

          isMe: myPlayerId === r.player_id,
          hasActiveChallenge: false
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
    const byId = new Map<string, Row>();
    rows.forEach((r) => byId.set(r.player_id, r));

    const { data: active } = await supabase
      .from('challenges')
      .select('reptador_id, reptat_id')
      .eq('event_id', eventId)
      .in('estat', ['proposat', 'acceptat', 'programat']);
    const activeIds = new Set<string>();
    (active as any[] ?? []).forEach((c) => {
      activeIds.add((c as any).reptador_id);
      activeIds.add((c as any).reptat_id);
    });
    activeIds.forEach((id) => {
      const row = byId.get(id);
      if (row) row.hasActiveChallenge = true;
    });

    const { data: played } = await supabase
      .from('matches')
      .select('challenge:challenge_id(reptador_id, reptat_id)')
      .eq('challenge.event_id', eventId);
    const playedIds = new Set<string>();
    (played as any[] ?? []).forEach((m) => {
      const ch = (m as any).challenge;
      if (ch) {
        playedIds.add(ch.reptador_id);
        playedIds.add(ch.reptat_id);
      }
    });

    const byPos = new Map<number, Row>();
    const ranking = rows.filter((r) => r.posicio != null && r.posicio <= 20);
    ranking.forEach((r) => byPos.set(r.posicio as number, r));

    const maxGap = 2;
    const tasks: Promise<void>[] = [];

    for (const r of ranking) {
      tasks.push(
        (async () => {
          if (r.hasActiveChallenge) return;
          if (!playedIds.has(r.player_id)) {
            r.canReptar = true;
            r.canSerReptat = true;
            return;
          }
          for (let d = 1; d <= maxGap; d++) {
            const opp = byPos.get((r.posicio as number) - d);
            if (!opp) continue;
            const { data } = await supabase.rpc('can_create_challenge', {
              p_event: eventId,
              p_reptador: r.player_id,
              p_reptat: opp.player_id
            });
            if ((data as any)?.[0]?.ok) {
              r.canReptar = true;
              break;
            }
          }

          for (let d = 1; d <= maxGap; d++) {
            const challenger = byPos.get((r.posicio as number) + d);
            if (!challenger) continue;
            const { data } = await supabase.rpc('can_create_challenge', {
              p_event: eventId,
              p_reptador: challenger.player_id,
              p_reptat: r.player_id
            });
            if ((data as any)?.[0]?.ok) {
              r.canSerReptat = true;
              break;
            }
          }
        })()
      );
    }

    await Promise.all(tasks);

    const waiting = rows.filter((r) => r.posicio == null || r.posicio > 20);
    const firstWaiting = waiting[0];
    const pos20 = byPos.get(20);

    if (firstWaiting && pos20 && !firstWaiting.hasActiveChallenge) {
      const { data } = await supabase.rpc('can_create_access_challenge', {
        p_event: eventId,
        p_reptador: firstWaiting.player_id,
        p_reptat: pos20.player_id
      });
      if ((data as any)?.[0]?.ok) {
        firstWaiting.canReptar = true;
        pos20.canSerReptat = true;
      }
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
          <th class="px-3 py-2 text-left font-semibold">Reptar</th>
          <th class="px-3 py-2 text-left font-semibold">Reptable</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr class="border-t">
            <td class="px-3 py-2">{r.posicio ?? '-'}</td>
            <td class="px-3 py-2">

              {r.nom}
              {#if r.canReptar}
                <span title="Pot reptar" class="ml-1 inline-block h-3 w-3 rounded-full bg-green-500 align-middle"></span>
              {/if}
              {#if r.canSerReptat}
                <span title="Pot ser reptat" class="ml-1 inline-block h-3 w-3 rounded-full bg-blue-500 align-middle"></span>

              {/if}
              {#if r.isMe}
                <span
                  title="Tu"

                  class="ml-1 inline-block rounded bg-yellow-400 px-1 text-xs font-semibold text-slate-900 align-middle"
                  >Tu</span
                >

              {/if}
              {#if r.hasActiveChallenge}
                <span
                  title="Té un repte actiu"
                  class="ml-1 inline-block h-3 w-3 rounded-full bg-red-500 align-middle"
                ></span>
              {/if}
            </td>
            <td class="px-3 py-2">{r.mitjana ?? '-'}</td>
            <td class="px-3 py-2 capitalize">{r.estat.replace('_', ' ')}</td>
            <td class="px-3 py-2">{fmtSafe(r.assignat_el)}</td>
            <td class="px-3 py-2">
              <span
                class={`text-xs rounded px-2 py-0.5 ${r.canReptar ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-500'}`}
                >{r.canReptar ? 'Sí' : 'No'}</span
              >
            </td>
            <td class="px-3 py-2">
              <span
                class={`text-xs rounded px-2 py-0.5 ${r.canSerReptat ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-500'}`}
                >{r.canSerReptat ? 'Sí' : 'No'}</span
              >
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
  <div class="mt-2 flex gap-4 text-sm">
    <div class="flex items-center gap-1"><span class="inline-block h-3 w-3 rounded-full bg-green-500"></span><span>pot reptar</span></div>
    <div class="flex items-center gap-1"><span class="inline-block h-3 w-3 rounded-full bg-blue-500"></span><span>pot ser reptat</span></div>

    <div class="flex items-center gap-1">
      <span class="inline-block rounded bg-yellow-400 px-1 text-xs font-semibold text-slate-900">Tu</span>
      <span>tu</span>
    </div>
    <div class="flex items-center gap-1"><span class="inline-block h-3 w-3 rounded-full bg-red-500"></span><span>repte actiu</span></div>
  </div>

{/if}

