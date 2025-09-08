// src/lib/authStore.ts
import { writable } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';

// Tipus mínims perquè no depengui dels types de supabase-js
type SessionUser = { email: string | null } | null;

export const user = writable<SessionUser>(null);
export const isAdmin = writable<boolean>(false);
export const authReady = writable<boolean>(false);

/** Recarrega sessió i computa si és admin (consulta taula 'admins' per email). */
export async function initAuth() {
  try {
    // 1) sessió actual
    const { data: sessData, error: sessErr } = await supabase.auth.getSession();
    if (sessErr) throw sessErr;
    const sessUser = sessData.session?.user ?? null;
    user.set(sessUser ? { email: sessUser.email ?? null } : null);

    // 2) escolta canvis d'autenticació
    supabase.auth.onAuthStateChange(async (_event, session) => {
      const u = session?.user ?? null;
      user.set(u ? { email: u.email ?? null } : null);
      await refreshIsAdmin(); // recalcula rol
    });

    // 3) calcula admin un cop carregada la sessió
    await refreshIsAdmin();
  } finally {
    authReady.set(true);
  }
}

/** Calcula si l'usuari és admin consultant la taula 'admins' (camp email). */
export async function refreshIsAdmin() {
  const current = getSafe(user);
  if (!current?.email) {
    isAdmin.set(false);
    return;
  }
  const { data, error } = await supabase
    .from('admins')
    .select('email')
    .eq('email', current.email)
    .maybeSingle();

  if (error) {
    // En dev: mostra a consola, però no tombis l'app
    console.warn('admins check error:', error.message);
  }
  isAdmin.set(!!data);
}

/** Tanca sessió i neteja stores. */
export async function logout() {
  await supabase.auth.signOut();
  user.set(null);
  isAdmin.set(false);
}

/** Utilitat per llegir un valor d'store sense subscripció externa */
function getSafe<T>(store: { subscribe: (run: (v: T) => void) => () => void }): T | null {
  let val: T | null = null;
  const unsub = store.subscribe((v) => (val = v));
  unsub();
  return val;
}
