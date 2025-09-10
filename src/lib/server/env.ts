import { SUPABASE_URL as S_URL, SUPABASE_ANON_KEY as S_KEY } from '$env/static/private';
import { env as DYN } from '$env/dynamic/private';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

export function getSupabaseEnv() {
  const url = S_URL || DYN.SUPABASE_URL || PUBLIC_SUPABASE_URL;
  const key = S_KEY || DYN.SUPABASE_ANON_KEY || PUBLIC_SUPABASE_ANON_KEY;
  if (!url) throw new Error('Missing SUPABASE_URL (no static private, dynamic private ni PUBLIC_).');
  if (!key) throw new Error('Missing SUPABASE_ANON_KEY (no static private, dynamic private ni PUBLIC_).');
  return { url, key };
}
