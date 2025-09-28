<!-- src/lib/components/PerformanceMetrics.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { performanceMonitor } from '$lib/monitoring/performance';
  import type { PerformanceDashboard } from '$lib/monitoring/performance';

  export let visible = false;
  export let compact = false;

  let dashboard: PerformanceDashboard | null = null;
  let refreshInterval: NodeJS.Timeout;

  onMount(() => {
    if (visible) {
      loadDashboard();
      // Actualitzar cada 10 segons
      refreshInterval = setInterval(loadDashboard, 10000);
    }
  });

  onDestroy(() => {
    if (refreshInterval) {
      clearInterval(refreshInterval);
    }
  });

  $: if (visible && !dashboard) {
    loadDashboard();
  }

  async function loadDashboard() {
    try {
      dashboard = await performanceMonitor.getDashboard();
    } catch (error) {
      console.warn('Error loading performance dashboard:', error);
    }
  }

  function formatDuration(ms: number): string {
    if (ms < 1000) return `${Math.round(ms)}ms`;
    return `${(ms / 1000).toFixed(1)}s`;
  }

  function getCacheHitRateColor(rate: number): string {
    if (rate >= 0.8) return 'text-green-600';
    if (rate >= 0.6) return 'text-yellow-600';
    return 'text-red-600';
  }

  function getErrorRateColor(rate: number): string {
    if (rate <= 0.01) return 'text-green-600';
    if (rate <= 0.05) return 'text-yellow-600';
    return 'text-red-600';
  }
</script>

{#if visible && dashboard}
  <div class="performance-metrics bg-gray-50 p-4 rounded-lg border {compact ? 'text-sm' : ''}">
    <h3 class="font-semibold mb-3 flex items-center">
      <span class="w-2 h-2 bg-green-500 rounded-full mr-2 animate-pulse"></span>
      Mètriques de Rendiment
    </h3>

    <div class="grid {compact ? 'grid-cols-2 gap-2' : 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4'}">
      <!-- Temps de resposta mitjà -->
      <div class="metric-card bg-white p-3 rounded shadow-sm">
        <div class="text-xs text-gray-500 uppercase tracking-wide">Temps Resposta Mitjà</div>
        <div class="text-lg font-semibold text-blue-600">
          {formatDuration(dashboard.summary.averageResponseTime)}
        </div>
      </div>

      <!-- Taxa de hit del cache -->
      <div class="metric-card bg-white p-3 rounded shadow-sm">
        <div class="text-xs text-gray-500 uppercase tracking-wide">Cache Hit Rate</div>
        <div class="text-lg font-semibold {getCacheHitRateColor(dashboard.summary.cacheHitRate)}">
          {(dashboard.summary.cacheHitRate * 100).toFixed(1)}%
        </div>
      </div>

      <!-- Total de requests -->
      <div class="metric-card bg-white p-3 rounded shadow-sm">
        <div class="text-xs text-gray-500 uppercase tracking-wide">Total Requests</div>
        <div class="text-lg font-semibold text-purple-600">
          {dashboard.summary.totalRequests.toLocaleString()}
        </div>
      </div>

      <!-- Taxa d'error -->
      <div class="metric-card bg-white p-3 rounded shadow-sm">
        <div class="text-xs text-gray-500 uppercase tracking-wide">Error Rate</div>
        <div class="text-lg font-semibold {getErrorRateColor(dashboard.summary.errorRate)}">
          {(dashboard.summary.errorRate * 100).toFixed(2)}%
        </div>
      </div>
    </div>

    {#if !compact}
      <!-- Consultes més lentes -->
      {#if dashboard.summary.slowestQueries.length > 0}
        <div class="mt-4">
          <h4 class="font-medium text-gray-700 mb-2">Consultes Més Lentes</h4>
          <div class="space-y-1">
            {#each dashboard.summary.slowestQueries.slice(0, 3) as query}
              <div class="flex justify-between items-center bg-white p-2 rounded text-sm">
                <span class="font-mono text-gray-600 truncate">{query.name}</span>
                <span class="text-red-600 font-semibold">{formatDuration(query.duration)}</span>
              </div>
            {/each}
          </div>
        </div>
      {/if}

      <!-- Mètriques de cache per tipus -->
      <div class="mt-4">
        <h4 class="font-medium text-gray-700 mb-2">Cache per Tipus</h4>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
          {#each Object.entries(dashboard.cacheMetrics) as [key, metric]}
            <div class="bg-white p-2 rounded text-sm">
              <div class="flex justify-between">
                <span class="font-medium">{key}</span>
                <span class="{getCacheHitRateColor(metric.hitRate)}">
                  {(metric.hitRate * 100).toFixed(0)}%
                </span>
              </div>
              <div class="text-gray-500 text-xs">
                {metric.hitCount}/{metric.totalCount} hits
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/if}

    <div class="mt-3 text-xs text-gray-400 text-right">
      Actualitzat: {new Date(dashboard.summary.lastUpdated).toLocaleTimeString()}
    </div>
  </div>
{/if}

<style>
  .performance-metrics {
    font-family: system-ui, -apple-system, sans-serif;
  }
  
  .metric-card {
    transition: transform 0.2s ease;
  }
  
  .metric-card:hover {
    transform: translateY(-1px);
  }
</style>