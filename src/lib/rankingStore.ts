// src/lib/rankingStore.ts
import { writable } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { cacheManager } from '$lib/cache/strategies';
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
    // Utilitzar wrapper automàtic de mesurament de rendiment
    const data = await performanceMonitor.measure(
      'ranking_query',
      'database',
      async () => {
        return await cacheManager.get(
          'ranking', 
          async () => {
            const { data, error } = await supabase.rpc('get_ranking');
            if (error) {
              console.warn('[rankingStore] get_ranking error:', error.message);
              throw new Error(error.message);
            }
            return (data as RankingRow[]) ?? [];
          },
          force ? 'network-first' : 'cache-first'
        );
      },
      { forceRefresh: force }
    );
    
    ranking.set(data);
    
  } catch (error: any) {
    console.warn('[rankingStore] refreshRanking error:', error.message);
    ranking.set([]);
  }
}

// Invalidar cache del ranking (útil després d'actualitzacions)
export function invalidateRankingCache(): void {
  cacheManager.invalidate('ranking');
  
  // També invalidar caches relacionats
  cacheManager.invalidate('activeChallenges');
  cacheManager.invalidate('playerStats');
}
