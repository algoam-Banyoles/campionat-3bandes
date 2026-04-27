/**
 * Servei de mutacions admin del calendari de campionats socials.
 *
 * Encapsula totes les operacions Supabase d'escriptura que abans vivien
 * dins del component `SocialLeagueCalendarViewer.svelte`. Cada funció
 * llança si hi ha error; el component gestiona la UX (confirmacions,
 * toasts, recàrregues).
 */

import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Calcula els punts d'una partida a partir de les caramboles. Empats
 * donen 1 punt a cada jugador.
 */
export function calculateMatchPoints(
  caramboles_jugador1: number,
  caramboles_jugador2: number
): { punts_jugador1: number; punts_jugador2: number } {
  if (caramboles_jugador1 > caramboles_jugador2) {
    return { punts_jugador1: 2, punts_jugador2: 0 };
  }
  if (caramboles_jugador2 > caramboles_jugador1) {
    return { punts_jugador1: 0, punts_jugador2: 2 };
  }
  return { punts_jugador1: 1, punts_jugador2: 1 };
}

export interface MatchResultInput {
  caramboles_jugador1: number;
  caramboles_jugador2: number;
  entrades: number;
  observacions: string;
}

export interface MatchScores {
  caramboles_jugador1: number | null;
  caramboles_jugador2: number | null;
  entrades: number | null;
  observacions_junta: string | null;
}

/**
 * Llegeix les puntuacions actuals d'una partida (per a pre-omplir el
 * modal de resultats amb els valors guardats).
 */
export async function fetchMatchScores(
  supabase: SupabaseClient,
  matchId: string
): Promise<MatchScores> {
  const { data, error } = await supabase
    .from('calendari_partides')
    .select('caramboles_jugador1, caramboles_jugador2, entrades, observacions_junta')
    .eq('id', matchId)
    .single();

  if (error) throw error;
  return data as MatchScores;
}

/**
 * Guarda el resultat d'una partida: calcula els punts, marca com a
 * `jugada` i deixa rastre de qui ha validat (si l'usuari és autenticat).
 */
export async function saveMatchResult(
  supabase: SupabaseClient,
  matchId: string,
  input: MatchResultInput
): Promise<void> {
  const { punts_jugador1, punts_jugador2 } = calculateMatchPoints(
    input.caramboles_jugador1,
    input.caramboles_jugador2
  );

  const {
    data: { user }
  } = await supabase.auth.getUser();

  const now = new Date().toISOString();

  const { error } = await supabase
    .from('calendari_partides')
    .update({
      caramboles_jugador1: input.caramboles_jugador1,
      caramboles_jugador2: input.caramboles_jugador2,
      entrades: input.entrades,
      punts_jugador1,
      punts_jugador2,
      data_joc: now,
      estat: 'jugada',
      validat_per: user?.id,
      data_validacio: now,
      observacions_junta: input.observacions
    })
    .eq('id', matchId);

  if (error) throw error;
}

/**
 * Registra una incompareixença via RPC. El servidor decideix si el
 * jugador queda eliminat (segons el comptador d'incompareixences).
 */
export async function registerNoShow(
  supabase: SupabaseClient,
  matchId: string,
  absentPlayer: 1 | 2
): Promise<{ jugador_eliminat: boolean; incompareixences: number }> {
  const { data, error } = await supabase.rpc('registrar_incompareixenca', {
    p_partida_id: matchId,
    p_jugador_que_falta: absentPlayer
  });

  if (error) throw error;
  return data as { jugador_eliminat: boolean; incompareixences: number };
}

/**
 * Converteix una partida programada en pendent de programar: esborra
 * data, hora i billar i ho deixa anotat a les observacions.
 */
export async function markAsUnprogrammed(
  supabase: SupabaseClient,
  match: { id: string; observacions_junta?: string | null }
): Promise<void> {
  const noteDate = new Date().toLocaleDateString('ca-ES');
  const note = `[${noteDate}] Convertida a no programada per indisponibilitat de jugador.`;
  const newObservations = match.observacions_junta
    ? `${match.observacions_junta}\n${note}`
    : note;

  const { error } = await supabase
    .from('calendari_partides')
    .update({
      data_programada: null,
      hora_inici: null,
      taula_assignada: null,
      estat: 'pendent_programar',
      observacions_junta: newObservations
    })
    .eq('id', match.id);

  if (error) throw error;
}

export interface MatchEditInput {
  data_programada: string;
  hora_inici: string;
  taula_assignada: number | null;
  estat: string;
  observacions_junta: string;
}

/**
 * Guarda l'edició d'una partida fent abans una comprovació de conflicte
 * (mateix billar, mateixa data i hora). Si hi ha col·lisió llança error.
 */
export async function saveMatchEdit(
  supabase: SupabaseClient,
  matchId: string,
  input: MatchEditInput
): Promise<void> {
  const updates: Record<string, unknown> = {
    estat: input.estat,
    taula_assignada: input.taula_assignada,
    observacions_junta: input.observacions_junta || null
  };

  if (input.data_programada && input.hora_inici) {
    updates.data_programada = `${input.data_programada}T${input.hora_inici}:00`;
    updates.hora_inici = input.hora_inici;
  }

  // Comprovar conflicte de billar abans de desar
  if (updates.data_programada && updates.hora_inici && updates.taula_assignada) {
    const dia = (updates.data_programada as string).split('T')[0];
    const { data: conflict } = await supabase
      .from('calendari_partides')
      .select('id')
      .eq('hora_inici', updates.hora_inici)
      .eq('taula_assignada', updates.taula_assignada)
      .neq('id', matchId)
      .or('partida_anullada.is.null,partida_anullada.eq.false')
      .not(
        'estat',
        'in',
        '("jugada","cancel·lada_per_retirada","pendent_programar","postposada","reprogramada")'
      )
      .filter('data_programada::date', 'eq', dia)
      .maybeSingle();

    if (conflict) {
      throw new Error(
        `El billar ${updates.taula_assignada} ja té una partida programada el ${dia} a les ${updates.hora_inici}. Tria un altre billar o una altra hora.`
      );
    }
  }

  const { error } = await supabase
    .from('calendari_partides')
    .update(updates)
    .eq('id', matchId);

  if (error) {
    if (error.message?.includes('idx_unique_billar_slot')) {
      throw new Error(
        `El billar ${updates.taula_assignada} ja té una partida a aquesta hora. Tria un altre billar o una altra hora.`
      );
    }
    throw error;
  }
}

/**
 * Marca un esdeveniment com a calendari publicat. Els filtres sobre
 * partides validades es fan al component (per la confirmació visual).
 */
export async function markCalendarPublished(
  supabase: SupabaseClient,
  eventId: string
): Promise<void> {
  const { error } = await supabase
    .from('events')
    .update({ calendari_publicat: true })
    .eq('id', eventId);

  if (error) throw error;
}

/**
 * Intercanvia data, hora i billar entre dues partides. No fa
 * comprovació prèvia de conflicte: és l'admin qui decideix.
 */
export async function swapMatchSchedule(
  supabase: SupabaseClient,
  match1: {
    id: string;
    data_programada: string | null;
    hora_inici: string | null;
    taula_assignada: number | null;
  },
  match2: {
    id: string;
    data_programada: string | null;
    hora_inici: string | null;
    taula_assignada: number | null;
  }
): Promise<void> {
  const { error: e1 } = await supabase
    .from('calendari_partides')
    .update({
      data_programada: match2.data_programada,
      hora_inici: match2.hora_inici,
      taula_assignada: match2.taula_assignada
    })
    .eq('id', match1.id);
  if (e1) throw e1;

  const { error: e2 } = await supabase
    .from('calendari_partides')
    .update({
      data_programada: match1.data_programada,
      hora_inici: match1.hora_inici,
      taula_assignada: match1.taula_assignada
    })
    .eq('id', match2.id);
  if (e2) throw e2;
}
