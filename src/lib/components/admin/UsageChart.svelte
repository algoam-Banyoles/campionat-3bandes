<script lang="ts">
  import { onMount } from 'svelte';
  import * as echarts from 'echarts';

  export let option: echarts.EChartsOption;
  export let height = 320;

  let dom: HTMLDivElement;
  let chart: echarts.ECharts | null = null;

  function refresh() {
    if (chart && option) chart.setOption(option, true);
  }

  onMount(() => {
    chart = echarts.init(dom);
    refresh();
    const onResize = () => chart?.resize();
    window.addEventListener('resize', onResize);
    return () => {
      window.removeEventListener('resize', onResize);
      chart?.dispose();
      chart = null;
    };
  });

  $: if (chart && option) refresh();
</script>

<div bind:this={dom} class="usage-chart" style="height:{height}px"></div>

<style>
  .usage-chart {
    width: 100%;
    background: var(--paper-elevated, #fff);
    border: 1px solid var(--rule, #e6e3dc);
  }
</style>
