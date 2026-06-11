/**
 * Helpers d'escriptura per a la programació manual de partides del torneig
 * hàndicap. Extrets de /handicap/partides/+page.svelte per poder-los
 * reutilitzar des de la pàgina de gestió unificada de partides.
 *
 * Comportament idèntic al codi original; la pàgina continua gestionant
 * l'estat UI (flags de càrrega, toasts, recàrregues).
 */

import type { SupabaseClient } from '@supabase/supabase-js';

export interface HandicapScheduleSlot {
  data: string; // 'YYYY-MM-DD'
  hora: string; // 'HH:MM'
  taula: number;
}

export interface ScheduleHandicapMatchOpts {
  eventId: string;
  matchId: string;
  /** FK a calendari_partides existent (null si la partida no estava programada) */
  calendariPartidaId: string | null;
  /** numero_soci del jugador 1 (pot ser null si el rival no és determinat) */
  player1SociNumero: number | null;
  /** numero_soci del jugador 2 (pot ser null si el rival no és determinat) */
  player2SociNumero: number | null;
  /**
   * True quan tots dos jugadors estan determinats. Controla si
   * handicap_matches passa a 'programada' o roman a 'pendent'.
   */
  bothResolved: boolean;
  slot: HandicapScheduleSlot;
}

export interface UnscheduleHandicapMatchOpts {
  matchId: string;
  calendariPartidaId: string;
}

/**
 * Programa manualment una partida del torneig hàndicap.
 *
 * Flow:
 * 1. Si ja existia un registre a calendari_partides, l'esborra.
 * 2. Insereix el nou slot a calendari_partides (categoria_id = null).
 * 3. Actualitza handicap_matches amb el nou calendari_partida_id i estat.
 *
 * Pre-reserves (algun rival per determinar) conserven 'pendent' amb data
 * orientativa; només passen a 'programada' quan els dos jugadors estan
 * definits (bothResolved = true).
 *
 * @throws Error amb missatge en català si qualsevol operació falla.
 */
export async function scheduleHandicapMatch(
  supabase: SupabaseClient,
  opts: ScheduleHandicapMatchOpts
): Promise<void> {
  const { eventId, matchId, calendariPartidaId, player1SociNumero, player2SociNumero, bothResolved, slot } = opts;

  // 1. Esborrar el slot anterior si existia
  if (calendariPartidaId) {
    const { error: delErr } = await supabase
      .from('calendari_partides')
      .delete()
      .eq('id', calendariPartidaId);
    if (delErr) throw new Error(`Error esborrant slot anterior: ${delErr.message}`);
  }

  // 2. Inserir nova fila a calendari_partides
  const { data: newPartida, error: insertErr } = await supabase
    .from('calendari_partides')
    .insert({
      event_id: eventId,
      categoria_id: null,
      jugador1_soci_numero: player1SociNumero,
      jugador2_soci_numero: player2SociNumero,
      data_programada: `${slot.data}T${slot.hora}:00`,
      hora_inici: slot.hora,
      taula_assignada: slot.taula,
      estat: 'generat'
    })
    .select('id')
    .single();

  if (insertErr || !newPartida) {
    throw new Error(insertErr?.message ?? 'Error creant la partida al calendari');
  }

  // 3. Actualitzar handicap_matches
  const nouEstat = bothResolved ? 'programada' : 'pendent';
  const { error: updateErr } = await supabase
    .from('handicap_matches')
    .update({ calendari_partida_id: (newPartida as any).id, estat: nouEstat })
    .eq('id', matchId);

  if (updateErr) throw new Error(updateErr.message);
}

/**
 * Elimina la programació d'una partida hàndicap:
 * esborra la fila de calendari_partides i posa handicap_matches en 'pendent'.
 *
 * @throws Error amb missatge en català si qualsevol operació falla.
 */
export async function unscheduleHandicapMatch(
  supabase: SupabaseClient,
  opts: UnscheduleHandicapMatchOpts
): Promise<void> {
  const { matchId, calendariPartidaId } = opts;

  const { error: delErr } = await supabase
    .from('calendari_partides')
    .delete()
    .eq('id', calendariPartidaId);
  if (delErr) throw new Error(delErr.message);

  const { error: updateErr } = await supabase
    .from('handicap_matches')
    .update({ calendari_partida_id: null, estat: 'pendent' })
    .eq('id', matchId);
  if (updateErr) throw new Error(updateErr.message);
}
