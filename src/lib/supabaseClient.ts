// src/lib/supabaseClient.ts
import { createClient } from '@supabase/supabase-js';
import { wrapRpc } from './errors';

const url = import.meta.env.PUBLIC_SUPABASE_URL;
const anon = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

if (!url) throw new Error('PUBLIC_SUPABASE_URL no definit');
if (!anon) throw new Error('PUBLIC_SUPABASE_ANON_KEY no definit');

/**
 * Timeout per defecte aplicat a totes les peticions HTTP que fa el client de
 * Supabase. Evita que la PWA quedi penjada indefinidament en mòbil quan la
 * xarxa es degrada o la resposta no arriba mai.
 *
 * Es pot sobreescriure passant un `signal` propi a una crida concreta.
 */
export const SUPABASE_FETCH_TIMEOUT_MS = 15000;

/** Combina diversos AbortSignal en un de sol que s'avorta amb el primer. */
function anySignal(signals: AbortSignal[]): AbortSignal {
  const ctrl = new AbortController();
  for (const s of signals) {
    if (s.aborted) {
      ctrl.abort((s as any).reason);
      return ctrl.signal;
    }
    s.addEventListener(
      'abort',
      () => ctrl.abort((s as any).reason),
      { once: true }
    );
  }
  return ctrl.signal;
}

/**
 * Wrapper de `fetch` que afegeix un timeout via AbortController. Si el caller
 * ja proporciona un signal, ambdós es respecten (el primer que avorti guanya).
 */
function fetchWithTimeout(
  input: RequestInfo | URL,
  init: RequestInit = {}
): Promise<Response> {
  const timeoutCtrl = new AbortController();
  const timeoutId = setTimeout(
    () => timeoutCtrl.abort(new DOMException('Supabase request timeout', 'TimeoutError')),
    SUPABASE_FETCH_TIMEOUT_MS
  );

  const signal = init.signal
    ? anySignal([timeoutCtrl.signal, init.signal])
    : timeoutCtrl.signal;

  return fetch(input, { ...init, signal }).finally(() => clearTimeout(timeoutId));
}

export const supabase = wrapRpc(
  createClient(url, anon, {
    auth: {
      persistSession: true,
      autoRefreshToken: true
    },
    global: {
      fetch: fetchWithTimeout
    }
  })
);
