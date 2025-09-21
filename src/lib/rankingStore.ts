// src/lib/rankingStore.ts
import { writable, get } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { cacheManager } from '$lib/cache/strategies';
import { connectionManager, isConnected } from '$lib/connection/connectionManager';
import { offlineStorage, getAllOffline, storeOffline } from '$lib/connection/offlineStorage';
// import { performanceMonitor } from '$lib/monitoring/performance';

// Stub temporal mentre TypeScript recompila
const performanceMonitor = {
  measure: async <T>(name: string, category: string, fn: () => Promise<T>, metadata?: any): Promise<T> => {
    return await fn();
  }
};

export type RankingRow = {
  posicio: number;
  player_id: string;
  nom: string;
  mitjana: number | null;
  estat: string;
};

export const ranking = writable<RankingRow[]>([]);

export async function refreshRanking(force = false): Promise<void> {
  
  try {
    // Crida directa a Supabase sense cache ni connexionManager
    const { data, error } = await supabase.rpc('get_ranking');
    
    if (error) {
      throw new Error(error.message);
    }
    
    const rankingData = (data as RankingRow[]) ?? [];
    ranking.set(rankingData);
    
  } catch (error: any) {
    ranking.set([]);
    throw error;
  }
}

// Invalidar cache del ranking (útil després d'actualitzacions)
export function invalidateRankingCache(): void {
  cacheManager.invalidate('ranking');
  
  // També invalidar caches relacionats
  cacheManager.invalidate('activeChallenges');
  cacheManager.invalidate('playerStats');
}
