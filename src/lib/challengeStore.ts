// src/lib/challengeStore.ts
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

export type Challenge = {
  id: string;
  event_id: string;
  tipus: 'normal' | 'access';
  reptador_id: string;
  reptat_id: string;
  estat: 'proposat' | 'acceptat' | 'programat' | 'refusat' | 'caducat' | 'jugat' | 'anullat';
  dates_proposades: string[];
  data_proposta: string;
  data_acceptacio?: string | null;
  data_programada?: string | null;
  reprogram_count: number;
  pos_reptador?: number | null;
  pos_reptat?: number | null;
  reptador_nom?: string;
  reptat_nom?: string;
};

export type ChallengeWithPlayers = Challenge & {
  reptador_nom: string;
  reptat_nom: string;
};

export const activeChallenges = writable<ChallengeWithPlayers[]>([]);
export const userChallenges = writable<ChallengeWithPlayers[]>([]);

/**
 * Actualitzar reptes actius amb cache i optimització
 */
export async function refreshActiveChallenges(): Promise<void> {
  try {
    const data = await performanceMonitor.measure(
      'active_challenges_query',
      'database',
      async () => {
        return await cacheManager.get(
          'activeChallenges',
          async () => {
            // Primer obtenir els challenges
            const { data: challenges, error } = await supabase
              .from('challenges')
              .select(`
                id,
                event_id,
                tipus,
                reptador_id,
                reptat_id,
                estat,
                dates_proposades,
                data_proposta,
                data_acceptacio,
                data_programada,
                reprogram_count,
                pos_reptador,
                pos_reptat
              `)
              .in('estat', ['proposat', 'acceptat', 'programat'])
              .order('data_proposta', { ascending: false });

            if (error) {
              console.warn('[challengeStore] refreshActiveChallenges error:', error.message);
              throw new Error(error.message);
            }

            if (!challenges || challenges.length === 0) {
              return [] as ChallengeWithPlayers[];
            }

            // Obtenir noms dels jugadors per separat per evitar duplicació
            const playerIds = Array.from(new Set([
              ...challenges.map(c => c.reptador_id),
              ...challenges.map(c => c.reptat_id)
            ]));

            const { data: players, error: playersError } = await supabase
              .from('players')
              .select('id, nom')
              .in('id', playerIds);

            if (playersError) {
              console.warn('[challengeStore] players query error:', playersError.message);
            }

            // Crear un mapa de jugadors per ID
            const playerMap = new Map<string, string>();
            (players || []).forEach(player => {
              playerMap.set(player.id, player.nom);
            });

            // Processar dades per afegir noms dels jugadors
            const processedData = challenges.map(challenge => ({
              ...challenge,
              reptador_nom: playerMap.get(challenge.reptador_id) || 'Desconegut',
              reptat_nom: playerMap.get(challenge.reptat_id) || 'Desconegut'
            }));

            return processedData as ChallengeWithPlayers[];
          }
        );
      }
    );

    activeChallenges.set(data);

  } catch (error: any) {
    console.warn('[challengeStore] refreshActiveChallenges error:', error.message);
    activeChallenges.set([]);
  }
}

/**
 * Obtenir reptes d'un jugador específic
 */
export async function refreshUserChallenges(playerId: string): Promise<void> {
  try {
    const data = await performanceMonitor.measure(
      'user_challenges_query',
      'database',
      async () => {
        return await cacheManager.get(
          'userChallenges',
          async () => {
            // Primer obtenir els challenges de l'usuari
            const { data: challenges, error } = await supabase
              .from('challenges')
              .select(`
                id,
                event_id,
                tipus,
                reptador_id,
                reptat_id,
                estat,
                dates_proposades,
                data_proposta,
                data_acceptacio,
                data_programada,
                reprogram_count,
                pos_reptador,
                pos_reptat
              `)
              .or(`reptador_id.eq.${playerId},reptat_id.eq.${playerId}`)
              .order('data_proposta', { ascending: false })
              .limit(50); // Limitar per rendiment

            if (error) {
              console.warn('[challengeStore] refreshUserChallenges error:', error.message);
              throw new Error(error.message);
            }

            if (!challenges || challenges.length === 0) {
              return [] as ChallengeWithPlayers[];
            }

            // Obtenir noms dels jugadors per separat
            const playerIds = Array.from(new Set([
              ...challenges.map(c => c.reptador_id),
              ...challenges.map(c => c.reptat_id)
            ]));

            const { data: players, error: playersError } = await supabase
              .from('players')
              .select('id, nom')
              .in('id', playerIds);

            if (playersError) {
              console.warn('[challengeStore] players query error:', playersError.message);
            }

            // Crear un mapa de jugadors per ID
            const playerMap = new Map<string, string>();
            (players || []).forEach(player => {
              playerMap.set(player.id, player.nom);
            });

            // Processar dades per afegir noms dels jugadors
            const processedData = challenges.map(challenge => ({
              ...challenge,
              reptador_nom: playerMap.get(challenge.reptador_id) || 'Desconegut',
              reptat_nom: playerMap.get(challenge.reptat_id) || 'Desconegut'
            }));

            return processedData as ChallengeWithPlayers[];
          },
          `user_${playerId}` // Usar modificador de clau per cache per usuari
        );
      },
      { playerId }
    );

    userChallenges.set(data);

  } catch (error: any) {
    console.warn('[challengeStore] refreshUserChallenges error:', error.message);
    userChallenges.set([]);
  }
}

/**
 * Invalidar cache dels challenges després d'actualitzacions
 */
export function invalidateChallengeCaches(playerId?: string): void {
  cacheManager.invalidate('activeChallenges');
  
  if (playerId) {
    cacheManager.invalidate('userChallenges', `user_${playerId}`);
  }
  
  // També invalidar rankings ja que poden haver canviat
  cacheManager.invalidate('ranking');
}

/**
 * Acceptar un repte i invalidar caches relacionats
 */
export async function acceptChallenge(challengeId: string, playerId?: string): Promise<void> {
  try {
    const { error } = await supabase
      .from('challenges')
      .update({ 
        estat: 'acceptat', 
        data_acceptacio: new Date().toISOString() 
      })
      .eq('id', challengeId);

    if (error) {
      throw new Error(error.message);
    }

    // Invalidar caches i actualitzar dades
    invalidateChallengeCaches(playerId);
    await refreshActiveChallenges();
    
    if (playerId) {
      await refreshUserChallenges(playerId);
    }

  } catch (error: any) {
    console.error('[challengeStore] acceptChallenge error:', error.message);
    throw error;
  }
}

/**
 * Refusar un repte i invalidar caches relacionats
 */
export async function refuseChallenge(challengeId: string, playerId?: string): Promise<void> {
  try {
    const { error } = await supabase
      .from('challenges')
      .update({ estat: 'refusat' })
      .eq('id', challengeId);

    if (error) {
      throw new Error(error.message);
    }

    // Invalidar caches i actualitzar dades
    invalidateChallengeCaches(playerId);
    await refreshActiveChallenges();
    
    if (playerId) {
      await refreshUserChallenges(playerId);
    }

  } catch (error: any) {
    console.error('[challengeStore] refuseChallenge error:', error.message);
    throw error;
  }
}