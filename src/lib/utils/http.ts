// src/lib/utils/http.ts
import { supabase } from '$lib/supabaseClient';

/**
 * Retorna headers amb Authorization: Bearer <token> si hi ha sessió.
 */
export async function getAuthHeader(): Promise<Record<string, string>> {
  try {
    const { data } = await supabase.auth.getSession();
    const token = data?.session?.access_token ?? null;
    return token ? { Authorization: `Bearer ${token}` } : {};
  } catch {
    return {};
  }
}

/**
 * authFetch — Wrapper de fetch que injecta automàticament el token i content-type (si cal).
 * Ús: await authFetch('/ruta', { method: 'POST', body: JSON.stringify(payload) })
 */
export async function authFetch(input: RequestInfo | URL, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  // Authorization
  const auth = await getAuthHeader();
  Object.entries(auth).forEach(([k, v]) => headers.set(k, v));
  // Content-Type (si hi ha body i no s'ha especificat)
  if (!headers.has('Content-Type') && init.body) headers.set('Content-Type', 'application/json');
  // (opcional) apikey pública, si el backend la demana
  const anonKey = (import.meta as any).env?.VITE_PUBLIC_APIKEY || (import.meta as any).env?.VITE_SUPABASE_ANON_KEY;
  if (anonKey && !headers.has('apikey')) headers.set('apikey', String(anonKey));

  return fetch(input, { ...init, headers, credentials: init.credentials ?? 'include' });
}
