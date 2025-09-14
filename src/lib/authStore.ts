// src/lib/authStore.ts
import { writable, derived, type Writable } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';
import { checkIsAdmin, invalidateAdminCache } from '$lib/roles';

// Tipus mínims perquè no depengui dels types de supabase-js
type Session = {
  access_token: string;
  user: { id: string; email: string | null };
};

export type UserProfile = {
  id: string;
  email: string | null;
  roles: string[];
};

// Estat principal d'autenticació
export const status: Writable<'loading' | 'authenticated' | 'anonymous'> = writable('loading');
export const session = writable<Session | null>(null);
export const user = writable<UserProfile | null>(null);

// Derivats
export const roles = derived(user, (u) => u?.roles ?? []);
export const adminStore = derived(roles, (r) => r.includes('admin'));
export const isAdmin = adminStore; // alias
export const token = derived(session, (s) => s?.access_token ?? null);

let hydrating: AbortController | null = null;

async function hydrate() {
  hydrating?.abort();
  const ac = new AbortController();
  hydrating = ac;
  try {
    const { data: sessData, error: sessErr } = await supabase.auth.getSession();
    if (ac.signal.aborted) return;
    if (sessErr || !sessData.session) {
      session.set(null);
      user.set(null);
      status.set('anonymous');
      return;
    }
    session.set({
      access_token: sessData.session.access_token,
      user: {
        id: sessData.session.user.id,
        email: sessData.session.user.email ?? null
      }
    });

    const rolesArr: string[] = [];
    try {
      invalidateAdminCache();
      const adm = await checkIsAdmin();
      if (adm) rolesArr.push('admin');
    } catch (e) {
      console.warn('checkIsAdmin failed', e);
    }
    if (ac.signal.aborted) return;
    user.set({
      id: sessData.session.user.id,
      email: sessData.session.user.email ?? null,
      roles: rolesArr
    });
    status.set('authenticated');
  } catch (e) {
    session.set(null);
    user.set(null);
    status.set('anonymous');
  }
}

/** Inicialitza sessió i listeners d'autenticació */
export async function initAuth() {
  await hydrate();
  supabase.auth.onAuthStateChange(async (event) => {
    if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
      await hydrate();
    }
    if (event === 'SIGNED_OUT') {
      hydrating?.abort();
      session.set(null);
      user.set(null);
      status.set('anonymous');
    }
  });
}

/** Tanca sessió i neteja estat. */
export async function logout() {
  await supabase.auth.signOut();
  hydrating?.abort();
  session.set(null);
  user.set(null);
  status.set('anonymous');
}

