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

    // Consulta directa amb JOIN per agafar nom i cognoms de socis
    const { data, error } = await supabase
      .from('ranking_positions')
      .select(`
        posicio,
        player_id,
        mitjana,
        estat,
        data_ultim_repte,
        socis!inner (
          numero_soci,
          nom,
          cognoms
        )
      `)
      .eq('event_id', activeEvent.id)
      .order('posicio', { ascending: true });

    if (error) {
      throw new Error(error.message);
    }

    // Transformar les dades al format correcte
    const rankingData: RankingRow[] = (data ?? []).map((item: any) => ({
      posicio: item.posicio,
      player_id: item.player_id,
      nom: item.socis.nom,
      cognoms: item.socis.cognoms,
      mitjana: item.mitjana,
      estat: item.estat,
      data_ultim_repte: item.data_ultim_repte,
      numero_soci: item.socis.numero_soci
    }));

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
