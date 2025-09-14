// src/lib/server/supabaseAdmin.ts
import { createClient } from '@supabase/supabase-js';
import { getSupabaseEnv } from './env';
import { wrapRpc } from '../errors';

export function serverSupabase(req?: Request) {
  const { url, key } = getSupabaseEnv();

  const authHeader =
    req?.headers.get('authorization') ||
    req?.headers.get('Authorization') ||
    null;

  return wrapRpc(
    createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        headers: authHeader ? { Authorization: authHeader } : {}
      }
    })
  );
}

