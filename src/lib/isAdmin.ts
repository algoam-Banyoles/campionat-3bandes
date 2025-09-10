import { supabase } from '$lib/supabaseClient';
import { loadingAuth, user } from '$lib/authStore';

/** Espera fins que l'autenticació estigui llesta */
async function waitAuthReady() {
  // polling simple; authStore canviarà $loadingAuth a false quan estigui llest
  // @ts-ignore - svelte store a top-level
  while ($loadingAuth) {
    await new Promise(r => setTimeout(r, 50));
  }
}

export async function isAdmin(): Promise<boolean> {
  try {
    await waitAuthReady();
    // @ts-ignore - svelte store a top-level
    const email = $user?.email ?? null;
    if (!email) return false;

    // consulta via RLS; la policy usa lower(email) = lower(jwt_email)
    const { data, error } = await supabase
      .from('admins')
      .select('email')
      .eq('email', email)   // la policy ja fa lower(...) al costat server
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
