// src/lib/authStore.ts
import { writable } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { adminStore, refreshAdmin, invalidateAdminCache } from '$lib/roles';

// Tipus mínims perquè no depengui dels types de supabase-js
type SessionUser = { email: string | null } | null;

export const user = writable<SessionUser>(null);
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
    supabase.auth.onAuthStateChange((_event, session) => {
      const u = session?.user ?? null;
      user.set(u ? { email: u.email ?? null } : null);
      invalidateAdminCache();
      void refreshAdmin();
    });

    // 3) calcula admin un cop carregada la sessió
    await refreshAdmin();
  } finally {
    authReady.set(true);
  }
}

/** Tanca sessió i neteja stores. */
export async function logout() {
  await supabase.auth.signOut();
  user.set(null);
  invalidateAdminCache();
  adminStore.set(false);
}
