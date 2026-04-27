import { writable, type Readable } from 'svelte/store';

/**
 * Servei imperatiu de confirmació amb modal personalitzat.
 *
 * Pensat com a substitut net del `window.confirm()` natiu, però amb
 * estil consistent, suport a marcadors de severitat (perill / atenció)
 * i botons amb text personalitzable.
 *
 * Ús:
 * ```
 * if (!await showConfirm({ message: 'Estàs segur?' })) return;
 * ```
 */

export type ConfirmSeverity = 'info' | 'warning' | 'danger';

export interface ConfirmOptions {
  title?: string;
  message: string;
  /** Text del botó d'acció primària. Per defecte: "Confirmar". */
  confirmLabel?: string;
  /** Text del botó d'acció secundària. Per defecte: "Cancel·lar". */
  cancelLabel?: string;
  /** Codi de color del botó primari. Per defecte: 'warning'. */
  severity?: ConfirmSeverity;
}

interface ConfirmState extends ConfirmOptions {
  open: boolean;
  resolve: ((value: boolean) => void) | null;
}

const initialState: ConfirmState = {
  open: false,
  message: '',
  resolve: null
};

const _store = writable<ConfirmState>(initialState);

/** Estat actual del diàleg (per al component que el renderitza). */
export const confirmDialogState: Readable<ConfirmState> = { subscribe: _store.subscribe };

/**
 * Mostra un confirm modal i retorna una promesa que resol amb true
 * (confirmar) o false (cancel·lar / tancar). Si ja n'hi ha un d'obert,
 * el reemplaça (cancel·lant la promesa anterior amb false).
 */
export function showConfirm(options: ConfirmOptions): Promise<boolean> {
  return new Promise<boolean>(resolve => {
    _store.update(prev => {
      if (prev.open && prev.resolve) {
        prev.resolve(false);
      }
      return {
        open: true,
        message: options.message,
        title: options.title,
        confirmLabel: options.confirmLabel,
        cancelLabel: options.cancelLabel,
        severity: options.severity ?? 'warning',
        resolve
      };
    });
  });
}

/** Resol el diàleg amb la decisió de l'usuari (true = confirmar). */
export function resolveConfirm(value: boolean): void {
  _store.update(prev => {
    if (prev.resolve) prev.resolve(value);
    return { ...initialState };
  });
}
