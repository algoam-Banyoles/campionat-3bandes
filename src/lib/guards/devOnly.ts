import type { SupabaseClient } from '@supabase/supabase-js';
import { error } from '@sveltejs/kit';

// Restricció temporal per desenvolupament: només algoam@gmail.com
// TODO: Eliminar aquesta restricció quan estigui llest per producció
const ALLOWED_DEV_EMAIL = 'algoam@gmail.com';

export async function ensureDevAccess(supabase: SupabaseClient): Promise<void> {
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  const email = userData.user?.email ?? null;

  if (userErr || !email) {
    throw error(403, 'Accés restringit durant desenvolupament');
  }

  if (email !== ALLOWED_DEV_EMAIL) {
    throw error(403, 'Funcionalitat en desenvolupament. Accés restringit.');
  }
}

// Helper per checks en components
export function isDevUser(userEmail: string | null | undefined): boolean {
  return userEmail === ALLOWED_DEV_EMAIL;
}