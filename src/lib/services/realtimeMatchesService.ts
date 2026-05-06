/**
 * Subscripció en temps real a canvis de partides via Supabase Realtime.
 *
 * Permet a components com classificacions o calendari reaccionar
 * automàticament quan un altre client introdueix un resultat o
 * reprograma una partida — sense necessitat de polling.
 */

import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';

/** Tipus d'esdeveniment classificat segons el canvi detectat. */
export type MatchUpdateType =
  | 'result_recorded' // s'han introduit caramboles per primera vegada
  | 'result_modified' // hi havia caramboles i s'han canviat
  | 'rescheduled' // canvi de data/hora/billar
  | 'cancelled' // ha quedat anul·lada
  | 'other';

export interface MatchUpdateEvent {
  type: MatchUpdateType;
  matchId: string;
  newRow: any;
  oldRow: any;
  /**
   * `true` si aquest canvi sembla que ve de l'usuari local (ha estat
   * marcat amb `markLocallyMutated()` recentment). Permet als
   * components evitar mostrar toasts redundants ("nou resultat") quan
   * el mateix usuari acaba d'introduir-lo.
   */
  isLocalEcho: boolean;
}

/**
 * Conjunt de match IDs que l'usuari local ha mutat recentment.
 * S'expira automàticament després de `LOCAL_ECHO_TTL_MS`.
 */
const LOCAL_ECHO_TTL_MS = 5000;
const recentlyMutatedLocally = new Map<string, number>();

/**
 * Marca un match com a mutat localment. Durant els pròxims
 * `LOCAL_ECHO_TTL_MS` ms, els esdeveniments realtime que l'afectin
 * arribaran amb `isLocalEcho: true` perquè els consumidors puguin
 * suprimir-ne el toast.
 */
export function markLocallyMutated(matchId: string): void {
  recentlyMutatedLocally.set(matchId, Date.now());
  // Neteja preventiva d'entrades velles per evitar creixement il·limitat
  for (const [id, ts] of recentlyMutatedLocally) {
    if (Date.now() - ts > LOCAL_ECHO_TTL_MS) {
      recentlyMutatedLocally.delete(id);
    }
  }
}

function isLocalEchoFor(matchId: string): boolean {
  const ts = recentlyMutatedLocally.get(matchId);
  if (ts == null) return false;
  if (Date.now() - ts > LOCAL_ECHO_TTL_MS) {
    recentlyMutatedLocally.delete(matchId);
    return false;
  }
  return true;
}

/**
 * Classifica què ha canviat entre `oldRow` i `newRow` per generar el
 * tipus d'esdeveniment més útil per a la UI.
 */
function classifyChange(oldRow: any, newRow: any): MatchUpdateType {
  if (!oldRow || !newRow) return 'other';

  const hadResult = oldRow.caramboles_jugador1 != null && oldRow.caramboles_jugador2 != null;
  const hasResult = newRow.caramboles_jugador1 != null && newRow.caramboles_jugador2 != null;
  if (!hadResult && hasResult) return 'result_recorded';
  if (hadResult && hasResult) {
    if (
      oldRow.caramboles_jugador1 !== newRow.caramboles_jugador1 ||
      oldRow.caramboles_jugador2 !== newRow.caramboles_jugador2
    ) {
      return 'result_modified';
    }
  }

  if (newRow.partida_anullada === true && oldRow.partida_anullada !== true) return 'cancelled';
  if (newRow.estat === 'cancel·lada_per_retirada' && oldRow.estat !== 'cancel·lada_per_retirada') {
    return 'cancelled';
  }

  if (
    oldRow.data_programada !== newRow.data_programada ||
    oldRow.hora_inici !== newRow.hora_inici ||
    oldRow.taula_assignada !== newRow.taula_assignada
  ) {
    return 'rescheduled';
  }

  return 'other';
}

/**
 * Subscriu a canvis de la taula `calendari_partides` per a l'esdeveniment
 * indicat. Retorna una funció `unsubscribe` que cal cridar al destruir
 * el component.
 *
 * @param onUpdate Callback amb l'esdeveniment classificat. Pot ser async
 *                 (la promesa s'ignora — gestiona els errors internament).
 */
export function subscribeToMatchUpdates(
  supabase: SupabaseClient,
  eventId: string,
  onUpdate: (event: MatchUpdateEvent) => void | Promise<void>
): () => void {
  if (!eventId) {
    return () => {};
  }

  const channel: RealtimeChannel = supabase
    .channel(`event:${eventId}:matches`)
    .on(
      'postgres_changes' as any,
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'calendari_partides',
        filter: `event_id=eq.${eventId}`
      },
      (payload: any) => {
        const newRow = payload.new;
        const oldRow = payload.old;
        const matchId = newRow?.id ?? oldRow?.id;
        if (!matchId) return;

        const type = classifyChange(oldRow, newRow);
        const isLocalEcho = isLocalEchoFor(matchId);
        try {
          const result = onUpdate({ type, matchId, newRow, oldRow, isLocalEcho });
          if (result && typeof (result as Promise<void>).catch === 'function') {
            (result as Promise<void>).catch((err: unknown) =>
              console.error('Error in realtime onUpdate handler:', err)
            );
          }
        } catch (err) {
          console.error('Error in realtime onUpdate handler:', err);
        }
      }
    )
    .subscribe();

  return () => {
    void supabase.removeChannel(channel);
  };
}
