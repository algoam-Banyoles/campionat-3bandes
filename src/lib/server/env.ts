import { env as DYN_PRIVATE } from '$env/dynamic/private';
import { env as DYN_PUBLIC } from '$env/dynamic/public';

export function getSupabaseEnv(useServiceRole = false) {
  const url = DYN_PRIVATE.SUPABASE_URL || DYN_PUBLIC.PUBLIC_SUPABASE_URL;
  
  let key: string;
  if (useServiceRole) {
    key = DYN_PRIVATE.SUPABASE_SERVICE_ROLE_KEY;
    if (!key) throw new Error('Missing SUPABASE_SERVICE_ROLE_KEY for admin operations.');
  } else {
    key = DYN_PRIVATE.SUPABASE_ANON_KEY || DYN_PUBLIC.PUBLIC_SUPABASE_ANON_KEY;
    if (!key) throw new Error('Missing SUPABASE_ANON_KEY (no private ni PUBLIC_).');
  }
  
  if (!url) throw new Error('Missing SUPABASE_URL (no private ni PUBLIC_).');
  return { url, key };
}
