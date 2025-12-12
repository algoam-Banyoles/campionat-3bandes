/**
 * Funcions per generar classificacions finals dels campionats
 */

import { supabase } from '$lib/supabaseClient';

export interface GenerateClassificationsResult {
  success: boolean;
  message: string;
  classifications_count: number;
}

/**
 * Genera i guarda les classificacions finals d'un campionat
 * Utilitza la funció RPC get_social_league_classifications per calcular
 * les classificacions i les guarda a la taula classificacions
 */
export async function generateFinalClassifications(
  eventId: string
): Promise<GenerateClassificationsResult> {
  try {
    const { data, error } = await supabase
      .rpc('generate_final_classifications', {
        p_event_id: eventId
      });

    if (error) {
      console.error('Error generating classifications:', error);
      throw error;
    }

    if (!data || data.length === 0) {
      throw new Error('No s\'ha rebut resposta de la funció');
    }

    const result = data[0];
    
    if (!result.success) {
      throw new Error(result.message);
    }

    return result;
  } catch (error) {
    console.error('Error in generateFinalClassifications:', error);
    throw error;
  }
}

/**
 * Comprova si un campionat té classificacions generades
 */
export async function hasGeneratedClassifications(eventId: string): Promise<boolean> {
  try {
    const { data, error, count } = await supabase
      .from('classificacions')
      .select('id', { count: 'exact', head: true })
      .eq('event_id', eventId);

    if (error) {
      console.error('Error checking classifications:', error);
      return false;
    }

    return (count || 0) > 0;
  } catch (error) {
    console.error('Error in hasGeneratedClassifications:', error);
    return false;
  }
}

/**
 * Obté estadístiques d'un campionat per decidir si es poden generar classificacions
 */
export async function getEventStatistics(eventId: string) {
  try {
    // Obtenir partides
    const { data: matches, error: matchesError } = await supabase
      .from('calendari_partides')
      .select('id, estat')
      .eq('event_id', eventId);

    if (matchesError) throw matchesError;

    const totalMatches = matches?.length || 0;
    const validatedMatches = matches?.filter(m => m.estat === 'validat').length || 0;
    const cancelledMatches = matches?.filter(m => m.estat === 'cancel·lada_per_retirada').length || 0;

    // Obtenir inscripcions
    const { count: inscriptionsCount, error: inscriptionsError } = await supabase
      .from('inscripcions')
      .select('id', { count: 'exact', head: true })
      .eq('event_id', eventId)
      .eq('confirmat', true);

    if (inscriptionsError) throw inscriptionsError;

    // Comprovar si ja hi ha classificacions
    const hasClassifications = await hasGeneratedClassifications(eventId);

    return {
      totalMatches,
      validatedMatches,
      cancelledMatches,
      confirmedInscriptions: inscriptionsCount || 0,
      hasClassifications,
      canGenerateClassifications: validatedMatches > 0
    };
  } catch (error) {
    console.error('Error getting event statistics:', error);
    throw error;
  }
}
