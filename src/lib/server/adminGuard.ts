import { createClient } from '@supabase/supabase-js';

function tokenFromEvent(event: Parameters<import('@sveltejs/kit').RequestHandler>[0]) {
  return (
    event.cookies.get('sb-access-token') ??
    event.request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ??
    null
  );
}

export function serverSupabase(
  event: Parameters<import('@sveltejs/kit').RequestHandler>[0],
  token?: string | null
) {
  const t = token ?? tokenFromEvent(event) ?? undefined;
  return createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    { global: { headers: t ? { Authorization: `Bearer ${t}` } : {} } }
  );
}

export async function requireAdmin(event: Parameters<import('@sveltejs/kit').RequestHandler>[0]) {
  const token = tokenFromEvent(event);
  if (!token) {
    return new Response(JSON.stringify({ error: 'No autenticat' }), { status: 401 });
  }

  const supabase = serverSupabase(event, token);
  const { data: u, error: userErr } = await supabase.auth.getUser();
  if (userErr) {
    return new Response(JSON.stringify({ error: userErr.message }), { status: 500 });
  }

  const email = u?.user?.email ?? null;
  if (!email) {
    return new Response(JSON.stringify({ error: 'No autenticat' }), { status: 401 });
  }
  const { data, error } = await supabase
    .from('admins')
    .select('email')
    .eq('email', email)
    .limit(1)
    .maybeSingle();
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
  if (!data) {
    return new Response(JSON.stringify({ error: 'Només admins' }), { status: 403 });
  }
  return null; // ok
}
