// src/lib/stores/playerChallengeHistory.ts
import { supabase } from '$lib/supabaseClient';

export type ChallengeResult = 'W' | 'L'; // Win or Loss

export interface PlayerChallengeHistory {
  playerId: string;
  recentResults: ChallengeResult[];
}

export async function getPlayerChallengeHistory(playerId: string, eventId: string, limit = 6): Promise<ChallengeResult[]> {
  try {
    // Obtenir els últims reptes completats del jugador
    const { data: matches, error } = await supabase
      .from('matches')
      .select(`
        id,
        data_joc,
        resultat,
        challenge_id,
        challenges!inner (
          reptador_id,
          reptat_id,
          event_id
        )
      `)
      .eq('challenges.event_id', eventId)
      .or(`challenges.reptador_id.eq.${playerId},challenges.reptat_id.eq.${playerId}`)
      .order('data_joc', { ascending: false })
      .limit(limit);

    if (error) {
      console.error('Error fetching challenge history:', error);
      return [];
    }

    if (!matches || matches.length === 0) {
      return [];
    }

    // Convertir els resultats a W/L des de la perspectiva del jugador
    const results: ChallengeResult[] = matches.map(match => {
      const challenge = match.challenges as any;
      const isChallenger = challenge.reptador_id === playerId;
      const result = match.resultat;

      // Determinar si el jugador va guanyar
      let playerWon = false;
      
      if (isChallenger) {
        // El jugador era el reptador
        playerWon = result === 'guanya_reptador' || 
                   result === 'empat_tiebreak_reptador' || 
                   result === 'walkover_reptador';
      } else {
        // El jugador era el reptat
        playerWon = result === 'guanya_reptat' || 
                   result === 'empat_tiebreak_reptat' || 
                   result === 'walkover_reptat';
      }

      return playerWon ? 'W' : 'L';
    });

    return results;
  } catch (error) {
    console.error('Error in getPlayerChallengeHistory:', error);
    return [];
  }
}