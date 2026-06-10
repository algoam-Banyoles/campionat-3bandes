<script lang="ts">
  import { onMount } from 'svelte';
  import Loader from '$lib/components/general/Loader.svelte';
  import Banner from '$lib/components/general/Banner.svelte';
  import { supabase } from '$lib/supabaseClient';
  import { formatSupabaseError } from '$lib/ui/alerts';
  import { CHALLENGE_STATE_LABEL } from '$lib/ui/challengeState';
  import { mySociNumero } from '$lib/stores/mySoci';

  // Filtre "només meves" (canvis i reptes propis)
  let onlyMine = false;

  type Change = {
    creat_el: string;
    soci_numero: number;
    posicio_anterior: number | null;
    posicio_nova: number | null;
    motiu: string | null;
    ref_challenge: string | null;
  };

  type ChallengeRow = {
    id: string;
    reptador_soci_numero: number;
    reptat_soci_numero: number;
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

  let players: Record<number, string> = {};

  // filters for changes
  let filterPlayer: number | '' = '';
  let filterMotiu = '';
  let filterFrom = '';
  let filterTo = '';

  // filters for challenges
  let filterChallengePlayer: number | '' = '';
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
      .eq('tipus_competicio', 'ranking_continu')
      .order('data_inici', { ascending: false })
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
        .select('creat_el, soci_numero, posicio_anterior, posicio_nova, motiu, ref_challenge')
        .eq('event_id', eventId)
        .order('creat_el', { ascending: false })
        .limit(50);
      if (lastDate) {
        query = query.lt('creat_el', lastDate);
      }
      const { data, error } = await query;
      if (error) throw error;
      const rows: Change[] = (data ?? []) as Change[];
      if (rows.length > 0) {
        changes = [...changes, ...rows];
        lastDate = rows[rows.length - 1].creat_el;
        const ids = Array.from(new Set(rows.map((r) => r.soci_numero).filter((n): n is number => n != null)));
        const missing = ids.filter((id) => !players[id]);
        if (missing.length > 0) {
          const { data: pl, error: e2 } = await supabase
            .from('socis')
            .select('numero_soci, nom')
            .in('numero_soci', missing);
          if (e2) throw e2;
          for (const p of pl ?? []) {
            players[(p as any).numero_soci] = (p as any).nom;
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
          'id,reptador_soci_numero,reptat_soci_numero,estat,data_proposta,matches(id,caramboles_reptador,caramboles_reptat)'
        )
        .eq('event_id', eventId)
        .order('data_proposta', { ascending: false });
      if (error) throw error;
      challenges = (data ?? []) as ChallengeRow[];
      const ids = Array.from(
        new Set(
          challenges
            .flatMap((c) => [c.reptador_soci_numero, c.reptat_soci_numero])
            .filter((n): n is number => n != null)
        )
      );
      const missing = ids.filter((id) => !players[id]);
      if (missing.length > 0) {
        const { data: pl, error: e2 } = await supabase
          .from('socis')
          .select('numero_soci, nom')
          .in('numero_soci', missing);
        if (e2) throw e2;
        for (const p of pl ?? []) {
          players[(p as any).numero_soci] = (p as any).nom;
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
    if (onlyMine && $mySociNumero != null && c.soci_numero !== $mySociNumero) return false;
    if (filterPlayer !== '' && c.soci_numero !== filterPlayer) return false;
    if (filterMotiu && !(c.motiu ?? '').toLowerCase().includes(filterMotiu.toLowerCase()))
      return false;
    const date = new Date(c.creat_el);
    if (filterFrom && date < new Date(filterFrom)) return false;
    if (filterTo && date > new Date(filterTo + 'T23:59:59')) return false;
    return true;
  });

  $: filteredChallenges = challenges.filter((c) => {
    if (
      onlyMine &&
      $mySociNumero != null &&
      c.reptador_soci_numero !== $mySociNumero &&
      c.reptat_soci_numero !== $mySociNumero
    )
      return false;
    if (
      filterChallengePlayer !== '' &&
      c.reptador_soci_numero !== filterChallengePlayer &&
      c.reptat_soci_numero !== filterChallengePlayer
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
  <title>Historial — Campionat Continu</title>
</svelte:head>

<div class="hist-root">

<header class="page-mast">
  <div>
    <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Campionat continu</div>
    <h1 class="page-title">Historial</h1>
  </div>
</header>

<section class="hist-section">
  <h2 class="section-title">Moviments de posició</h2>
  {#if loadingChanges && changes.length === 0}
    <Loader />
  {:else if errorChanges}
    <Banner type="error" message={errorChanges} />
  {:else}
    <div class="mb-4 flex flex-wrap gap-2 items-end">
      {#if $mySociNumero}
        <label class="mine-toggle">
          <input type="checkbox" bind:checked={onlyMine} />
          <span>Només meves</span>
        </label>
      {/if}
      <select class="rounded-xl border px-3 py-2" bind:value={filterPlayer} disabled={onlyMine}>
        <option value="">Tots els jugadors</option>
        {#each Object.entries(players).sort((a, b) => a[1].localeCompare(b[1])) as [id, name]}
          <option value={Number(id)}>{name}</option>
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
        on:click={() => { clearChangeFilters(); onlyMine = false; }}
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
              <td class="p-2">{players[r.soci_numero] ?? 'Jugador desconegut'}</td>
              <td class="p-2">{r.posicio_anterior ?? '—'} → {r.posicio_nova ?? '—'}</td>
              <td class="p-2">{r.motiu ?? '—'}</td>
              <td class="p-2">
                {#if r.ref_challenge}
                  <span class="text-slate-700">{r.ref_challenge}</span>
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

<section class="hist-section">
  <h2 class="section-title">Reptes</h2>
  {#if loadingChallenges && challenges.length === 0}
    <Loader />
  {:else if errorChallenges}
    <Banner type="error" message={errorChallenges} />
  {:else}
    <div class="mb-4 flex flex-wrap gap-2 items-end">
      {#if $mySociNumero}
        <label class="mine-toggle">
          <input type="checkbox" bind:checked={onlyMine} />
          <span>Només meves</span>
        </label>
      {/if}
      <select class="rounded-xl border px-3 py-2" bind:value={filterChallengePlayer} disabled={onlyMine}>
        <option value="">Tots els jugadors</option>
        {#each Object.entries(players).sort((a, b) => a[1].localeCompare(b[1])) as [id, name]}
          <option value={Number(id)}>{name}</option>
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
        on:click={() => { clearChallengeFilters(); onlyMine = false; }}
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
              <td class="p-2">{players[c.reptador_soci_numero] ?? 'Jugador desconegut'}</td>
              <td class="p-2">{players[c.reptat_soci_numero] ?? 'Jugador desconegut'}</td>
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

</div>

<style>
  .hist-root {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    font-family: var(--font-sans);
    color: var(--ink);
  }

  .page-mast {
    padding-bottom: 1rem;
    border-bottom: 2px solid var(--ink);
  }
  .editorial-eyebrow {
    font-size: 0.75rem; font-weight: 600;
    letter-spacing: 0.16em; text-transform: uppercase;
    color: var(--sec-continu);
  }
  .page-title {
    font-weight: 800; font-size: 2rem;
    letter-spacing: -0.025em; line-height: 1.05;
    margin: 0; color: var(--ink);
  }

  .hist-section {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.25rem 1.5rem;
  }
  .section-title {
    font-weight: 800;
    font-size: 1.25rem;
    letter-spacing: -0.022em;
    margin: 0 0 1rem;
    padding-bottom: 0.65rem;
    border-bottom: 2px solid var(--ink);
    color: var(--ink);
  }

  /* Filtres */
  .hist-section :global(select),
  .hist-section :global(input[type='text']),
  .hist-section :global(input[type='date']) {
    background: var(--paper-elevated) !important;
    border: 1px solid var(--rule-strong) !important;
    border-radius: 0 !important;
    color: var(--ink) !important;
    padding: 0.45rem 0.75rem !important;
    font-family: var(--font-sans);
    min-height: 40px;
  }
  .hist-section :global(select:focus),
  .hist-section :global(input:focus) {
    outline: 2px solid var(--ink) !important;
    border-color: var(--ink) !important;
  }

  /* Botó "Neteja filtres" */
  .hist-section :global(button.bg-slate-200) {
    background: transparent !important;
    border: 1px solid var(--rule-strong) !important;
    border-radius: 0 !important;
    color: var(--ink) !important;
    font-weight: 600;
    min-height: 40px;
  }
  .hist-section :global(button.bg-slate-200:hover) {
    border-color: var(--ink) !important;
  }
  /* Botó "Carrega'n més" */
  .hist-section :global(button.bg-slate-900) {
    background: var(--ink) !important;
    border: 1px solid var(--ink) !important;
    border-radius: 0 !important;
    color: var(--paper) !important;
    font-weight: 600;
    min-height: 44px;
  }

  /* Taules */
  .hist-section :global(table) {
    width: 100%;
    border-collapse: collapse;
    border: 1px solid var(--rule);
  }
  .hist-section :global(table th) {
    font-size: 0.625rem !important;
    font-weight: 600 !important;
    text-transform: uppercase !important;
    letter-spacing: 0.14em !important;
    color: var(--ink-3) !important;
    background: var(--paper) !important;
    padding: 0.75rem !important;
    border-bottom: 1px solid var(--rule);
  }
  .hist-section :global(table td) {
    padding: 0.75rem !important;
    border-bottom: 1px solid var(--rule);
    color: var(--ink) !important;
    font-size: 0.875rem;
  }
  .hist-section :global(table tr:hover td) {
    background: var(--paper);
  }
  .hist-section :global(.text-blue-600) {
    color: var(--blue) !important;
    text-decoration: none !important;
    border-bottom: 1px solid var(--blue);
    padding-bottom: 1px;
  }

  .mine-toggle {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.5rem 0.85rem;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule-strong, #b8b3a8);
    cursor: pointer;
    font-family: var(--font-sans, sans-serif);
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--ink, #1a1814);
    user-select: none;
  }
  .mine-toggle:hover { border-color: var(--ink, #1a1814); }
  .mine-toggle input[type='checkbox'] {
    width: 1rem;
    height: 1rem;
    accent-color: var(--ink, #1a1814);
    cursor: pointer;
  }
</style>
