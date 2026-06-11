<script lang="ts">
  import { goto } from '$app/navigation';
      // Guard: només admins en vista admin (respecta el toggle viewMode).
      $: if ($adminChecked && !$effectiveIsAdmin) {
        goto('/campionat-continu/reptes');
      }

    import { onMount } from 'svelte';
    import { user } from '$lib/stores/auth';
    import { adminChecked } from '$lib/stores/adminAuth';
    import { effectiveIsAdmin } from '$lib/stores/viewMode';
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
      await Promise.all([load(), refreshRanking(), invalidate('/campionat-continu/llista-espera')]);
    } catch (e: any) {
      error = e?.message ?? 'Error resolent repte';
    } finally {
      busy = null;
    }
  }
</script>

<svelte:head><title>Reptes d'accés</title></svelte:head>

<div class="gr-sub-root">
  <header class="gr-sub-mast">
    <div class="editorial-eyebrow">Rànquing continu · Reptes</div>
    <h1>Reptes d'accés</h1>
  </header>

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
</div>

<style>
  .gr-sub-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .gr-sub-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .gr-sub-mast .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .gr-sub-mast h1 {
    margin: 0.4rem 0 0;
    font-size: clamp(1.5rem, 2vw, 2rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .gr-sub-root :global(.bg-white) { background: var(--paper-elevated, #fff) !important; }
  .gr-sub-root :global(.bg-slate-100),
  .gr-sub-root :global(.bg-gray-100) { background: var(--paper, #fbfaf6) !important; }
  .gr-sub-root :global(.text-slate-500),
  .gr-sub-root :global(.text-slate-600),
  .gr-sub-root :global(.text-slate-700) { color: var(--ink-2, #4a443e) !important; }
  .gr-sub-root :global(.rounded),
  .gr-sub-root :global(.rounded-md),
  .gr-sub-root :global(.rounded-lg) { border-radius: 0 !important; }
  .gr-sub-root :global(input),
  .gr-sub-root :global(select),
  .gr-sub-root :global(textarea),
  .gr-sub-root :global(button.rounded) {
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule-strong, #b8b3a8);
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
</style>
