<script lang="ts">
  import { onMount } from 'svelte';
    import { goto } from '$app/navigation';
    import Loader from '$lib/components/general/Loader.svelte';
    import Banner from '$lib/components/general/Banner.svelte';
    import { supabase } from '$lib/supabaseClient';
    import { formatSupabaseError } from '$lib/ui/alerts';
    import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
    import { initAdminPage } from '$lib/utils/adminPage';

    // Guard: només admins.
    $: if ($adminChecked && !$isAdmin) {
      goto('/campionat-continu/historial');
    }

  type Change = {
    creat_el: string;
    soci_numero: number;
    posicio_anterior: number | null;
    posicio_nova: number | null;
    motiu: string | null;
    ref_challenge: string | null;
  };

  let loading = true;
  let error: string | null = null;
  let changes: Change[] = [];
  let players: Record<number, string> = {};

  // filters
  let filterPlayer = '';
  let filterMotiu = '';
  let filterFrom = '';
  let filterTo = '';

  let hasMore = false;
  let lastDate: string | null = null;
  let eventId: string | null = null;

  async function fetchEvent(): Promise<void> {
    const { data, error: e } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .order('creat_el', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (e) throw e;
    eventId = data?.id ?? null;
  }

  async function loadMore(): Promise<void> {
    try {
      loading = true;
      error = null;
      if (!eventId) await fetchEvent();
      if (!eventId) {
        throw new Error('No hi ha cap esdeveniment actiu.');
      }
      let query = supabase
        .from('history_position_changes')
        .select('creat_el, soci_numero, posicio_anterior, posicio_nova, motiu, ref_challenge')
        .eq('event_id', eventId)
        .order('creat_el', { ascending: false })
        .limit(50);
      if (lastDate) {
        query = query.lt('creat_el', lastDate);
      }
      const { data, error: e } = await query;
      if (e) throw e;
      const rows = (data ?? []) as unknown as Change[];
      if (rows.length > 0) {
        changes = [...changes, ...rows];
        lastDate = rows[rows.length - 1].creat_el;
        const nums = Array.from(new Set(rows.map((r) => r.soci_numero)));
        const missing = nums.filter((n) => !players[n]);
        if (missing.length > 0) {
          const { data: pl, error: e2 } = await supabase
            .from('socis')
            .select('numero_soci, nom')
            .in('numero_soci', missing);
          if (e2) throw e2;
          for (const p of pl ?? []) {
            players[p.numero_soci] = p.nom;
          }
        }
      }
      hasMore = rows.length === 50;
    } catch (e) {
      error = formatSupabaseError(e);
    } finally {
      loading = false;
    }
  }

  function clearFilters() {
    filterPlayer = '';
    filterMotiu = '';
    filterFrom = '';
    filterTo = '';
  }

  $: filtered = changes.filter((c) => {
    if (filterPlayer && String(c.soci_numero) !== filterPlayer) return false;
    if (filterMotiu && !(c.motiu ?? '').toLowerCase().includes(filterMotiu.toLowerCase()))
      return false;
    const date = new Date(c.creat_el);
    if (filterFrom && date < new Date(filterFrom)) return false;
    if (filterTo && date > new Date(filterTo + 'T23:59:59')) return false;
    return true;
  });

  onMount(async () => {
    await initAdminPage(loadMore);
  });
</script>

<svelte:head>
  <title>Historial de canvis al rànquing</title>
</svelte:head>

<div class="hcr-root">
  <header class="hcr-mast">
    <div class="editorial-eyebrow">Rànquing continu · Auditoria</div>
    <h1 class="hcr-title">Historial de canvis de posició</h1>
    <p class="hcr-sub">Registre de moviments del rànquing: pujades, baixades, retirades i penalitzacions.</p>
  </header>

{#if $isAdmin}
  {#if loading && changes.length === 0}
    <Loader />
  {:else if error}
    <Banner type="error" message={error} />
  {:else}
    <div class="mb-4 flex flex-wrap gap-2 items-end">
      <select class="rounded-xl border px-3 py-2" bind:value={filterPlayer}>
        <option value="">Tots els jugadors</option>
        {#each Object.entries(players).sort((a, b) => a[1].localeCompare(b[1])) as [id, name]}
          <option value={id}>{name}</option>
        {/each}
      </select>
      <input
        type="text"
        placeholder="Motiu conté…"
        class="rounded-xl border px-3 py-2"
        bind:value={filterMotiu}
      />
      <input type="date" class="rounded-xl border px-3 py-2" bind:value={filterFrom} />
      <input type="date" class="rounded-xl border px-3 py-2" bind:value={filterTo} />
      <button
        class="rounded-xl bg-slate-200 px-3 py-2 text-sm"
        on:click={clearFilters}
        type="button"
      >
        Neteja filtres
      </button>
    </div>

    <div class="overflow-x-auto">
      <table class="min-w-full border text-sm">
        <thead>
          <tr class="bg-slate-100 text-left">
            <th class="p-2">Data</th>
            <th class="p-2">Jugador</th>
            <th class="p-2">De → A</th>
            <th class="p-2">Motiu</th>
            <th class="p-2">Repte</th>
          </tr>
        </thead>
        <tbody>
          {#each filtered as r}
            <tr class="border-t">
              <td class="p-2 whitespace-nowrap">{new Date(r.creat_el).toLocaleString()}</td>
              <td class="p-2">{players[r.soci_numero] ?? 'Jugador desconegut'}</td>
              <td class="p-2">
                {r.posicio_anterior ?? '—'} → {r.posicio_nova ?? '—'}
              </td>
              <td class="p-2">{r.motiu ?? '—'}</td>
              <td class="p-2">
                {#if r.ref_challenge}
                  <a href={`/campionat-continu/gestio-reptes/${r.ref_challenge}`} class="text-blue-600 underline">{r.ref_challenge}</a>
                {:else}
                  —
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if hasMore}
      <div class="mt-4">
        <button
          class="rounded-xl bg-slate-900 px-4 py-2 text-white disabled:opacity-50"
          on:click={loadMore}
          disabled={loading}
        >
          {#if loading}Carregant…{:else}Carrega'n més{/if}
        </button>
      </div>
    {/if}
  {/if}
{:else}
  <p class="muted">No autoritzat</p>
{/if}
</div>

<style>
  .hcr-root {
    max-width: 1180px;
    margin: 0 auto;
    padding: 1.75rem 1.25rem 4rem;
    font-family: var(--font-sans, sans-serif);
    color: var(--ink, #1a1814);
  }
  .hcr-mast {
    margin-bottom: 1.5rem;
    padding-bottom: 1.1rem;
    border-bottom: 2px solid var(--ink, #1a1814);
  }
  .editorial-eyebrow {
    font-size: 0.625rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.16em;
    color: var(--ink-3, #807a72);
  }
  .hcr-title {
    margin: 0.4rem 0 0.4rem;
    font-size: clamp(1.75rem, 2.4vw, 2.4rem);
    font-weight: 800;
    letter-spacing: -0.022em;
    line-height: 1.1;
  }
  .hcr-sub {
    margin: 0;
    font-size: 0.9375rem;
    color: var(--ink-2, #4a443e);
    max-width: 56ch;
  }
  .muted { color: var(--ink-3, #807a72); font-size: 0.875rem; }

  /* Overrides Tailwind dins .hcr-root */
  .hcr-root :global(table) { font-family: var(--font-sans, sans-serif); }
  .hcr-root :global(table th),
  .hcr-root :global(table td) { border-color: var(--rule, #e6e3dc); }
  .hcr-root :global(thead.bg-slate-100) {
    background: var(--paper, #fbfaf6) !important;
    border-bottom: 1px solid var(--ink, #1a1814) !important;
  }
  .hcr-root :global(.bg-slate-100),
  .hcr-root :global(.bg-slate-200) { background: var(--paper, #fbfaf6) !important; }
  .hcr-root :global(.bg-slate-900) {
    background: var(--ink, #1a1814) !important;
    color: var(--paper, #fbfaf6) !important;
  }
  .hcr-root :global(.text-slate-600),
  .hcr-root :global(.text-slate-700) { color: var(--ink-2, #4a443e) !important; }
  .hcr-root :global(.text-blue-600) { color: var(--ink, #1a1814) !important; }
  .hcr-root :global(.rounded),
  .hcr-root :global(.rounded-sm),
  .hcr-root :global(.rounded-md),
  .hcr-root :global(.rounded-lg),
  .hcr-root :global(.rounded-xl),
  .hcr-root :global(.rounded-full) { border-radius: 0 !important; }
  .hcr-root :global(input),
  .hcr-root :global(select) {
    background: var(--paper-elevated, #fff) !important;
    border: 1px solid var(--rule-strong, #b8b3a8) !important;
    border-radius: 0 !important;
    font-family: var(--font-sans, sans-serif);
  }
  .hcr-root :global(input:focus),
  .hcr-root :global(select:focus) {
    outline: 2px solid var(--ink, #1a1814);
    outline-offset: -1px;
  }
</style>
