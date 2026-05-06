/**
 * Subscripció en temps real a canvis d'`events` via Supabase Realtime.
 *
 * Pensat per a propagar canvis d'estat (planificacio → en_curs →
 * finalitzat), publicació de calendari, etc., entre clients.
 */

import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';

export type EventChangeType =
  | 'estat_changed'
  | 'calendari_published'
  | 'actiu_toggled'
  | 'other';

export interface EventChangeEvent {
  type: EventChangeType;
  eventId: string;
  newRow: any | null;
  oldRow: any | null;
  isLocalEcho: boolean;
}

const LOCAL_ECHO_TTL_MS = 5000;
const recentlyMutatedLocally = new Map<string, number>();

/** Marca un event com a mutat localment (TTL 5s). */
export function markEventLocallyMutated(eventId: string): void {
  recentlyMutatedLocally.set(eventId, Date.now());
  for (const [id, ts] of recentlyMutatedLocally) {
    if (Date.now() - ts > LOCAL_ECHO_TTL_MS) {
      recentlyMutatedLocally.delete(id);
    }
  }
}

function isLocalEchoFor(eventId: string): boolean {
  const ts = recentlyMutatedLocally.get(eventId);
  if (ts == null) return false;
  if (Date.now() - ts > LOCAL_ECHO_TTL_MS) {
    recentlyMutatedLocally.delete(eventId);
    return false;
  }
  return true;
}

function classifyUpdate(oldRow: any, newRow: any): EventChangeType {
  if (!oldRow || !newRow) return 'other';
  if (oldRow.estat_competicio !== newRow.estat_competicio) return 'estat_changed';
  if (oldRow.calendari_publicat !== newRow.calendari_publicat && newRow.calendari_publicat) {
    return 'calendari_published';
  }
  if (oldRow.actiu !== newRow.actiu) return 'actiu_toggled';
  return 'other';
}

/**
 * Subscriu a UPDATE d'un event concret. Si vols escoltar tots els
 * events, passa `'*'` com a id (no filtra). Retorna `unsubscribe`.
 */
export function subscribeToEventUpdates(
  supabase: SupabaseClient,
  eventId: string,
  onUpdate: (event: EventChangeEvent) => void | Promise<void>
): () => void {
  if (!eventId) return () => {};

  const channel: RealtimeChannel = supabase
    .channel(`event:${eventId}:meta`)
    .on(
      'postgres_changes' as any,
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'events',
        filter: eventId === '*' ? undefined : `id=eq.${eventId}`
      },
      (payload: any) => {
        const newRow = payload.new ?? null;
        const oldRow = payload.old ?? null;
        const id = newRow?.id ?? oldRow?.id;
        if (!id) return;

        const type = classifyUpdate(oldRow, newRow);
        const isLocalEcho = isLocalEchoFor(id);
        try {
          const result = onUpdate({ type, eventId: id, newRow, oldRow, isLocalEcho });
          if (result && typeof (result as Promise<void>).catch === 'function') {
            (result as Promise<void>).catch((err: unknown) =>
              console.error('Error in realtime events handler:', err)
            );
          }
        } catch (err) {
          console.error('Error in realtime events handler:', err);
        }
      }
    )
    .subscribe();

  return () => {
    void supabase.removeChannel(channel);
  };
}
