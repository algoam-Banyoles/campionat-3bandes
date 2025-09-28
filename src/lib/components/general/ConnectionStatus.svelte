<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { connectionState, connectionQuality } from '$lib/connection/connectionManager';
  import { syncState, isSyncing, lastSync } from '$lib/connection/syncManager';
  import { queueStats } from '$lib/connection/offlineQueue';
  import type { ConnectionState } from '$lib/connection/connectionManager';

  export let showDetails = false;
  export let position: 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left' = 'top-right';
  export let compact = false;

  let connectionStatus: ConnectionState;
  let quality: string;
  let lastSyncTime: Date | null;
  let syncing: boolean;
  let queueInfo: any;
  let currentSyncState: any;

  let intervalId: number | null = null;
  let relativeTimeText = '';

  let unsubscribers: (() => void)[] = [];

  onMount(() => {
    // Subscribe to all relevant stores
    unsubscribers = [
      connectionState.subscribe(state => connectionStatus = state),
      connectionQuality.subscribe(q => quality = q),
      lastSync.subscribe((time: Date | null) => {
        lastSyncTime = time;
        updateRelativeTime();
      }),
      isSyncing.subscribe(s => syncing = s),
      queueStats.subscribe(stats => queueInfo = stats),
      syncState.subscribe(state => currentSyncState = state)
    ];

    // Update relative time every minute
    intervalId = window.setInterval(updateRelativeTime, 60000);
  });

  onDestroy(() => {
    unsubscribers.forEach(unsub => unsub?.());
    if (intervalId) clearInterval(intervalId);
  });

  function updateRelativeTime() {
    if (!lastSyncTime) {
      relativeTimeText = 'Mai';
      return;
    }

    const now = new Date();
    const diffMs = now.getTime() - lastSyncTime.getTime();
    const diffMinutes = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMinutes / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMinutes < 1) {
      relativeTimeText = 'Ara mateix';
    } else if (diffMinutes < 60) {
      relativeTimeText = `Fa ${diffMinutes}m`;
    } else if (diffHours < 24) {
      relativeTimeText = `Fa ${diffHours}h`;
    } else {
      relativeTimeText = `Fa ${diffDays}d`;
    }
  }

  function getStatusColor(status: ConnectionState): string {
    if (!status.isOnline) return 'bg-gray-500';
    if (!status.isConnected) return 'bg-red-500';
    if (status.isRetrying) return 'bg-yellow-500';
    
    switch (quality) {
      case 'excellent': return 'bg-green-500';
      case 'good': return 'bg-green-400';
      case 'poor': return 'bg-yellow-400';
      default: return 'bg-red-500';
    }
  }

  function getStatusText(status: ConnectionState): string {
    if (!status.isOnline) return 'Offline';
    if (!status.isConnected) return 'Desconnectat';
    if (status.isRetrying) return `Reintentant (${status.retryCount})`;
    if (syncing) return 'Sincronitzant...';
    
    switch (quality) {
      case 'excellent': return 'Excel·lent';
      case 'good': return 'Bona';
      case 'poor': return 'Lenta';
      default: return 'Connectat';
    }
  }

  function getPositionClasses(pos: string): string {
    const base = 'fixed z-50';
    switch (pos) {
      case 'top-right': return `${base} top-4 right-4`;
      case 'top-left': return `${base} top-4 left-4`;
      case 'bottom-right': return `${base} bottom-4 right-4`;
      case 'bottom-left': return `${base} bottom-4 left-4`;
      default: return `${base} top-4 right-4`;
    }
  }

  function toggleDetails() {
    showDetails = !showDetails;
  }
</script>

<div class="{getPositionClasses(position)} select-none">
  <!-- Compact indicator -->
  {#if compact}
    <div 
      class="flex items-center space-x-2 bg-white dark:bg-gray-800 rounded-full px-3 py-1 shadow-lg border border-gray-200 dark:border-gray-700 cursor-pointer hover:shadow-xl transition-shadow"
      on:click={toggleDetails}
      role="button"
      tabindex="0"
      on:keydown={(e) => e.key === 'Enter' && toggleDetails()}
    >
      <div class="w-2 h-2 rounded-full {getStatusColor(connectionStatus)} animate-pulse"></div>
      <span class="text-xs font-medium text-gray-700 dark:text-gray-300">
        {getStatusText(connectionStatus)}
      </span>
      {#if queueInfo?.total > 0}
        <span class="bg-orange-100 dark:bg-orange-900 text-orange-800 dark:text-orange-200 text-xs px-1.5 py-0.5 rounded-full">
          {queueInfo.total}
        </span>
      {/if}
    </div>
  {:else}
    <!-- Full status card -->
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg border border-gray-200 dark:border-gray-700 p-4 min-w-72">
      <!-- Header -->
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center space-x-2">
          <div class="w-3 h-3 rounded-full {getStatusColor(connectionStatus)} {connectionStatus?.isRetrying ? 'animate-pulse' : ''}"></div>
          <h3 class="text-sm font-semibold text-gray-900 dark:text-gray-100">
            Estat de Connexió
          </h3>
        </div>
        <button
          on:click={toggleDetails}
          class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
          aria-label="Amagar detalls"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>

      <!-- Status Info -->
      <div class="space-y-2">
        <div class="flex justify-between items-center">
          <span class="text-sm text-gray-600 dark:text-gray-400">Estat:</span>
          <span class="text-sm font-medium text-gray-900 dark:text-gray-100">
            {getStatusText(connectionStatus)}
          </span>
        </div>

        {#if connectionStatus?.isConnected}
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600 dark:text-gray-400">Qualitat:</span>
            <span class="text-sm font-medium capitalize text-gray-900 dark:text-gray-100">
              {quality}
            </span>
          </div>
        {/if}

        <div class="flex justify-between items-center">
          <span class="text-sm text-gray-600 dark:text-gray-400">Última sync:</span>
          <span class="text-sm font-medium text-gray-900 dark:text-gray-100">
            {relativeTimeText}
          </span>
        </div>

        {#if queueInfo?.total > 0}
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600 dark:text-gray-400">Cua offline:</span>
            <span class="bg-orange-100 dark:bg-orange-900 text-orange-800 dark:text-orange-200 text-xs px-2 py-1 rounded-full font-medium">
              {queueInfo.total} pendents
            </span>
          </div>
        {/if}

        {#if connectionStatus?.isRetrying}
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600 dark:text-gray-400">Reintents:</span>
            <span class="text-sm font-medium text-gray-900 dark:text-gray-100">
              {connectionStatus.retryCount} / {connectionStatus.retryDelay}ms
            </span>
          </div>
        {/if}

        {#if syncing}
          <div class="flex items-center space-x-2 mt-2">
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-500"></div>
            <span class="text-sm text-blue-600 dark:text-blue-400">Sincronitzant dades...</span>
          </div>
        {/if}

        {#if currentSyncState?.syncErrors && currentSyncState.syncErrors.length > 0}
          <div class="mt-2 p-2 bg-red-50 dark:bg-red-900/20 rounded border border-red-200 dark:border-red-800">
            <div class="flex items-center space-x-1">
              <svg class="w-4 h-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <span class="text-xs font-medium text-red-800 dark:text-red-300">Errors recents</span>
            </div>
            <div class="mt-1 text-xs text-red-700 dark:text-red-400 max-h-20 overflow-y-auto">
              {currentSyncState.syncErrors[0]}
            </div>
          </div>
        {/if}
      </div>

      <!-- Details -->
      {#if showDetails}
        <div class="mt-4 pt-3 border-t border-gray-200 dark:border-gray-700">
          <div class="grid grid-cols-2 gap-2 text-xs">
            <div>
              <span class="text-gray-500 dark:text-gray-400">Navegador:</span>
              <span class="text-gray-900 dark:text-gray-100">{connectionStatus?.isOnline ? 'Online' : 'Offline'}</span>
            </div>
            <div>
              <span class="text-gray-500 dark:text-gray-400">Servidor:</span>
              <span class="text-gray-900 dark:text-gray-100">{connectionStatus?.isConnected ? 'Connectat' : 'Desconnectat'}</span>
            </div>
            {#if connectionStatus?.lastConnected}
              <div class="col-span-2">
                <span class="text-gray-500 dark:text-gray-400">Última connexió:</span>
                <span class="text-gray-900 dark:text-gray-100">
                  {connectionStatus.lastConnected.toLocaleString('ca')}
                </span>
              </div>
            {/if}
          </div>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  /* Ensure animations work smoothly */
  .animate-pulse {
    animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }

  .animate-spin {
    animation: spin 1s linear infinite;
  }

  @keyframes pulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: .5;
    }
  }

  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }
</style>