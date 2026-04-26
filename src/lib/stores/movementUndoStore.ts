import { writable, derived, type Readable } from 'svelte/store';
import type { CategoryMovement } from '$lib/types';

/**
 * Store del darrer lot de moviments aplicat. Permet implementar un
 * "Desfer" temporal a la UI després d'un moviment intel·ligent en cascada.
 *
 * El lot expira automàticament passat `EXPIRATION_MS` (per defecte 5 min).
 */

export interface MovementBatch {
  movements: CategoryMovement[];
  appliedAt: number; // Date.now()
  /** Identificador opcional del context (event_id) per filtrar */
  eventId?: string;
}

const EXPIRATION_MS = 5 * 60 * 1000; // 5 minuts

const _store = writable<MovementBatch | null>(null);
let expirationTimer: ReturnType<typeof setTimeout> | null = null;

function clearTimer() {
  if (expirationTimer) {
    clearTimeout(expirationTimer);
    expirationTimer = null;
  }
}

/** Recorda un lot de moviments aplicats (en sobreescriu un d'anterior). */
export function rememberBatch(movements: CategoryMovement[], eventId?: string): void {
  if (movements.length === 0) {
    _store.set(null);
    return;
  }
  clearTimer();
  _store.set({
    movements,
    appliedAt: Date.now(),
    eventId
  });
  expirationTimer = setTimeout(() => {
    _store.set(null);
    expirationTimer = null;
  }, EXPIRATION_MS);
}

/** Esborra el lot recordat (per exemple, després d'un Desfer). */
export function clearBatch(): void {
  clearTimer();
  _store.set(null);
}

/** Lot actual (o null si ha expirat o no n'hi ha cap). */
export const lastMovementBatch: Readable<MovementBatch | null> = derived(_store, ($s) => $s);

/** Indica si hi ha un lot vigent que es pot desfer. */
export const canUndo: Readable<boolean> = derived(_store, ($s) => $s !== null && $s.movements.length > 0);
