<script lang="ts">
  import { onMount } from 'svelte';

  type Row = {
    event_id: string;
    posicio: number;
    player_id: string;
    nom: string;
    mitjana: number | null;
    estat: string;
    assignat_el: string | null;
  };

  const fmtSafe = (iso: string | null): string => {
    if (!iso) return '—';
    const d = new Date(iso);
    return isNaN(d.getTime()) ? '—' : d.toLocaleDateString();
  };

  let loading = true;
  let error: string | null = null;
  let rows: Row[] = [];

  onMount(async () => {
    try {
      // importem el client només al navegador
      const { supabase } = await import('$lib/supabaseClient');
      const { data, error: err } = await supabase
        .from('v_ranking')
        .select('event_id,posicio,player_id,nom,mitjana,estat,assignat_el')
        .order('posicio', { ascending: true });

      if (err) error = err.message;
      else rows = data ?? [];
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
  <p class="text-red-600">Error: {error}</p>
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
            <td class="px-3 py-2">{r.posicio}</td>
            <td class="px-3 py-2">{r.nom}</td>
            <td class="px-3 py-2">{r.mitjana ?? '-'}</td>
            <td class="px-3 py-2 capitalize">{r.estat.replace('_', ' ')}</td>
            <td class="px-3 py-2">{fmtSafe(r.assignat_el)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}
