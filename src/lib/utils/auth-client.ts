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
  // Timeout de 10 segons per evitar bloquejos indefinits
  const timeoutPromise = new Promise<void>((resolve) => {
    setTimeout(() => {
      console.warn('[auth-client] hydrateSession timeout after 10s - setting anonymous state');
      authState.set({ status: 'anonymous', session: null, user: null });
      resolve();
    }, 10000);
  });

  const hydrationPromise = (async () => {
    try {
      const { data, error } = await supabase.auth.getSession();

      // Si hi ha error o no hi ha sessió, establir com a anònim
      if (error) {
        console.warn('Auth session error:', error.message);
        authState.set({ status: 'anonymous', session: null, user: null });
        return;
      }

      if (!data.session) {
        authState.set({ status: 'anonymous', session: null, user: null });
        return;
      }

      // Verificar que el token no hagi expirat
      const now = Math.floor(Date.now() / 1000);
      if (data.session.expires_at && data.session.expires_at < now) {
        console.warn('Session expired, signing out');
        await signOut();
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
        // Si falla checkIsAdmin, potser és un problema d'autenticació
        // Intentem refrescar el token
        try {
          const { data: refreshData, error: refreshError } = await supabase.auth.refreshSession();
          if (refreshError) {
            console.warn('Token refresh failed:', refreshError.message);
            await signOut();
            return;
          }
        } catch (refreshErr) {
          console.warn('Token refresh error:', refreshErr);
          await signOut();
          return;
        }
      }

      const me: UserProfile = {
        id: data.session.user.id,
        email: data.session.user.email ?? '',
        roles
      };

      authState.set({
        status: 'authenticated',
        session: { access_token: data.session.access_token },
        user: me
      });

    } catch (error) {
      console.error('Unexpected error in hydrateSession:', error);
      authState.set({ status: 'anonymous', session: null, user: null });
    }
  })();

  return Promise.race([hydrationPromise, timeoutPromise]);
}

export function initAuthClient() {
  if (initialized) return;
  initialized = true;
  
  // Hydrate initial session
  hydrateSession().catch(error => {
    console.error('Initial session hydration failed:', error);
  });
  
  // Listen to auth state changes
  supabase.auth.onAuthStateChange(async (event, session) => {
    console.log('Auth state change:', event, session?.user?.email || 'no user');
    
    try {
      if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
        await hydrateSession();
      } else if (event === 'SIGNED_OUT') {
        authState.set({ status: 'anonymous', session: null, user: null });
      } else if (event === 'USER_UPDATED') {
        await hydrateSession();
      }
    } catch (error) {
      console.error('Error handling auth state change:', error);
      authState.set({ status: 'anonymous', session: null, user: null });
    }
  });
  
  // Listen to storage events for cross-tab sync
  if (typeof window !== 'undefined') {
    window.addEventListener('storage', (e) => {
      if (e.key && e.key.includes('auth')) {
        hydrateSession().catch(console.error);
      }
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
