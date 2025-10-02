// src/lib/rankingStore.ts
import { writable, get } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { cacheManager } from '$lib/cache/strategies';
import { connectionManager, isConnected } from '$lib/connection/connectionManager';
import { offlineStorage, getAllOffline, storeOffline } from '$lib/connection/offlineStorage';
import { formatPlayerDisplayName } from '$lib/utils/playerName';
import { performanceMonitor } from '$lib/monitoring/performance';

import type { RankingPosition } from '$lib/types';

export type RankingRow = RankingPosition;

export const ranking = writable<RankingRow[]>([]);

export async function refreshRanking(force = false): Promise<void> {

  try {
    // Primer, agafar l'event actiu del RANKING CONTINU
    const { data: activeEvent, error: eventError } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .eq('tipus_competicio', 'ranking_continu')
      .order('creat_el', { ascending: false })
      .limit(1)
      .single();

    if (eventError && eventError.code !== 'PGRST116') {
      throw new Error(eventError.message);
    }

    if (!activeEvent) {
      console.warn('No hi ha cap event actiu de ranking continu. Cal crear-ne un des de l\'admin.');
      ranking.set([]);
      return;
    }

    // Consulta amb JOIN a través de players (esquema real de producció)
    const { data: finalRankingData, error: rankingError } = await supabase
      .from('ranking_positions')
      .select(`
        id,
        event_id,
        posicio,
        player_id,
        created_at,
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
        id: item.id,
        event_id: item.event_id,
        posicio: item.posicio,
        player_id: item.player_id,
        created_at: item.created_at,
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
