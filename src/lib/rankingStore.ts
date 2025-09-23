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

    // Consulta més robusta: primer agafar ranking_positions, després obtenir detalls dels socis
    const { data: rankingData, error: rankingError } = await supabase
      .from('ranking_positions')
      .select('posicio, player_id')
      .eq('event_id', activeEvent.id)
      .order('posicio', { ascending: true });

    if (rankingError) {
      throw new Error(rankingError.message);
    }

    if (!rankingData || rankingData.length === 0) {
      ranking.set([]);
      return;
    }

    // Estructura actual: ranking_positions -> players -> socis
    const playerIds = rankingData.map(r => r.player_id);
    
    // Obtenir dades de players amb l'estructura actual
    const { data: playersData, error: playersError } = await supabase
      .from('players')
      .select('id, nom, numero_soci, mitjana, estat, data_ultim_repte')
      .in('id', playerIds);

    if (playersError) {
      console.warn('Error getting players data:', playersError.message);
      ranking.set([]);
      return;
    }

    // Obtenir nom i cognoms reals de socis mitjançant numero_soci
    const numerosSoci = playersData?.filter(p => p.numero_soci).map(p => p.numero_soci) || [];
    let socisData = null;
    if (numerosSoci.length > 0) {
      const { data, error: socisError } = await supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .in('numero_soci', numerosSoci);

      if (socisError) {
        console.warn('Error getting socis data:', socisError.message);
      } else {
        socisData = data;
      }
    }

    // Crear maps per combinar dades
    const playersMap = new Map(playersData?.map(p => [p.id, p]) || []);
    const socisMap = new Map(socisData?.map((s: any) => [s.numero_soci, s]) || []);

    // Transformar les dades al format correcte combinant ranking amb players i socis
    const finalRankingData: RankingRow[] = rankingData.map((item: any) => {
      const player = playersMap.get(item.player_id) as any;
      const soci = player?.numero_soci ? socisMap.get(player.numero_soci) as any : null;
      
      // Generar nom: inicial del nom real de socis + primer cognom
      let displayName = 'Desconegut';
      if (soci?.nom && soci?.cognoms) {
        const inicial = soci.nom.charAt(0).toUpperCase();
        const primerCognom = soci.cognoms.split(' ')[0];
        displayName = `${inicial}. ${primerCognom}`;
      } else if (player?.nom) {
        // Fallback si no hi ha dades de soci
        displayName = player.nom;
      }
      
      return {
        posicio: item.posicio,
        player_id: item.player_id,
        nom: displayName,
        cognoms: soci?.cognoms || null,
        mitjana: player?.mitjana || null,
        estat: player?.estat || 'actiu',
        data_ultim_repte: player?.data_ultim_repte || null,
        numero_soci: player?.numero_soci || 0
      };
    });

    ranking.set(finalRankingData);

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
