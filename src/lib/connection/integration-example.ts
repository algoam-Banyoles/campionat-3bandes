// Integration example for the connection fallback system
import { onMount } from 'svelte';
import { get } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { connectionManager, isConnected, connectionQuality } from '$lib/connection/connectionManager';
import { offlineQueue, queueOperation, hasQueuedOperations } from '$lib/connection/offlineQueue';
import { syncManager, manualSync } from '$lib/connection/syncManager';
import { serviceWorkerManager } from '$lib/connection/serviceWorker';
import { offlineStorage } from '$lib/connection/offlineStorage';

/**
 * Example integration in a Svelte component
 */
export function useConnectionFallbacks() {
  onMount(() => {
    // Register service worker for offline functionality
    const initServiceWorker = async () => {
      if (serviceWorkerManager.isSupported()) {
        await serviceWorkerManager.register();
        console.log('✅ Service Worker registered');
      }
    };
    initServiceWorker();

    let unsubscribeConnection: (() => void) | undefined;
    let unsubscribeQuality: (() => void) | undefined;

    // Listen for connection changes
    unsubscribeConnection = isConnected.subscribe(connected => {
      if (connected) {
        console.log('🟢 Connection restored');
        // Trigger manual sync if there are queued operations
        if (hasQueuedOperations()) {
          manualSync().catch(console.error);
        }
      } else {
        console.log('🔴 Connection lost - entering offline mode');
      }
    });

    // Listen for connection quality changes
    unsubscribeQuality = connectionQuality.subscribe(quality => {
      console.log(`📶 Connection quality: ${quality}`);
    });

    // Cleanup
    return () => {
      if (unsubscribeConnection) unsubscribeConnection();
      if (unsubscribeQuality) unsubscribeQuality();
    };
  });
}

/**
 * Example: Execute a challenge operation with offline support
 */
export async function acceptChallengeWithFallback(challengeId: string, userId: string) {
  try {
    // This will automatically handle offline queuing if no connection
    await connectionManager.executeWithRetry(
      async () => {
        // Your Supabase operation here
        const { error } = await supabase
          .from('challenges')
          .update({ estat: 'acceptat', data_acceptacio: new Date().toISOString() })
          .eq('id', challengeId);

        if (error) throw error;
      },
      'critical' // High priority retry strategy
    );

    console.log('✅ Challenge accepted successfully');
    
  } catch (error) {
    // If connection fails, operation will be queued automatically
    console.log('⏳ Challenge acceptance queued for when connection returns');
    
    // Queue the operation with high priority
    await queueOperation(
      'challenge_accept',
      async () => {
        const { error } = await supabase
          .from('challenges')
          .update({ estat: 'acceptat', data_acceptacio: new Date().toISOString() })
          .eq('id', challengeId);
        if (error) throw error;
      },
      { challengeId, action: 'accept' },
      { priority: 'critical', userId, maxRetries: 5 }
    );
  }
}

/**
 * Example: Prefetch critical data when connection is good
 */
export async function prefetchCriticalData() {
  const quality = get(connectionQuality);
  
  if (quality === 'excellent' || quality === 'good') {
    const urlsToPrefetch = [
      '/api/ranking',
      '/api/challenges/active',
      '/api/players/active'
    ];
    
    await serviceWorkerManager.prefetchResources(urlsToPrefetch);
    console.log('📦 Critical data prefetched for offline use');
  }
}

/**
 * Example: Check offline capabilities
 */
export async function checkOfflineCapabilities() {
  const storageInfo = await offlineStorage.getStorageInfo();
  const cacheStatus = await serviceWorkerManager.getCacheStatus();
  
  console.log('💾 Offline Storage:', storageInfo);
  console.log('🗂️ Cache Status:', cacheStatus);
  
  return {
    hasOfflineData: storageInfo.stats.itemCount > 0,
    cacheSize: Object.values(cacheStatus).reduce((total, cache: any) => total + (cache?.size || 0), 0),
    isReady: storageInfo.isReady
  };
}

/**
 * Example: Manual sync trigger
 */
export async function triggerManualSync() {
  try {
    await manualSync();
    console.log('🔄 Manual sync completed successfully');
  } catch (error) {
    console.error('❌ Manual sync failed:', error);
    throw error;
  }
}