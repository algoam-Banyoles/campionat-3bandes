// src/lib/utils/supabase.ts
import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Error tipat que es llança quan una operació amb Supabase supera el timeout.
 * Permet diferenciar timeouts d'altres errors aigües amunt sense haver
 * d'inspeccionar missatges.
 */
export class SupabaseTimeoutError extends Error {
  readonly code = 'SUPABASE_TIMEOUT';
  constructor(public readonly timeoutMs: number) {
    super(`Operació Supabase avortada per timeout (${timeoutMs} ms)`);
    this.name = 'SupabaseTimeoutError';
  }
}

/** Timeout per defecte de `withSupabase` (ms). */
export const DEFAULT_OPERATION_TIMEOUT_MS = 15000;

/**
 * Importa el client de Supabase de forma dinàmica per optimitzar el bundle
 * i evitar problemes de SSR.
 */
export async function getSupabaseClient(): Promise<SupabaseClient> {
  const { supabase } = await import('$lib/supabaseClient');
  return supabase;
}

export interface WithSupabaseOptions {
  /** Timeout en ms abans de llançar `SupabaseTimeoutError`. */
  timeoutMs?: number;
}

/**
 * Wrapper per a operacions Supabase amb timeout dur. Si l'operació no resol
 * dins el termini llança `SupabaseTimeoutError` en lloc de penjar-se.
 *
 * Nota: el timeout només controla la promesa retornada — la petició HTTP de
 * Supabase ja té el seu propi timeout via `fetchWithTimeout` a `supabaseClient.ts`.
 * Aquesta capa addicional cobreix lògica encadenada (múltiples queries dins
 * la lambda) i operacions que no són HTTP.
 */
export async function withSupabase<T>(
  operation: (supabase: SupabaseClient) => Promise<T>,
  options: WithSupabaseOptions = {}
): Promise<T> {
  const timeoutMs = options.timeoutMs ?? DEFAULT_OPERATION_TIMEOUT_MS;
  const supabase = await getSupabaseClient();

  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(
      () => reject(new SupabaseTimeoutError(timeoutMs)),
      timeoutMs
    );
  });

  try {
    return await Promise.race([operation(supabase), timeoutPromise]);
  } finally {
    if (timeoutId !== undefined) clearTimeout(timeoutId);
  }
}
