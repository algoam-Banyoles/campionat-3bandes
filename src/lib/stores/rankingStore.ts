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

    // Fase 5c-S3: llegim soci_numero directe i fem JOIN a socis + socis_jugador.
    // player_id eliminat del SELECT.
    const { data: finalRankingData, error: rankingError } = await supabase
      .from('ranking_positions')
      .select(`
        event_id,
        posicio,
        soci_numero,
        socis!ranking_positions_soci_numero_fkey (
          numero_soci,
          nom,
          cognoms,
          socis_jugador (
            mitjana,
            estat,
            data_ultim_repte
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
      const soci = Array.isArray(item.socis) ? item.socis[0] : item.socis;
      const sj = soci ? (Array.isArray(soci.socis_jugador) ? soci.socis_jugador[0] : soci.socis_jugador) : null;

      return {
        id: `${item.event_id}-${item.soci_numero}`,
        event_id: item.event_id,
        posicio: item.posicio,
        soci_numero: item.soci_numero,
        created_at: new Date().toISOString(),
        nom: soci?.nom || null,
        cognoms: soci?.cognoms || null,
        mitjana: sj?.mitjana ?? null,
        estat: sj?.estat || 'actiu',
        data_ultim_repte: sj?.data_ultim_repte || null,
        numero_soci: item.soci_numero || 0
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
