<script lang="ts">
    import { onMount } from 'svelte';
    import { user } from '$lib/stores/auth';
    import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
  import Banner from '$lib/components/general/Banner.svelte';
  import { resolveAccessChallenge } from '$lib/challenges';
  import { refreshRanking } from '$lib/stores/rankingStore';
  import { invalidate } from '$app/navigation';

  type Row = {
    id: string;
    reptador_soci_numero: number;
    reptat_soci_numero: number;
    reptador_nom: string;
    reptat_nom: string;
  };

  let loading = true;
  let error: string | null = null;
  let rows: Row[] = [];
  let busy: string | null = null;
  let okMsg: string | null = null;

  onMount(load);

  async function load() {
    try {
      loading = true;
      error = null;
      okMsg = null;

      const { supabase } = await import('$lib/supabaseClient');
      const { data: ch, error: e1 } = await supabase
        .from('challenges')
        .select('id,reptador_soci_numero,reptat_soci_numero')
        .eq('tipus', 'access')
        .in('estat', ['proposat', 'acceptat', 'programat'])
        .order('data_proposta', { ascending: true });
      if (e1) throw e1;

      const nums = Array.from(
        new Set([...(ch?.map((c: any) => c.reptador_soci_numero) ?? []), ...(ch?.map((c: any) => c.reptat_soci_numero) ?? [])])
      );
      const { data: socisData, error: e2 } = await supabase
        .from('socis')
        .select('numero_soci,nom')
        .in('numero_soci', nums);
      if (e2) throw e2;
      const nameByNum = new Map(socisData?.map((p) => [p.numero_soci, p.nom]) ?? []);
      rows = ((ch ?? []) as unknown as Row[]).map((c) => ({
        ...c,
        reptador_nom: nameByNum.get(c.reptador_soci_numero) ?? '—',
        reptat_nom: nameByNum.get(c.reptat_soci_numero) ?? '—'
      }));
    } catch (e: any) {
      error = e?.message ?? 'Error carregant reptes d\'accés';
    } finally {
      loading = false;
    }
  }

  async function resolve(r: Row, winner: 'reptador' | 'reptat') {
    try {
      busy = r.id;
      error = null;
      okMsg = null;
      const { supabase } = await import('$lib/supabaseClient');
      await resolveAccessChallenge(supabase, r.id, winner);
      okMsg = 'Repte resolt';
      await Promise.all([load(), refreshRanking(), invalidate('/llista-espera')]);
    } catch (e: any) {
      error = e?.message ?? 'Error resolent repte';
    } finally {
      busy = null;
    }
  }
</script>

<svelte:head><title>Reptes d'accés</title></svelte:head>

<h1 class="text-xl font-semibold mb-4">Reptes d'accés</h1>

{#if loading}
  <p class="text-slate-500">Carregant…</p>
{:else if error}
  <Banner type="error" message={error} />
{:else if rows.length === 0}
  <p class="text-slate-500">No hi ha reptes d'accés pendents.</p>
{:else}
  {#if okMsg}
    <Banner type="success" message={okMsg} class="mb-3" />
  {/if}
  <ul class="space-y-2">
    {#each rows as r}
      <li class="p-3 border rounded">
        <div class="font-medium">{r.reptador_nom} vs {r.reptat_nom}</div>
        <div class="mt-2 space-x-2">
          <button
            class="rounded border px-2 py-1 text-sm"
            on:click={() => resolve(r, 'reptador')}
            disabled={busy === r.id}
          >
            Guanya reptador
          </button>
          <button
            class="rounded border px-2 py-1 text-sm"
            on:click={() => resolve(r, 'reptat')}
            disabled={busy === r.id}
          >
            Guanya reptat
          </button>
        </div>
      </li>
    {/each}
  </ul>
{/if}
