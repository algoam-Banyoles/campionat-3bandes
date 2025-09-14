<script lang="ts">
  import { onMount } from 'svelte';
  import { user } from '$lib/authStore';
  import { checkIsAdmin } from '$lib/roles';
  import Banner from '$lib/components/Banner.svelte';
  import { resolveAccessChallenge } from '$lib/challenges';
  import { refreshRanking } from '$lib/rankingStore';
  import { invalidate } from '$app/navigation';

  type Row = {
    id: string;
    reptador_id: string;
    reptat_id: string;
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

      if (!$user?.email) {
        error = 'Has d\'iniciar sessió.';
        return;
      }
      const adm = await checkIsAdmin();
      if (!adm) {
        error = 'Només administradors.';
        return;
      }

      const { supabase } = await import('$lib/supabaseClient');
      const { data: ch, error: e1 } = await supabase
        .from('challenges')
        .select('id,reptador_id,reptat_id')
        .eq('tipus', 'access')
        .in('estat', ['proposat', 'acceptat', 'programat'])
        .order('data_proposta', { ascending: true });
      if (e1) throw e1;

      const ids = Array.from(
        new Set([...(ch?.map((c) => c.reptador_id) ?? []), ...(ch?.map((c) => c.reptat_id) ?? [])])
      );
      const { data: players, error: e2 } = await supabase
        .from('players')
        .select('id,nom')
        .in('id', ids);
      if (e2) throw e2;
      const nameById = new Map(players?.map((p) => [p.id, p.nom]) ?? []);
      rows = (ch ?? []).map((c) => ({
        ...c,
        reptador_nom: nameById.get(c.reptador_id) ?? '—',
        reptat_nom: nameById.get(c.reptat_id) ?? '—'
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
