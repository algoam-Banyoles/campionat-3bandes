import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';

export async function GET(event) {
  const token =
    event.cookies.get('sb-access-token') ??
    event.request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ??
    '';
  const supabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    { global: { headers: token ? { Authorization: `Bearer ${token}` } : {} } }
  );

  const { data: userData, error } = await supabase.auth.getUser();
  return json({
    hasCookieToken: Boolean(event.cookies.get('sb-access-token')),
    hasAuthHeader: Boolean(event.request.headers.get('authorization')),
    email: userData?.user?.email ?? null,
    authError: error?.message ?? null
  });
}

