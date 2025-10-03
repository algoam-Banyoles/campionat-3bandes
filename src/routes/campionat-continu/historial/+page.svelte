<script lang="ts">
  import { onMount } from 'svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import Banner from '$lib/components/general/Banner.svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';

  type Change = {
    creat_el: string;
    player_id: string;
    posicio_anterior: number | null;
    posicio_nova: number | null;
    motiu: string | null;
    ref_challenge: string | null;
  };

  type ChallengeRow = {
    id: string;
    reptador_id: string;
    reptat_id: string;
    estat: string;
    data_proposta: string;
    matches: { caramboles_reptador: number; caramboles_reptat: number }[];
  };

  let loadingChanges = true;
  let errorChanges: string | null = null;
  let changes: Change[] = [];

  let loadingChallenges = true;
  let errorChallenges: string | null = null;
  let challenges: ChallengeRow[] = [];

  let players: Record<string, string> = {};

  // filters for changes
  let filterPlayer = '';
  let filterMotiu = '';
  let filterFrom = '';
  let filterTo = '';

  // filters for challenges
  let filterChallengePlayer = '';
  let filterEstat = '';

  let hasMore = false;
  let lastDate: string | null = null;
  let eventId: string | null = null;

  const challengeStateLabel = (state: string): string => CHALLENGE_STATE_LABEL[state] ?? state;

  async function fetchEvent(): Promise<void> {
    const { data, error } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .order('creat_el', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    eventId = data?.id ?? null;
  }

  async function loadMoreChanges(): Promise<void> {
    try {
      loadingChanges = true;
      errorChanges = null;
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
      const { data, error } = await query;
      if (error) throw error;
      const rows: Change[] = data ?? [];
      if (rows.length > 0) {
        changes = [...changes, ...rows];
        lastDate = rows[rows.length - 1].creat_el;
        const ids = Array.from(new Set(rows.map((r) => r.player_id)));
        const missing = ids.filter((id) => !players[id]);
        if (missing.length > 0) {
          const { data: pl, error: e2 } = await supabase
            .from('players')
            .select('id, socis!inner(nom)')
            .in('id', missing);
          if (e2) throw e2;
          for (const p of pl ?? []) {
            players[p.id] = (p.socis as any)?.nom;
          }
        }
      }
      hasMore = rows.length === 50;
    } catch (e) {
      errorChanges = formatSupabaseError(e);
    } finally {
      loadingChanges = false;
    }
  }

  async function loadChallenges(): Promise<void> {
    try {
      loadingChallenges = true;
      errorChallenges = null;
      if (!eventId) await fetchEvent();
      if (!eventId) {
        throw new Error('No hi ha cap esdeveniment actiu.');
      }
      const { data, error } = await supabase
        .from('challenges')
        .select(
          'id,reptador_id,reptat_id,estat,data_proposta,matches(id,caramboles_reptador,caramboles_reptat)'
        )
        .eq('event_id', eventId)
        .order('data_proposta', { ascending: false });
      if (error) throw error;
      challenges = data ?? [];
      const ids = Array.from(
        new Set(challenges.flatMap((c) => [c.reptador_id, c.reptat_id]))
      );
      const missing = ids.filter((id) => !players[id]);
      if (missing.length > 0) {
        const { data: pl, error: e2 } = await supabase
          .from('players')
          .select('id, socis!inner(nom)')
          .in('id', missing);
        if (e2) throw e2;
        for (const p of pl ?? []) {
          players[p.id] = (p.socis as any)?.nom;
        }
      }
    } catch (e) {
      errorChallenges = formatSupabaseError(e);
    } finally {
      loadingChallenges = false;
    }
  }

  function clearChangeFilters() {
    filterPlayer = '';
    filterMotiu = '';
    filterFrom = '';
    filterTo = '';
  }

  function clearChallengeFilters() {
    filterChallengePlayer = '';
    filterEstat = '';
  }

  $: filteredChanges = changes.filter((c) => {
    if (filterPlayer && c.player_id !== filterPlayer) return false;
    if (filterMotiu && !(c.motiu ?? '').toLowerCase().includes(filterMotiu.toLowerCase()))
      return false;
    const date = new Date(c.creat_el);
    if (filterFrom && date < new Date(filterFrom)) return false;
    if (filterTo && date > new Date(filterTo + 'T23:59:59')) return false;
    return true;
  });

  $: filteredChallenges = challenges.filter((c) => {
    if (
      filterChallengePlayer &&
      c.reptador_id !== filterChallengePlayer &&
      c.reptat_id !== filterChallengePlayer
    )
      return false;
    if (filterEstat && c.estat !== filterEstat) return false;
    return true;
  });

  onMount(() => {
    loadMoreChanges();
    loadChallenges();
  });
</script>

<svelte:head>
  <title>Historial</title>
</svelte:head>

<h1 class="text-2xl font-semibold mb-4">Historial</h1>

<section class="mb-8">
  <h2 class="text-xl font-semibold mb-2">Moviments de posició</h2>
  {#if loadingChanges && changes.length === 0}
    <Loader />
  {:else if errorChanges}
    <Banner type="error" message={errorChanges} />
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
        on:click={clearChangeFilters}
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
          {#each filteredChanges as r}
            <tr class="border-t">
              <td class="p-2 whitespace-nowrap">{new Date(r.creat_el).toLocaleString()}</td>
              <td class="p-2">{players[r.player_id] ?? 'Jugador desconegut'}</td>
              <td class="p-2">{r.posicio_anterior ?? '—'} → {r.posicio_nova ?? '—'}</td>
              <td class="p-2">{r.motiu ?? '—'}</td>
              <td class="p-2">
                {#if r.ref_challenge}
                  <a
                    href={`/reptes/${r.ref_challenge}`}
                    class="text-blue-600 underline"
                    >{r.ref_challenge}</a
                  >
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
          on:click={loadMoreChanges}
          disabled={loadingChanges}
        >
          {#if loadingChanges}Carregant…{:else}Carrega'n més{/if}
        </button>
      </div>
    {/if}
  {/if}
</section>

<section>
  <h2 class="text-xl font-semibold mb-2">Reptes</h2>
  {#if loadingChallenges && challenges.length === 0}
    <Loader />
  {:else if errorChallenges}
    <Banner type="error" message={errorChallenges} />
  {:else}
    <div class="mb-4 flex flex-wrap gap-2 items-end">
      <select class="rounded-xl border px-3 py-2" bind:value={filterChallengePlayer}>
        <option value="">Tots els jugadors</option>
        {#each Object.entries(players).sort((a, b) => a[1].localeCompare(b[1])) as [id, name]}
          <option value={id}>{name}</option>
        {/each}
      </select>
      <select class="rounded-xl border px-3 py-2" bind:value={filterEstat}>
        <option value="">Tots els estats</option>
        <option value="proposat">{CHALLENGE_STATE_LABEL.proposat}</option>
        <option value="acceptat">{CHALLENGE_STATE_LABEL.acceptat}</option>
        <option value="programat">{CHALLENGE_STATE_LABEL.programat}</option>
        <option value="refusat">refusat</option>
        <option value="caducat">{CHALLENGE_STATE_LABEL.caducat}</option>
        <option value="jugat">{CHALLENGE_STATE_LABEL.jugat}</option>
        <option value="anullat">{CHALLENGE_STATE_LABEL.anullat}</option>
      </select>
      <button
        class="rounded-xl bg-slate-200 px-3 py-2 text-sm"
        on:click={clearChallengeFilters}
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
            <th class="p-2">Reptador</th>
            <th class="p-2">Reptat</th>
            <th class="p-2">Estat</th>
            <th class="p-2">Resultat</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredChallenges as c}
            <tr class="border-t">
              <td class="p-2 whitespace-nowrap">{new Date(c.data_proposta).toLocaleString()}</td>
              <td class="p-2">{players[c.reptador_id] ?? 'Jugador desconegut'}</td>
              <td class="p-2">{players[c.reptat_id] ?? 'Jugador desconegut'}</td>
              <td class="p-2">{challengeStateLabel(c.estat)}</td>
              <td class="p-2">
                {#if c.matches && c.matches.length > 0}
                  {c.matches[0].caramboles_reptador} - {c.matches[0].caramboles_reptat}
                {:else}
                  —
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</section>

<style>
  table th,
  table td {
    border-color: rgb(203 213 225);
  }
</style>
