<script lang="ts">
  import { onMount } from 'svelte';
  import { isOnline, isConnected } from '$lib/connection/connectionManager';
  import { queueStats } from '$lib/connection/offlineQueue';
  import { isSyncing } from '$lib/connection/syncManager';

  export let showWhenOnline = false; // Whether to show indicator when everything is working
  export let position: 'top' | 'bottom' = 'top';
  export let theme: 'light' | 'dark' | 'auto' = 'auto';

  let online: boolean;
  let connected: boolean;
  let syncing: boolean;
  let queueInfo: any;
  let visible = false;

  onMount(() => {
    isOnline.subscribe(value => {
      online = value;
      updateVisibility();
    });

    isConnected.subscribe(value => {
      connected = value;
      updateVisibility();
    });

    isSyncing.subscribe(value => {
      syncing = value;
      updateVisibility();
    });

    queueStats.subscribe(stats => {
      queueInfo = stats;
      updateVisibility();
    });
  });

  function updateVisibility() {
    const hasIssues = !online || !connected || (queueInfo?.total > 0);
    const hasActivity = syncing;
    
    visible = showWhenOnline || hasIssues || hasActivity;
  }

  function getIndicatorText(): string {
    if (!online) {
      return '📵 Sense connexió a internet';
    }
    
    if (!connected) {
      return '🔌 Desconnectat del servidor';
    }
    
    if (syncing) {
      return '🔄 Sincronitzant dades...';
    }
    
    if (queueInfo?.total > 0) {
      const plural = queueInfo.total > 1 ? 's' : '';
      return `⏳ ${queueInfo.total} operació${plural} pendent${plural}`;
    }
    
    return '✅ Tot funcionant correctament';
  }

  function getIndicatorClass(): string {
    const baseClasses = 'transition-all duration-300 ease-in-out px-4 py-2 text-sm font-medium shadow-lg';
    const positionClasses = position === 'top' 
      ? 'top-0 transform -translate-y-full' 
      : 'bottom-0 transform translate-y-full';
    
    let colorClasses = '';
    
    if (!online || !connected) {
      colorClasses = 'bg-red-500 text-white';
    } else if (queueInfo?.total > 0) {
      colorClasses = 'bg-orange-400 text-white';
    } else if (syncing) {
      colorClasses = 'bg-blue-500 text-white';
    } else {
      colorClasses = 'bg-green-500 text-white';
    }

    const themeClasses = theme === 'dark' ? 'dark' : theme === 'light' ? '' : 'auto';
    
    return `${baseClasses} ${positionClasses} ${colorClasses} ${themeClasses}`;
  }

  function handleClick() {
    // Could emit event for parent to handle or show more details
    const event = new CustomEvent('indicatorClick', {
      detail: {
        online,
        connected,
        syncing,
        queueInfo
      }
    });
    
    if (typeof window !== 'undefined') {
      window.dispatchEvent(event);
    }
  }
</script>

<!-- Offline/Connection Issues Indicator -->
{#if visible}
  <div 
    class="fixed left-0 right-0 z-50 {position === 'top' ? 'top-0' : 'bottom-0'}"
    role="alert"
    aria-live="polite"
  >
    <button
      type="button"
      class="w-full text-center {getIndicatorClass()} cursor-pointer hover:opacity-90"
      on:click={handleClick}
      aria-label="Detalls de l'indicador de connexió"
    >
      <div class="flex items-center justify-center space-x-2">
        <span>{getIndicatorText()}</span>
        
        {#if syncing}
          <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white opacity-75"></div>
        {/if}
        
        {#if queueInfo?.total > 0}
          <span class="bg-white bg-opacity-25 px-2 py-1 rounded-full text-xs">
            {queueInfo.total}
          </span>
        {/if}
  </div>
      
      <!-- Progress bar for syncing -->
      {#if syncing}
        <div class="absolute bottom-0 left-0 h-1 bg-white bg-opacity-30 animate-pulse w-full"></div>
      {/if}
  </button>
  </div>
{/if}

<style>
  .animate-spin {
    animation: spin 1s linear infinite;
  }

  .animate-pulse {
    animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }

  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }

  @keyframes pulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: .5;
    }
  }

  /* Smooth slide-in animation */
  div[role="alert"] {
    animation: slideIn 0.3s ease-out;
  }

  @keyframes slideIn {
    from {
      transform: translateY(-100%);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  /* Dark mode support */
  @media (prefers-color-scheme: dark) {
    .auto {
      color-scheme: dark;
    }
  }
</style>