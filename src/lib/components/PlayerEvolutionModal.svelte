<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { createEventDispatcher } from 'svelte';

  export let playerId: string;
  export let playerName: string;

  const dispatch = createEventDispatcher();

  let loading = true;
  let error: string | null = null;
  let points: { week: number; pos: number }[] = [];
  let canvasEl: HTMLCanvasElement;
  let chart: any = null;

  function close() {
    dispatch('close');
  }

  onDestroy(() => {
    if (chart) {
      chart.destroy();
      chart = null;
    }
  });

  onMount(async () => {
    const { supabase } = await import('$lib/supabaseClient');
    try {
      // Fetch weekly positions for the player
      const { data, error: err } = await supabase
        .from('player_weekly_positions')
        .select('setmana, posicio')
        .eq('player_id', playerId)
        .order('setmana', { ascending: true });
      if (err) throw err;
      const rows = (data ?? []) as { setmana: number; posicio: number }[];
      rows.sort((a, b) => a.setmana - b.setmana);
      if (rows.length > 0) {
        let lastWeek = rows[0].setmana;
        let lastPos = rows[0].posicio;
        points.push({ week: lastWeek, pos: lastPos });
        for (let i = 1; i < rows.length; i++) {
          const row = rows[i];
          for (let w = lastWeek + 1; w < row.setmana; w++) {
            points.push({ week: w, pos: lastPos });
          }
          lastWeek = row.setmana;
          lastPos = row.posicio;
          points.push({ week: lastWeek, pos: lastPos });
        }
      }
    } catch (e: any) {
      error = e?.message ?? 'Error desconegut';
    } finally {
      loading = false;
      await drawChart();
    }
  });

  async function drawChart() {
    if (!canvasEl || points.length === 0) return;
    if (!(window as any).Chart) {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js';
      document.head.appendChild(script);
      await new Promise((resolve) => (script.onload = resolve));
    }
    const Chart = (window as any).Chart;
    const ctx = canvasEl.getContext('2d');
    chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: points.map((p) => `Setmana ${p.week}`),
        datasets: [
          {
            label: 'Posició',
            data: points.map((p) => p.pos),
            tension: 0,
            pointRadius: 4,
            fill: false
          }
        ]
      },
      options: {
        scales: {
          y: {
            reverse: true,
            min: 1,
            max: 20,
            ticks: { stepSize: 1 }
          }
        }
      }
    });
  }
</script>

<div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
  <div class="bg-white rounded-lg shadow-lg w-full max-w-xl p-4">
    <div class="flex justify-between items-center mb-4">
      <h2 class="text-lg font-semibold">Evolució de {playerName}</h2>
      <button class="text-gray-500" on:click={close} aria-label="Tanca">✕</button>
    </div>
    {#if loading}
      <p class="text-slate-500">Carregant evolució…</p>
    {:else if error}
      <div class="text-red-600">Error: {error}</div>
    {:else if points.length === 0}
      <p class="text-slate-500">Encara no hi ha evolució registrada</p>
    {:else}
      <canvas bind:this={canvasEl} class="w-full h-64"></canvas>
    {/if}
  </div>
</div>
