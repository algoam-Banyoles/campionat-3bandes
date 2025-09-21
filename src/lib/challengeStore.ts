// src/lib/challengeStore.ts
import { writable, get } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { cacheManager } from '$lib/cache/strategies';
import { connectionManager, isConnected } from '$lib/connection/connectionManager';
import { queueOperation } from '$lib/connection/offlineQueue';
import { offlineStorage, getAllOffline, storeOffline, queryOffline } from '$lib/connection/offlineStorage';
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
 * Actualitzar reptes actius amb cache i suport offline
 */
export async function refreshActiveChallenges(): Promise<void> {
  const connected = get(isConnected);
  
  // Mode offline - carregar des del storage local
  if (!connected) {
    try {
      console.log('[challengeStore] Offline mode - loading challenges from local storage');
      
      const offlineChallenges = await getAllOffline('reptes', (challenge) => 
        ['pendent', 'acceptat', 'programat'].includes(challenge.estat)
      );
      
      const offlinePlayers = await getAllOffline('socis');
      const playerMap = new Map<string, string>();
      offlinePlayers.forEach(player => {
        playerMap.set(player.id.toString(), `${player.nom} ${player.cognom}`);
      });

      const processedData: ChallengeWithPlayers[] = offlineChallenges.map(challenge => ({
        id: challenge.id.toString(),
        event_id: '', // Would need to be stored
        tipus: 'normal' as const,
        reptador_id: challenge.soci_retador_id.toString(),
        reptat_id: challenge.soci_retat_id.toString(),
        estat: challenge.estat as any,
        dates_proposades: [], // Would need to be stored
        data_proposta: challenge.data_creacio,
        data_acceptacio: challenge.data_acceptacio,
        data_programada: null,
        reprogram_count: 0,
        pos_reptador: null,
        pos_reptat: null,
        reptador_nom: playerMap.get(challenge.soci_retador_id.toString()) || 'Desconegut',
        reptat_nom: playerMap.get(challenge.soci_retat_id.toString()) || 'Desconegut'
      }));

      activeChallenges.set(processedData);
      return;
      
    } catch (error) {
      console.warn('[challengeStore] Error loading offline challenges:', error);
      activeChallenges.set([]);
      return;
    }
  }

  // Mode online amb connexió
  try {
    const data = await performanceMonitor.measure(
      'active_challenges_query',
      'database',
      async () => {
        return await connectionManager.executeWithRetry(
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

                // Guardar en storage offline per ús futur
                if (processedData.length > 0) {
                  const offlineFormat = processedData.map(challenge => ({
                    id: parseInt(challenge.id),
                    soci_retador_id: parseInt(challenge.reptador_id),
                    soci_retat_id: parseInt(challenge.reptat_id),
                    estat: challenge.estat as any,
                    data_creacio: challenge.data_proposta,
                    data_acceptacio: challenge.data_acceptacio,
                    data_limit: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 days
                    updated_at: new Date().toISOString()
                  }));
                  
                  await storeOffline('reptes', offlineFormat);
                }

                return processedData as ChallengeWithPlayers[];
              }
            );
          },
          'standard'
        );
      }
    );

    activeChallenges.set(data);

  } catch (error: any) {
    console.warn('[challengeStore] refreshActiveChallenges error:', error.message);
    
    // Fallback: intentar carregar des del storage offline
    try {
      const offlineChallenges = await getAllOffline('reptes');
      if (offlineChallenges.length > 0) {
        console.log('[challengeStore] Using offline data as fallback');
        // Convert offline format to expected format (simplified)
        const fallbackData: ChallengeWithPlayers[] = offlineChallenges.map(challenge => ({
          id: challenge.id.toString(),
          event_id: '',
          tipus: 'normal' as const,
          reptador_id: challenge.soci_retador_id.toString(),
          reptat_id: challenge.soci_retat_id.toString(),
          estat: challenge.estat as any,
          dates_proposades: [],
          data_proposta: challenge.data_creacio,
          data_acceptacio: challenge.data_acceptacio,
          data_programada: null,
          reprogram_count: 0,
          pos_reptador: null,
          pos_reptat: null,
          reptador_nom: 'Desconegut',
          reptat_nom: 'Desconegut'
        }));
        activeChallenges.set(fallbackData);
      } else {
        activeChallenges.set([]);
      }
    } catch (fallbackError) {
      console.warn('[challengeStore] Error loading offline fallback:', fallbackError);
      activeChallenges.set([]);
    }
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
 * Acceptar un repte amb suport offline
 */
export async function acceptChallenge(challengeId: string, playerId?: string): Promise<void> {
  const connected = get(isConnected);
  
  const updateData = { 
    estat: 'acceptat', 
    data_acceptacio: new Date().toISOString() 
  };

  if (!connected) {
    // Mode offline - afegir a la cua d'operacions
    console.log('[challengeStore] Offline mode - queueing challenge acceptance');
    
    await queueOperation(
      'challenge_accept',
      async () => {
        const { error } = await supabase
          .from('challenges')
          .update(updateData)
          .eq('id', challengeId);

        if (error) {
          throw new Error(error.message);
        }
      },
      { challengeId, updateData },
      { 
        priority: 'critical',
        userId: playerId,
        maxRetries: 5
      }
    );

    // Actualitzar localment si és possible
    try {
      const localChallenge = await offlineStorage.get('reptes', parseInt(challengeId));
      if (localChallenge) {
        const updatedChallenge = {
          ...localChallenge,
          estat: 'acceptat' as any,
          data_acceptacio: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        await storeOffline('reptes', updatedChallenge);
      }
    } catch (error) {
      console.warn('[challengeStore] Error updating local challenge:', error);
    }

    return;
  }

  // Mode online amb retry
  try {
    await connectionManager.executeWithRetry(
      async () => {
        const { error } = await supabase
          .from('challenges')
          .update(updateData)
          .eq('id', challengeId);

        if (error) {
          throw new Error(error.message);
        }
      },
      'critical'
    );

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
 * Refusar un repte amb suport offline
 */
export async function refuseChallenge(challengeId: string, playerId?: string): Promise<void> {
  const connected = get(isConnected);
  
  const updateData = { estat: 'refusat' };

  if (!connected) {
    // Mode offline - afegir a la cua d'operacions
    console.log('[challengeStore] Offline mode - queueing challenge refusal');
    
    await queueOperation(
      'challenge_refuse',
      async () => {
        const { error } = await supabase
          .from('challenges')
          .update(updateData)
          .eq('id', challengeId);

        if (error) {
          throw new Error(error.message);
        }
      },
      { challengeId, updateData },
      { 
        priority: 'high',
        userId: playerId,
        maxRetries: 3
      }
    );

    // Actualitzar localment si és possible
    try {
      const localChallenge = await offlineStorage.get('reptes', parseInt(challengeId));
      if (localChallenge) {
        const updatedChallenge = {
          ...localChallenge,
          estat: 'refusat' as any,
          updated_at: new Date().toISOString()
        };
        await storeOffline('reptes', updatedChallenge);
      }
    } catch (error) {
      console.warn('[challengeStore] Error updating local challenge:', error);
    }

    return;
  }

  // Mode online amb retry
  try {
    await connectionManager.executeWithRetry(
      async () => {
        const { error } = await supabase
          .from('challenges')
          .update(updateData)
          .eq('id', challengeId);

        if (error) {
          throw new Error(error.message);
        }
      },
      'standard'
    );

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