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
  reptador_soci_numero: number;
  reptat_soci_numero: number;
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
        const fullName = player.cognom ? `${player.nom} ${player.cognom}` : player.nom;
        playerMap.set(player.id.toString(), fullName);
      });

      const processedData: ChallengeWithPlayers[] = offlineChallenges.map(challenge => ({
        id: challenge.id.toString(),
        event_id: '',
        tipus: 'normal' as const,
        reptador_soci_numero: challenge.soci_retador_id,
        reptat_soci_numero: challenge.soci_retat_id,
        estat: challenge.estat as any,
        dates_proposades: [],
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
                    reptador_soci_numero,
                    reptat_soci_numero,
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
                  // Si és un error d'autenticació, gestionar-lo de forma especial
                  if (error.code === 'PGRST301' || error.message?.includes('JWT')) {
                    console.warn('[challengeStore] Auth error - user might need to login');
                    throw new Error('AUTHENTICATION_REQUIRED');
                  }
                  
                  console.warn('[challengeStore] refreshActiveChallenges error:', error.message);
                  throw new Error(error.message);
                }

                if (!challenges || challenges.length === 0) {
                  return [] as ChallengeWithPlayers[];
                }

                // Obtenir noms dels jugadors per soci_numero
                const sociNums = Array.from(new Set([
                  ...challenges.map(c => c.reptador_soci_numero),
                  ...challenges.map(c => c.reptat_soci_numero)
                ].filter((n): n is number => n != null)));

                const { data: socisData, error: socisError } = await supabase
                  .from('socis')
                  .select('numero_soci, nom, cognoms')
                  .in('numero_soci', sociNums);

                if (socisError) {
                  console.warn('[challengeStore] socis query error:', socisError.message);
                }

                // Crear un mapa de jugadors per soci_numero
                const sociMap = new Map<number, string>();
                (socisData || []).forEach(soci => {
                  const fullName = soci.cognoms ? `${soci.nom} ${soci.cognoms}` : soci.nom;
                  sociMap.set(soci.numero_soci, fullName);
                });

                // Processar dades per afegir noms dels jugadors
                const processedData = challenges.map(challenge => ({
                  ...challenge,
                  reptador_nom: sociMap.get(challenge.reptador_soci_numero) || 'Desconegut',
                  reptat_nom: sociMap.get(challenge.reptat_soci_numero) || 'Desconegut'
                }));

                // Guardar en storage offline per ús futur
                if (processedData.length > 0) {
                  const offlineFormat = processedData.map(challenge => ({
                    id: parseInt(challenge.id),
                    soci_retador_id: challenge.reptador_soci_numero,
                    soci_retat_id: challenge.reptat_soci_numero,
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
          reptador_soci_numero: challenge.soci_retador_id,
          reptat_soci_numero: challenge.soci_retat_id,
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
export async function refreshUserChallenges(sociNumero: number): Promise<void> {
  try {
    const data = await performanceMonitor.measure(
      'user_challenges_query',
      'database',
      async () => {
        return await cacheManager.get(
          'userChallenges',
          async () => {
            // Primer obtenir els challenges de l'usuari per soci_numero
            const { data: challenges, error } = await supabase
              .from('challenges')
              .select(`
                id,
                event_id,
                tipus,
                reptador_soci_numero,
                reptat_soci_numero,
                estat,
                dates_proposades,
                data_proposta,
                data_acceptacio,
                data_programada,
                reprogram_count,
                pos_reptador,
                pos_reptat
              `)
              .or(`reptador_soci_numero.eq.${sociNumero},reptat_soci_numero.eq.${sociNumero}`)
              .order('data_proposta', { ascending: false })
              .limit(50); // Limitar per rendiment

            if (error) {
              // Si és un error d'autenticació, gestionar-lo de forma especial
              if (error.code === 'PGRST301' || error.message?.includes('JWT')) {
                console.warn('[challengeStore] Auth error in refreshUserChallenges - user might need to login');
                throw new Error('AUTHENTICATION_REQUIRED');
              }

              console.warn('[challengeStore] refreshUserChallenges error:', error.message);
              throw new Error(error.message);
            }

            if (!challenges || challenges.length === 0) {
              return [] as ChallengeWithPlayers[];
            }

            // Obtenir noms dels jugadors per soci_numero
            const sociNums = Array.from(new Set([
              ...challenges.map(c => c.reptador_soci_numero),
              ...challenges.map(c => c.reptat_soci_numero)
            ].filter((n): n is number => n != null)));

            const { data: socisData, error: socisError } = await supabase
              .from('socis')
              .select('numero_soci, nom')
              .in('numero_soci', sociNums);

            if (socisError) {
              console.warn('[challengeStore] socis query error:', socisError.message);
            }

            // Crear un mapa de jugadors per soci_numero
            const sociMap = new Map<number, string>();
            (socisData || []).forEach(soci => {
              sociMap.set(soci.numero_soci, soci.nom);
            });

            // Processar dades per afegir noms dels jugadors
            const processedData = challenges.map(challenge => ({
              ...challenge,
              reptador_nom: sociMap.get(challenge.reptador_soci_numero) || 'Desconegut',
              reptat_nom: sociMap.get(challenge.reptat_soci_numero) || 'Desconegut'
            }));

            return processedData as ChallengeWithPlayers[];
          },
          `user_${sociNumero}` // Usar modificador de clau per cache per usuari
        );
      },
      { sociNumero }
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
export function invalidateChallengeCaches(sociNumero?: number): void {
  cacheManager.invalidate('activeChallenges');

  if (sociNumero) {
    cacheManager.invalidate('userChallenges', `user_${sociNumero}`);
  }
  
  // També invalidar rankings ja que poden haver canviat
  cacheManager.invalidate('ranking');
}

/**
 * Acceptar un repte amb suport offline
 */
export async function acceptChallenge(challengeId: string, sociNumero?: number): Promise<void> {
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
        userId: sociNumero != null ? String(sociNumero) : undefined,
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
          if (error.code === 'PGRST301' || error.message?.includes('JWT')) {
            throw new Error('AUTHENTICATION_REQUIRED');
          }
          throw new Error(error.message);
        }
      },
      'critical'
    );

    // Invalidar caches i actualitzar dades
    invalidateChallengeCaches(sociNumero);
    await refreshActiveChallenges();

    if (sociNumero) {
      await refreshUserChallenges(sociNumero);
    }

  } catch (error: any) {
    console.error('[challengeStore] acceptChallenge error:', error.message);
    throw error;
  }
}

/**
 * Refusar un repte amb suport offline
 */
export async function refuseChallenge(challengeId: string, sociNumero?: number): Promise<void> {
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
        userId: sociNumero != null ? String(sociNumero) : undefined,
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
          if (error.code === 'PGRST301' || error.message?.includes('JWT')) {
            throw new Error('AUTHENTICATION_REQUIRED');
          }
          throw new Error(error.message);
        }
      },
      'standard'
    );

    // Invalidar caches i actualitzar dades
    invalidateChallengeCaches(sociNumero);
    await refreshActiveChallenges();

    if (sociNumero) {
      await refreshUserChallenges(sociNumero);
    }

  } catch (error: any) {
    console.error('[challengeStore] refuseChallenge error:', error.message);
    throw error;
  }
}