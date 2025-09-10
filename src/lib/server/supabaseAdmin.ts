// src/lib/server/supabaseAdmin.ts
import { createClient } from '@supabase/supabase-js';
import { getSupabaseEnv } from './env';

export function serverSupabase(req?: Request) {
  const { url, key } = getSupabaseEnv();

  const authHeader =
    req?.headers.get('authorization') ||
    req?.headers.get('Authorization') ||
    null;

  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: authHeader ? { Authorization: authHeader } : {}
    }
  });
}

