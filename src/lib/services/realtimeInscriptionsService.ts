/**
 * Subscripció en temps real a canvis d'inscripcions via Supabase Realtime.
 *
 * Pensat per a la pàgina d'admin/inscripcions-socials, on dos admins
 * poden editar concurrentment. Quan un mou un jugador de categoria,
 * l'altre veu el canvi sense recarregar.
 */

import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';

export type InscriptionChangeType =
  | 'created'
  | 'category_changed'
  | 'restrictions_changed'
  | 'withdrawn'
  | 'reinstated'
  | 'deleted'
  | 'other';

export interface InscriptionChangeEvent {
  type: InscriptionChangeType;
  inscriptionId: string;
  newRow: any | null;
  oldRow: any | null;
  isLocalEcho: boolean;
}

const LOCAL_ECHO_TTL_MS = 5000;
const recentlyMutatedLocally = new Map<string, number>();

/**
 * Marca una inscripció com a mutada localment durant 5s. Els canvis
 * realtime que l'afectin arribaran amb `isLocalEcho: true`.
 */
export function markInscriptionLocallyMutated(inscriptionId: string): void {
  recentlyMutatedLocally.set(inscriptionId, Date.now());
  for (const [id, ts] of recentlyMutatedLocally) {
    if (Date.now() - ts > LOCAL_ECHO_TTL_MS) {
      recentlyMutatedLocally.delete(id);
    }
  }
}

function isLocalEchoFor(inscriptionId: string): boolean {
  const ts = recentlyMutatedLocally.get(inscriptionId);
  if (ts == null) return false;
  if (Date.now() - ts > LOCAL_ECHO_TTL_MS) {
    recentlyMutatedLocally.delete(inscriptionId);
    return false;
  }
  return true;
}

function classifyUpdate(oldRow: any, newRow: any): InscriptionChangeType {
  if (!oldRow || !newRow) return 'other';

  if (oldRow.categoria_assignada_id !== newRow.categoria_assignada_id) {
    return 'category_changed';
  }
  if (oldRow.estat_jugador !== newRow.estat_jugador) {
    if (newRow.estat_jugador === 'retirat') return 'withdrawn';
    if (oldRow.estat_jugador === 'retirat') return 'reinstated';
  }
  if (
    JSON.stringify(oldRow.preferencies_dies) !== JSON.stringify(newRow.preferencies_dies) ||
    JSON.stringify(oldRow.preferencies_hores) !== JSON.stringify(newRow.preferencies_hores) ||
    oldRow.restriccions_especials !== newRow.restriccions_especials
  ) {
    return 'restrictions_changed';
  }
  return 'other';
}

/**
 * Subscriu a canvis d'inscripcions per a un esdeveniment. Captura
 * inserts, updates i deletes — el callback rep el tipus classificat.
 *
 * Retorna una funció `unsubscribe`.
 */
export function subscribeToInscriptionUpdates(
  supabase: SupabaseClient,
  eventId: string,
  onUpdate: (event: InscriptionChangeEvent) => void | Promise<void>
): () => void {
  if (!eventId) return () => {};

  const handle = (rawType: 'INSERT' | 'UPDATE' | 'DELETE', payload: any) => {
    const newRow = payload.new ?? null;
    const oldRow = payload.old ?? null;
    const inscriptionId = newRow?.id ?? oldRow?.id;
    if (!inscriptionId) return;

    let type: InscriptionChangeType;
    if (rawType === 'INSERT') type = 'created';
    else if (rawType === 'DELETE') type = 'deleted';
    else type = classifyUpdate(oldRow, newRow);

    const isLocalEcho = isLocalEchoFor(inscriptionId);
    try {
      const result = onUpdate({ type, inscriptionId, newRow, oldRow, isLocalEcho });
      if (result && typeof (result as Promise<void>).catch === 'function') {
        (result as Promise<void>).catch((err: unknown) =>
          console.error('Error in realtime inscriptions handler:', err)
        );
      }
    } catch (err) {
      console.error('Error in realtime inscriptions handler:', err);
    }
  };

  const channel: RealtimeChannel = supabase
    .channel(`event:${eventId}:inscriptions`)
    .on(
      'postgres_changes' as any,
      { event: 'INSERT', schema: 'public', table: 'inscripcions', filter: `event_id=eq.${eventId}` },
      (payload: any) => handle('INSERT', payload)
    )
    .on(
      'postgres_changes' as any,
      { event: 'UPDATE', schema: 'public', table: 'inscripcions', filter: `event_id=eq.${eventId}` },
      (payload: any) => handle('UPDATE', payload)
    )
    .on(
      'postgres_changes' as any,
      { event: 'DELETE', schema: 'public', table: 'inscripcions', filter: `event_id=eq.${eventId}` },
      (payload: any) => handle('DELETE', payload)
    )
    .subscribe();

  return () => {
    void supabase.removeChannel(channel);
  };
}
