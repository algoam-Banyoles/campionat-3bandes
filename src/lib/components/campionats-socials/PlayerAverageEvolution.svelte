<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import * as echarts from 'echarts';
  import type { ECharts } from 'echarts';

  export let history: any[] = [];
  export let playerName: string = '';
  export let modalitat: string = '';

  let chartContainer: HTMLDivElement;
  let chart: ECharts | null = null;

  $: if (chart && history.length > 0) {
    updateChart();
  }

  onMount(() => {
    if (chartContainer) {
      chart = echarts.init(chartContainer);
      updateChart();

      // Handle window resize
      const handleResize = () => {
        chart?.resize();
      };
      window.addEventListener('resize', handleResize);

      return () => {
        window.removeEventListener('resize', handleResize);
      };
    }
  });

  onDestroy(() => {
    chart?.dispose();
  });

  function updateChart() {
    if (!chart || history.length === 0) return;

    // Prepare data for the chart
    const temporades = history.map(h => h.temporada);
    const mitjanes = history.map(h => h.mitjana_particular || 0);
    const posicions = history.map(h => h.posicio);
    const categories = history.map(h => h.categoria_nom);

    const option = {
      title: {
        text: `Evolució de Mitjanes - ${playerName}`,
        subtext: modalitat ? `Modalitat: ${getModalitatName(modalitat)}` : 'Totes les modalitats',
        left: 'center'
      },
      tooltip: {
        trigger: 'axis',
        formatter: (params: any) => {
          const dataIndex = params[0].dataIndex;
          return `
            <strong>${temporades[dataIndex]}</strong><br/>
            Categoria: ${categories[dataIndex]}<br/>
            Mitjana: <strong>${mitjanes[dataIndex].toFixed(3)}</strong><br/>
            Posició: ${posicions[dataIndex]}
          `;
        }
      },
      legend: {
        data: ['Mitjana Particular', 'Posició'],
        top: 40
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '3%',
        containLabel: true
      },
      xAxis: {
        type: 'category',
        boundaryGap: false,
        data: temporades,
        axisLabel: {
          rotate: 45
        }
      },
      yAxis: [
        {
          type: 'value',
          name: 'Mitjana',
          position: 'left',
          axisLabel: {
            formatter: '{value}'
          }
        },
        {
          type: 'value',
          name: 'Posició',
          position: 'right',
          inverse: true,
          axisLabel: {
            formatter: '{value}'
          }
        }
      ],
      series: [
        {
          name: 'Mitjana Particular',
          type: 'line',
          data: mitjanes,
          smooth: true,
          symbol: 'circle',
          symbolSize: 8,
          lineStyle: {
            width: 3,
            color: '#3b82f6'
          },
          itemStyle: {
            color: '#3b82f6'
          },
          areaStyle: {
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(59, 130, 246, 0.3)' },
              { offset: 1, color: 'rgba(59, 130, 246, 0.05)' }
            ])
          }
        },
        {
          name: 'Posició',
          type: 'line',
          yAxisIndex: 1,
          data: posicions,
          smooth: true,
          symbol: 'diamond',
          symbolSize: 8,
          lineStyle: {
            width: 2,
            color: '#f59e0b',
            type: 'dashed'
          },
          itemStyle: {
            color: '#f59e0b'
          }
        }
      ]
    };

    chart.setOption(option);
  }

  function getModalitatName(mod: string): string {
    const names: Record<string, string> = {
      'tres_bandes': '3 Bandes',
      'lliure': 'Lliure',
      'banda': 'Banda'
    };
    return names[mod] || mod;
  }
</script>

<div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
  <div bind:this={chartContainer} class="w-full" style="height: 400px;"></div>

  {#if history.length === 0}
    <div class="flex items-center justify-center h-96">
      <div class="text-center">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">Sense dades</h3>
        <p class="mt-1 text-sm text-gray-500">No hi ha històric disponible per aquest jugador</p>
      </div>
    </div>
  {/if}
</div>