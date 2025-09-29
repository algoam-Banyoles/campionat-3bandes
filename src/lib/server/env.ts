// Fallback environment variable access for development
export function getSupabaseEnv(useServiceRole = false) {
  // Use process.env as fallback when SvelteKit env modules are not available
  const url = process.env.SUPABASE_URL || process.env.PUBLIC_SUPABASE_URL;
  
  let key: string;
  if (useServiceRole) {
    key = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
    if (!key) throw new Error('Missing SUPABASE_SERVICE_ROLE_KEY for admin operations.');
  } else {
    key = process.env.SUPABASE_ANON_KEY || process.env.PUBLIC_SUPABASE_ANON_KEY || '';
    if (!key) throw new Error('Missing SUPABASE_ANON_KEY (no private ni PUBLIC_).');
  }
  
  if (!url) throw new Error('Missing SUPABASE_URL (no private ni PUBLIC_).');
  return { url, key };
}
