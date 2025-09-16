import { authState, type UserProfile } from '$lib/stores/auth';
import { supabase } from '$lib/supabaseClient';
import { checkIsAdmin, invalidateAdminCache } from '$lib/roles';

let initialized = false;

export function getAccessTokenSync(): string | null {
  let token: string | null = null;
  authState.update((s) => {
    if (s.status === 'authenticated') token = s.session.access_token;
    return s;
  });
  return token;
}

export async function hydrateSession() {
  const { data, error } = await supabase.auth.getSession();
  if (error || !data.session) {
    authState.set({ status: 'anonymous', session: null, user: null });
    return;
  }
  // Obtain roles
  const roles: string[] = [];
  try {
    invalidateAdminCache();
    const adm = await checkIsAdmin();
    if (adm) roles.push('admin');
  } catch (e) {
    console.warn('checkIsAdmin failed', e);
  }
  const me: UserProfile = {
    id: data.session.user.id,
    email: data.session.user.email ?? '',
    roles
  };
  authState.set({ status: 'authenticated', session: { access_token: data.session.access_token }, user: me });
}

export function initAuthClient() {
  if (initialized) return;
  initialized = true;
  hydrateSession();
  supabase.auth.onAuthStateChange(async (evt) => {
    if (evt === 'SIGNED_IN' || evt === 'TOKEN_REFRESHED') await hydrateSession();
    if (evt === 'SIGNED_OUT') authState.set({ status: 'anonymous', session: null, user: null });
  });
  if (typeof window !== 'undefined') {
    window.addEventListener('storage', (e) => {
      if (e.key && e.key.includes('auth')) hydrateSession();
    });
  }
}

export async function ensureFreshToken(): Promise<string | null> {
  const { data } = await supabase.auth.getSession();
  if (!data.session) return null;
  await hydrateSession();
  return data.session.access_token;
}

export async function signOut() {
  await supabase.auth.signOut();
  if (typeof fetch !== 'undefined') {
    try {
      await fetch('/api/session', { method: 'DELETE', credentials: 'include' });
    } catch {
      // ignore
    }
  }
  authState.set({ status: 'anonymous', session: null, user: null });
}
