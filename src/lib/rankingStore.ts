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
  const connected = get(isConnected);
  
  try {
    // Si no hi ha connexió, intentar carregar des del storage offline
    if (!connected) {
      console.log('[rankingStore] Offline mode - loading from local storage');
      const offlineRanking = await getAllOffline('ranquing');
      
      if (offlineRanking.length > 0) {
        // Convertir format de storage a format de ranking
        const rankingData: RankingRow[] = offlineRanking.map((item, index) => ({
          posicio: item.posicio || index + 1,
          player_id: item.soci_id.toString(),
          nom: `Jugador ${item.soci_id}`, // Would need to fetch from socis table
          mitjana: item.mitjana_actual,
          estat: 'actiu'
        }));
        
        ranking.set(rankingData);
        return;
      } else {
        // No hi ha dades offline disponibles
        console.warn('[rankingStore] No offline data available');
        
        throw new Error('No hi ha dades disponibles offline');
      }
    }

    // Mode online amb connexió - intentar amb retry
    const data = await performanceMonitor.measure(
      'ranking_query',
      'database',
      async () => {
        return await connectionManager.executeWithRetry(
          async () => {
            return await cacheManager.get(
              'ranking', 
              async () => {
                const { data, error } = await supabase.rpc('get_ranking');
                if (error) {
                  console.warn('[rankingStore] get_ranking error:', error.message);
                  throw new Error(error.message);
                }
                
                const rankingData = (data as RankingRow[]) ?? [];
                
                // Store in offline storage for future offline access
                if (rankingData.length > 0) {
                  const offlineFormat = rankingData.map(row => ({
                    id: parseInt(row.player_id),
                    soci_id: parseInt(row.player_id),
                    posicio: row.posicio,
                    mitjana_actual: row.mitjana || 0,
                    partides_totals: 0, // Would need additional data
                    victories: 0,
                    derrotes: 0,
                    updated_at: new Date().toISOString()
                  }));
                  
                  await storeOffline('ranquing', offlineFormat);
                }
                
                return rankingData;
              },
              force ? 'network-first' : 'cache-first'
            );
          },
          'standard'
        );
      },
      { forceRefresh: force }
    );
    
    ranking.set(data);
    
  } catch (error: any) {
    console.warn('[rankingStore] refreshRanking error:', error.message);
    
    // Fallback: intentar carregar des del storage offline
    try {
      const offlineRanking = await getAllOffline('ranquing');
      if (offlineRanking.length > 0) {
        console.log('[rankingStore] Using offline data as fallback');
        const rankingData: RankingRow[] = offlineRanking.map((item, index) => ({
          posicio: item.posicio || index + 1,
          player_id: item.soci_id.toString(),
          nom: `Jugador ${item.soci_id}`,
          mitjana: item.mitjana_actual,
          estat: 'actiu'
        }));
        ranking.set(rankingData);
      } else {
        // Últim recurs: array buit
        ranking.set([]);
      }
    } catch (fallbackError) {
      console.warn('[rankingStore] Error loading offline fallback:', fallbackError);
      ranking.set([]);
    }
    
    // Re-throw error per permetre maneig upstream
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
