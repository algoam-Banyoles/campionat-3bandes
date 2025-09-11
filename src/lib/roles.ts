// src/lib/roles.ts
import { writable } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';

const CACHE_TTL_MS = 60 * 1000;
let cache: { value: boolean; ts: number } | null = null;

export const adminStore = writable<boolean>(false);

export function invalidateAdminCache(): void {
  cache = null;
}

export async function checkIsAdmin(): Promise<boolean> {
  const now = Date.now();
  if (cache && now - cache.ts < CACHE_TTL_MS) {
    return cache.value;
  }

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

  const { data, error } = await supabase
    .from('admins')
    .select('email')
    .ilike('email', email)
    .limit(1)
    .maybeSingle();

  if (error) {
    console.warn('[roles] select error:', error.message);
    cache = { value: false, ts: now };
    return false;
  }
  const val = !!data;
  cache = { value: val, ts: now };
  return val;
}

export async function refreshAdmin(): Promise<boolean> {
  invalidateAdminCache();
  const val = await checkIsAdmin();
  adminStore.set(val);
  return val;
}

