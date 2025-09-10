<script lang="ts">
  import { onMount } from 'svelte';

  type Row = {
    ordre: number;
    nom: string;
    data_inscripcio: string;
  };

  const fmtDate = (iso: string | null): string => {
    if (!iso) return '—';
    const d = new Date(iso);
    return isNaN(d.getTime()) ? '—' : d.toLocaleDateString();
  };

  let loading = true;
  let error: string | null = null;
  let rows: Row[] = [];

  onMount(async () => {
    try {
      const { supabase } = await import('$lib/supabaseClient');
      const { data, error: err } = await supabase.rpc('get_waiting_list');
      if (err) error = err.message;
      else rows = data ?? [];
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Llista d’espera</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Llista d’espera</h1>

{#if loading}
  <p class="text-slate-500">Carregant llista d’espera…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-300 bg-red-50 p-3 text-red-800">{error}</div>
{:else if rows.length === 0}
  <p class="text-slate-500">No hi ha ningú en llista d’espera.</p>
{:else}
  <div class="overflow-x-auto rounded-lg border border-slate-200">
    <table class="min-w-full text-sm">
      <thead class="bg-slate-50">
        <tr>
          <th class="px-3 py-2 text-left font-semibold">Ordre</th>
          <th class="px-3 py-2 text-left font-semibold">Nom</th>
          <th class="px-3 py-2 text-left font-semibold">Data inscripció</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r}
          <tr class="border-t">
            <td class="px-3 py-2">{r.ordre}</td>
            <td class="px-3 py-2">{r.nom}</td>
            <td class="px-3 py-2">{fmtDate(r.data_inscripcio)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}
