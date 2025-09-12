import { createClient } from '@supabase/supabase-js';
import { error, type RequestEvent } from '@sveltejs/kit';

function getToken(event: RequestEvent): string | null {
  return (
    event.cookies.get('sb-access-token') ??
    event.request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ??
    null
  );
}

export async function getServerUser(event: RequestEvent): Promise<{ email: string } | null> {
  const token = getToken(event);
  if (!token) return null;

  const supabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    { global: { headers: { Authorization: `Bearer ${token}` } } }
  );

  const { data, error: userErr } = await supabase.auth.getUser();
  const email = data.user?.email ?? null;
  if (userErr || !email) return null;
  return { email };
}

export async function requireAdmin(event: RequestEvent): Promise<{ email: string }> {
  const user = await getServerUser(event);
  if (!user) {
    throw error(401, 'Unauthorized');
  }

  const token = getToken(event) ?? '';
  const supabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    { global: { headers: { Authorization: `Bearer ${token}` } } }
  );

  const { data: isAdmin, error: adminErr } = await supabase.rpc('is_admin', { p_email: user.email });
  if (adminErr || !isAdmin) {
    throw error(403, 'Només admins');
  }

  return user;
}

