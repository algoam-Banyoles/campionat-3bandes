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

    // Group data by modality
    const modalitats = ['tres_bandes', 'lliure', 'banda'];
    const modalitatColors = {
      'tres_bandes': '#3b82f6', // Blue
      'lliure': '#10b981',      // Green
      'banda': '#f59e0b'        // Orange
    };

    // Get all unique temporades
    const allTemporades = [...new Set(history.map(h => h.temporada))].sort();

    // Prepare series data for each modality
    const series = modalitats.map(mod => {
      const modData = history.filter(h => h.modalitat === mod);

      // Create data array with null for missing temporades
      const data = allTemporades.map(temp => {
        const record = modData.find(d => d.temporada === temp);
        return record ? record.mitjana_particular : null;
      });

      return {
        name: getModalitatName(mod),
        type: 'line',
        data: data,
        smooth: true,
        symbol: 'circle',
        symbolSize: 8,
        connectNulls: false,
        lineStyle: {
          width: 3,
          color: modalitatColors[mod]
        },
        itemStyle: {
          color: modalitatColors[mod]
        },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: modalitatColors[mod] + '40' },
            { offset: 1, color: modalitatColors[mod] + '10' }
          ])
        }
      };
    }).filter(s => s.data.some(d => d !== null)); // Only include modalities with data

    const option = {
      title: {
        text: `Evolució de Mitjanes - ${playerName}`,
        subtext: modalitat ? `Modalitat: ${getModalitatName(modalitat)}` : 'Totes les modalitats',
        left: 'center',
        top: 10
      },
      tooltip: {
        trigger: 'axis',
        formatter: (params: any) => {
          if (!params || params.length === 0) return '';

          const temporada = params[0].axisValue;
          let tooltip = `<strong>${temporada}</strong><br/>`;

          params.forEach((param: any) => {
            if (param.value !== null) {
              const record = history.find(h => h.temporada === temporada && h.modalitat ===
                (param.seriesName === '3 Bandes' ? 'tres_bandes' :
                 param.seriesName === 'Lliure' ? 'lliure' : 'banda'));

              tooltip += `<span style="color:${param.color}">●</span> ${param.seriesName}: <strong>${param.value.toFixed(3)}</strong>`;
              if (record) {
                tooltip += ` (${record.categoria_nom})`;
              }
              tooltip += '<br/>';
            }
          });

          return tooltip;
        }
      },
      legend: {
        data: series.map(s => s.name),
        top: 60,
        left: 'center'
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '3%',
        top: '100px',
        containLabel: true
      },
      xAxis: {
        type: 'category',
        boundaryGap: false,
        data: allTemporades,
        axisLabel: {
          rotate: 45
        }
      },
      yAxis: {
        type: 'value',
        name: 'Mitjana',
        axisLabel: {
          formatter: '{value}'
        }
      },
      series: series
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