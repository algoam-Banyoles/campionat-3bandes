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
      const { data: player, error: pErr } = await supabase
        .from('socis')
        .select('nom')
        .eq('id', id)
        .maybeSingle();
      if (pErr) throw pErr;
      playerName = player?.nom ?? '';

      const { data: event, error: eErr } = await supabase
        .from('events')
        .select('id')
        .eq('actiu', true)
        .order('creat_el', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (eErr) throw eErr;
      const eventId = event?.id;
      if (!eventId) throw new Error('No hi ha cap esdeveniment actiu');

      const { data: changes, error: cErr } = await supabase
        .from('history_position_changes')
        .select('creat_el,posicio_nova')
        .eq('player_id', id)
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
  <title>Evolució de {playerName}</title>
</svelte:head>

<h1 class="text-xl font-semibold mb-4">Evolució de {playerName}</h1>

{#if loading}
  <p class="text-slate-500">Carregant evolució…</p>
{:else if error}
  <div class="mb-4 rounded border border-red-200 bg-red-50 p-3 text-red-700">Error: {error}</div>
{:else if points.length === 0}
  <p class="text-slate-500">No hi ha dades de rànquing.</p>
{:else}
  <svg viewBox={`0 0 ${width} ${height}`} class="w-full max-w-2xl">
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
{/if}
