// src/lib/stores/playerChallengeHistory.ts
import { supabase } from '$lib/supabaseClient';

export type ChallengeResult = 'W' | 'L'; // Win or Loss

export interface PlayerChallengeHistory {
  sociNumero: number;
  recentResults: ChallengeResult[];
}

/**
 * Versió batch: fetcha totes les últimes partides d'una sèrie de socis en una
 * sola query i agrupa client-side. Pensat per evitar N queries (una per soci)
 * al ranking del campionat continu.
 *
 * @param sociNumeros Llista de socis a consultar
 * @param eventId Event actiu
 * @param limit Nombre màxim de resultats per soci (default 6)
 * @returns Map de soci_numero → array de 'W'/'L' (més recents primer)
 */
export async function getPlayerChallengeHistoriesBatch(
  sociNumeros: number[],
  eventId: string,
  limit = 6
): Promise<Map<number, ChallengeResult[]>> {
  const result = new Map<number, ChallengeResult[]>();
  if (sociNumeros.length === 0) return result;

  try {
    // Fetcha les partides on alguna soci de la llista hi participa, ordenades per data desc.
    // Volem els últims `limit` per soci, però com que un mateix match pot involucrar dos
    // socis de la llista, agafem un buffer raonable (limit * sociNumeros.length).
    const { data: matches, error } = await supabase
      .from('matches')
      .select(`
        id,
        data_joc,
        resultat,
        challenge_id,
        challenges!inner (
          reptador_soci_numero,
          reptat_soci_numero,
          event_id
        )
      `)
      .eq('challenges.event_id', eventId)
      .or(
        sociNumeros
          .flatMap((s) => [`reptador_soci_numero.eq.${s}`, `reptat_soci_numero.eq.${s}`])
          .join(','),
        { referencedTable: 'challenges' }
      )
      .order('data_joc', { ascending: false })
      .limit(limit * sociNumeros.length * 2);

    if (error) {
      console.error('Error fetching challenge histories batch:', error);
      return result;
    }
    if (!matches) return result;

    const sociSet = new Set(sociNumeros);

    for (const match of matches) {
      const challenge = match.challenges as any;
      const reptador = challenge.reptador_soci_numero;
      const reptat = challenge.reptat_soci_numero;
      const matchResult = match.resultat;

      for (const soci of [reptador, reptat]) {
        if (!sociSet.has(soci)) continue;
        const arr = result.get(soci) ?? [];
        if (arr.length >= limit) continue;

        const isChallenger = reptador === soci;
        let won = false;
        if (isChallenger) {
          won =
            matchResult === 'guanya_reptador' ||
            matchResult === 'empat_tiebreak_reptador' ||
            matchResult === 'walkover_reptador';
        } else {
          won =
            matchResult === 'guanya_reptat' ||
            matchResult === 'empat_tiebreak_reptat' ||
            matchResult === 'walkover_reptat';
        }
        arr.push(won ? 'W' : 'L');
        result.set(soci, arr);
      }
    }

    return result;
  } catch (error) {
    console.error('Error in getPlayerChallengeHistoriesBatch:', error);
    return result;
  }
}

export async function getPlayerChallengeHistory(sociNumero: number, eventId: string, limit = 6): Promise<ChallengeResult[]> {
  try {
    // Obtenir els últims reptes completats del jugador via soci_numero
    const { data: matches, error } = await supabase
      .from('matches')
      .select(`
        id,
        data_joc,
        resultat,
        challenge_id,
        challenges!inner (
          reptador_soci_numero,
          reptat_soci_numero,
          event_id
        )
      `)
      .eq('challenges.event_id', eventId)
      .or(
        `reptador_soci_numero.eq.${sociNumero},reptat_soci_numero.eq.${sociNumero}`,
        { referencedTable: 'challenges' }
      )
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
      const isChallenger = challenge.reptador_soci_numero === sociNumero;
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
