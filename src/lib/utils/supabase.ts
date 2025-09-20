// src/lib/utils/supabase.ts
import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Utilitat per importar el client de Supabase de forma dinàmica
 * Això ajuda a optimitzar el bundle i evita problemes de SSR
 */
export async function getSupabaseClient(): Promise<SupabaseClient> {
  const { supabase } = await import('$lib/supabaseClient');
  return supabase;
}

/**
 * Wrapper per a operacions comunes de Supabase amb gestió d'errors
 */
export async function withSupabase<T>(
  operation: (supabase: SupabaseClient) => Promise<T>
): Promise<T> {
  const supabase = await getSupabaseClient();
  return operation(supabase);
}