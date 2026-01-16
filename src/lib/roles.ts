// src/lib/roles.ts
import { supabase } from '$lib/supabaseClient';

const CACHE_TTL_MS = 60 * 1000;
let cache: { value: boolean; ts: number } | null = null;

export function invalidateAdminCache(): void {
  cache = null;
}

export async function checkIsAdmin(): Promise<boolean> {
  const now = Date.now();
  if (cache && now - cache.ts < CACHE_TTL_MS) {
    return cache.value;
  }

  // Timeout de 15 segons per evitar bloquejos (més temps per connexions lentes)
  let timeoutId: NodeJS.Timeout;
  const timeoutPromise = new Promise<boolean>((resolve) => {
    timeoutId = setTimeout(() => {
      console.warn('[roles] checkIsAdmin timeout after 15s - assuming non-admin');
      cache = { value: false, ts: now };
      resolve(false);
    }, 15000);
  });

  const checkPromise = (async () => {
    try {
      const { data: sessionData, error: sessErr } = await supabase.auth.getSession();
      if (sessErr) {
        console.warn('[roles] getSession error:', sessErr.message);
        cache = { value: false, ts: now };
        return false;
      }
      const email = sessionData.session?.user?.email ?? null;
      if (!email) {
        cache = { value: false, ts: now };
        return false;
      }

      let retries = 2;
      while (retries > 0) {
        const { data, error } = await supabase
          .from('admins')
          .select('email')
          .ilike('email', email)
          .limit(1)
          .maybeSingle();

        if (!error) {
          const val = !!data;
          cache = { value: val, ts: now };
          return val;
        }

        console.warn('[roles] Error checking admin status (retries left:', retries - 1, '):', error.message, 'for email:', email);

        // Si és un error de schema, no reintentis
        if (error.message.includes('relation') || error.message.includes('does not exist')) {
          console.error('[roles] Database schema issue - admins table missing or inaccessible');
          break;
        }

        retries--;
        if (retries > 0) {
          // Espera 100ms abans de reintentar
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }

      cache = { value: false, ts: now };
      return false;
    } finally {
      // Cancel·lar timeout si la promesa es resol abans
      clearTimeout(timeoutId);
    }
  })();

  return Promise.race([checkPromise, timeoutPromise]);
}

