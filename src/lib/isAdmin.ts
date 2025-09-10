// src/lib/isAdmin.ts
import { supabase } from '$lib/supabaseClient';

/**
 * Retorna true si l'usuari logat és admin (correu present a public.admins).
 * Requereix la policy RLS:
 *   using ( lower(email) = lower(auth.jwt()->>'email') )
 */
export async function isAdmin(): Promise<boolean> {
  try {
    // 1) Obtenim la sessió actual
    const { data: sessionData, error: sessErr } = await supabase.auth.getSession();
    if (sessErr) {
      console.warn('[isAdmin] getSession error:', sessErr.message);
      return false;
    }
    const email = sessionData?.session?.user?.email ?? null;
    if (!email) return false;

    // 2) Consultem la PRÒPIA fila a public.admins (RLS comprovarà el JWT)
    const { data, error } = await supabase
      .from('admins')
      .select('email')
      .eq('email', email)
      .maybeSingle();

    if (error) {
      console.warn('[isAdmin] select error:', error.message);
      return false;
    }
    return !!data;
  } catch (e: any) {
    console.warn('[isAdmin] exception:', e?.message ?? e);
    return false;
  }
}
