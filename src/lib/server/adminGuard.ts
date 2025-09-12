import { createClient } from '@supabase/supabase-js';
import { error, type RequestEvent } from '@sveltejs/kit';
import { serverSupabase as baseServerSupabase } from './supabaseAdmin';

export function serverSupabase(event: RequestEvent) {
  return baseServerSupabase(event.request);
}


export function serverSupabase(event: Parameters<import('@sveltejs/kit').RequestHandler>[0]) {
  const token =
    event.cookies.get('sb-access-token') ??
    event.request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ??
    '';
  return createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    { global: { headers: token ? { Authorization: `Bearer ${token}` } : {} } }
  );
}

export async function requireAdmin(
  event: Parameters<import('@sveltejs/kit').RequestHandler>[0]
) {
  const supabase = serverSupabase(event);
  const { data: u } = await supabase.auth.getUser();
  const email = u?.user?.email ?? null;
  if (!email) {
    return new Response(JSON.stringify({ error: 'No autenticat' }), { status: 401 });
  }
  const { data, error } = await supabase.rpc('is_admin', { p_email: email });
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
  if (!data) {
    return new Response(JSON.stringify({ error: 'No autoritzat' }), { status: 403 });
  }
  return null; // ok
}

