<script lang="ts">
  import { onMount } from 'svelte';

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
        const waiting = base.filter((r) => r.posicio == null || r.posicio > 20);
        const firstWaitingId = waiting[0]?.player_id ?? null;
        rows = base.map((r) => {
          const inRanking = r.posicio != null && r.posicio <= 20;
          let canReptar = false;
          let canSerReptat = false;
          if (inRanking && r.estat === 'actiu') {
            canReptar = true;
            canSerReptat = true;
          }
          if (!inRanking && r.player_id === firstWaitingId && r.estat === 'actiu') {
            canReptar = true;
          }
          return {
            ...r,
            canReptar,
            canSerReptat,
            isMe: myPlayerId === r.player_id
          } as Row;
        });
      }
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });
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
              {#if r.isMe}
                <span class="ml-2 rounded bg-yellow-100 px-2 py-0.5 text-xs text-yellow-800">Tu</span>
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
{/if}

