// src/lib/rankingStore.ts
import { writable, get } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { cacheManager } from '$lib/cache/strategies';
import { connectionManager, isConnected } from '$lib/connection/connectionManager';
import { offlineStorage, getAllOffline, storeOffline } from '$lib/connection/offlineStorage';
import { formatPlayerDisplayName } from '$lib/utils/playerName';
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
  nom: string | null;
  cognoms: string | null;
  mitjana: number | null;
  estat: 'actiu' | 'inactiu' | 'pre_inactiu' | 'baixa';
  data_ultim_repte: string | null;
  numero_soci: number;
};

export const ranking = writable<RankingRow[]>([]);

export async function refreshRanking(force = false): Promise<void> {

  try {
    // Primer, agafar l'event actiu
    const { data: activeEvent, error: eventError } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .order('creat_el', { ascending: false })
      .limit(1)
      .single();

    if (eventError) {
      throw new Error(eventError.message);
    }

    if (!activeEvent) {
      ranking.set([]);
      return;
    }

    // Consulta amb JOIN a través de players (esquema real de producció)
    const { data: finalRankingData, error: rankingError } = await supabase
      .from('ranking_positions')
      .select(`
        posicio,
        player_id,
        players!inner (
          id,
          mitjana,
          estat,
          data_ultim_repte,
          numero_soci,
          socis (
            numero_soci,
            nom,
            cognoms
          )
        )
      `)
      .eq('event_id', activeEvent.id)
      .order('posicio', { ascending: true });

    if (rankingError) {
      throw new Error(rankingError.message);
    }

    if (!finalRankingData || finalRankingData.length === 0) {
      ranking.set([]);
      return;
    }

    // Transformar les dades al format correcte
    const transformedData: RankingRow[] = finalRankingData.map((item: any) => {
      const player = item.players;
      const soci = player?.socis;

      return {
        posicio: item.posicio,
        player_id: item.player_id,
        nom: soci?.nom || null,
        cognoms: soci?.cognoms || null,
        mitjana: player?.mitjana || null,
        estat: player?.estat || 'actiu',
        data_ultim_repte: player?.data_ultim_repte || null,
        numero_soci: player?.numero_soci || 0
      };
    });

    ranking.set(transformedData);

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
