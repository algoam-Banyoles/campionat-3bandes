<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabaseClient';

  let loading = true;
  let error: string | null = null;
  let playerName = '';
  let points: { x: number; y: number }[] = [];

  const width = 600;
  const height = 200;

  $: xs = points.map((p) => p.x);
  $: ys = points.map((p) => p.y);
  $: minX = xs.length ? Math.min(...xs) : 0;
  $: maxX = xs.length ? Math.max(...xs) : 0;
  $: minY = ys.length ? Math.min(...ys) : 0;
  $: maxY = ys.length ? Math.max(...ys) : 0;
  $: polyPoints = points.length
    ? points
        .map((p) => {
          const x = ((p.x - minX) / (maxX - minX || 1)) * width;
          const y = ((p.y - minY) / (maxY - minY || 1)) * height;
          return `${x},${y}`;
        })
        .join(' ')
    : '';
  $: circles = points.length
    ? points.map((p) => ({
        cx: ((p.x - minX) / (maxX - minX || 1)) * width,
        cy: ((p.y - minY) / (maxY - minY || 1)) * height
      }))
    : [];

  onMount(async () => {
    const id = $page.params.id;
    try {
      // id is soci_numero (URL param).
      const sociNumero = Number(id);
      const { data: sociData, error: sErr } = await supabase
        .from('socis')
        .select('nom')
        .eq('numero_soci', sociNumero)
        .maybeSingle();
      if (sErr) throw sErr;
      playerName = sociData?.nom ?? '';

      const { data: event, error: eErr } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .eq('tipus_competicio', 'ranking_continu')
        .order('data_inici', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (eErr) throw eErr;
      const eventId = event?.id;
      if (!eventId) throw new Error('No hi ha cap esdeveniment actiu');

      const { data: changes, error: cErr } = await supabase
        .from('history_position_changes')
        .select('creat_el,posicio_nova')
        .eq('soci_numero', sociNumero)
        .eq('event_id', eventId)
        .order('creat_el', { ascending: true });
      if (cErr) throw cErr;

      points = (changes ?? [])
        .filter((c) => c.posicio_nova != null)
        .map((c) => ({
          x: new Date(c.creat_el).getTime(),
          y: c.posicio_nova as number
        }));
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Evolució de {playerName} — Campionat Continu</title>
</svelte:head>

<div class="evol-root">

<header class="page-mast">
  <div>
    <div class="editorial-eyebrow" style="margin-bottom: 0.4rem;">Campionat continu</div>
    <h1 class="page-title">Evolució de {playerName}</h1>
  </div>
</header>

{#if loading}
  <div class="state-empty">Carregant evolució…</div>
{:else if error}
  <div class="state-empty error-state">Error: {error}</div>
{:else if points.length === 0}
  <div class="state-empty">No hi ha dades de rànquing.</div>
{:else}
  <div class="chart-card">
    <svg viewBox={`0 0 ${width} ${height}`} class="chart-svg">
      <polyline
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        points={polyPoints}
      />
      {#each circles as c}
        <circle cx={c.cx} cy={c.cy} r="3" fill="currentColor" />
      {/each}
    </svg>
  </div>
{/if}

</div>

<style>
  .evol-root {
    display: flex; flex-direction: column; gap: 1.25rem;
    font-family: var(--font-sans); color: var(--ink);
  }
  .page-mast { padding-bottom: 1rem; border-bottom: 2px solid var(--ink); }
  .editorial-eyebrow {
    font-size: 0.75rem; font-weight: 600;
    letter-spacing: 0.16em; text-transform: uppercase;
    color: var(--sec-continu);
  }
  .page-title {
    font-weight: 800; font-size: 1.625rem;
    letter-spacing: -0.022em; margin: 0;
  }
  .state-empty {
    padding: 1.25rem 1.5rem;
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    color: var(--ink-2);
    text-align: center;
  }
  .state-empty.error-state { color: var(--accent); border-color: var(--accent); }
  .chart-card {
    background: var(--paper-elevated);
    border: 1px solid var(--rule);
    padding: 1.25rem;
    color: var(--ink);
  }
  .chart-svg { width: 100%; max-width: 42rem; }
</style>
