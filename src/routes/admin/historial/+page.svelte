<script lang="ts">
  import { onMount } from 'svelte';
  import Loader from '$lib/components/Loader.svelte';
  import Banner from '$lib/components/Banner.svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError } from '$lib/ui/alerts';
    import { adminStore } from '$lib/authStore';

  type Change = {
    creat_el: string;
    player_id: string;
    posicio_anterior: number | null;
    posicio_nova: number | null;
    motiu: string | null;
    ref_challenge: string | null;
  };

  let loading = true;
  let error: string | null = null;
  let changes: Change[] = [];
  let players: Record<string, string> = {};

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
        .select('creat_el, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge')
        .eq('event_id', eventId)
        .order('creat_el', { ascending: false })
        .limit(50);
      if (lastDate) {
        query = query.lt('creat_el', lastDate);
      }
      const { data, error: e } = await query;
      if (e) throw e;
      const rows: Change[] = data ?? [];
      if (rows.length > 0) {
        changes = [...changes, ...rows];
        lastDate = rows[rows.length - 1].creat_el;
        const ids = Array.from(new Set(rows.map((r) => r.player_id)));
        const missing = ids.filter((id) => !players[id]);
        if (missing.length > 0) {
          const { data: pl, error: e2 } = await supabase
            .from('players')
            .select('id, nom')
            .in('id', missing);
          if (e2) throw e2;
          for (const p of pl ?? []) {
            players[p.id] = p.nom;
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
    if (filterPlayer && c.player_id !== filterPlayer) return false;
    if (filterMotiu && !(c.motiu ?? '').toLowerCase().includes(filterMotiu.toLowerCase()))
      return false;
    const date = new Date(c.creat_el);
    if (filterFrom && date < new Date(filterFrom)) return false;
    if (filterTo && date > new Date(filterTo + 'T23:59:59')) return false;
    return true;
  });

  onMount(loadMore);
</script>

<svelte:head>
  <title>Historial de moviments</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Historial de moviments</h1>

{#if $adminStore}
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
              <td class="p-2">{players[r.player_id] ?? r.player_id}</td>
              <td class="p-2">
                {r.posicio_anterior ?? '—'} → {r.posicio_nova ?? '—'}
              </td>
              <td class="p-2">{r.motiu ?? '—'}</td>
              <td class="p-2">
                {#if r.ref_challenge}
                  <a href={`/admin/reptes/${r.ref_challenge}`} class="text-blue-600 underline">{r.ref_challenge}</a>
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
  <p>No autoritzat</p>
{/if}

<style>
  table th, table td { border-color: rgb(203 213 225); }
</style>
