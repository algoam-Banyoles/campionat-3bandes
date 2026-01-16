import { authState, type UserProfile } from '$lib/stores/auth';
import { supabase } from '$lib/supabaseClient';
import { checkIsAdmin, invalidateAdminCache } from '$lib/roles';

let initialized = false;
let hydrationInProgress = false;

export function getAccessTokenSync(): string | null {
  let token: string | null = null;
  authState.update((s) => {
    if (s.status === 'authenticated') token = s.session.access_token;
    return s;
  });
  return token;
}

export async function hydrateSession() {
  // Evitar múltiples crides simultànies
  if (hydrationInProgress) {
    console.log('[auth-client] hydrateSession already in progress, skipping');
    return;
  }

  hydrationInProgress = true;

  // Timeout de 20 segons per evitar bloquejos indefinits (més temps per connexions lentes en mòbils)
  let timeoutId: NodeJS.Timeout;
  let timedOut = false;

  const timeoutPromise = new Promise<void>((resolve) => {
    timeoutId = setTimeout(() => {
      timedOut = true;
      console.warn('[auth-client] hydrateSession timeout after 20s - keeping current state');
      hydrationInProgress = false;
      resolve();
    }, 20000);
  });

  const hydrationPromise = (async () => {
    try {
      const { data, error } = await supabase.auth.getSession();

      // Si ja ha expirat el timeout, no fer res
      if (timedOut) return;

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

      // Obtain roles amb timeout més llarg
      const roles: string[] = [];
      try {
        invalidateAdminCache();
        const adm = await checkIsAdmin();
        if (adm) roles.push('admin');
      } catch (e) {
        console.warn('checkIsAdmin failed', e);
        // NO fer logout si falla checkIsAdmin - mantenir usuari autenticat sense rol admin
        // Només registrar l'error i continuar amb roles buit
      }

      // Si ja ha expirat el timeout, no actualitzar l'estat
      if (timedOut) return;

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
      // Només establir anònim si no és un error de timeout
      if (!timedOut) {
        authState.set({ status: 'anonymous', session: null, user: null });
      }
    } finally {
      // Cancel·lar timeout si la promesa es resol abans
      clearTimeout(timeoutId);
      hydrationInProgress = false;
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
