// src/routes/admin/debug/+server.ts
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { requireAdmin } from '$lib/server/adminGuard';
import { createClient } from '@supabase/supabase-js';
import { wrapRpc } from '$lib/errors';

// decodifica (sense verificar) la part payload d'un JWT
function decodeJwtPayload(token: string | null) {
  try {
    if (!token) return null;
    const [, payload] = token.split('.');
    if (!payload) return null;
    const pad = (s: string) => s + '='.repeat((4 - (s.length % 4)) % 4);
    const str = atob(pad(payload).replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(str);
  } catch {
    return null;
  }
}

export const GET: RequestHandler = async (event) => {
  const guard = await requireAdmin(event);
  if (guard) return guard; // 401/403/500

  const token =
    event.cookies.get('sb-access-token') ??
    event.request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ??
    null;
  const claims = decodeJwtPayload(token);
  const jwtEmail = claims?.email ?? null;

  // prova de RLS amb el token: podem llegir la pròpia fila d'admins?
  let rls_ok = false;
  let rls_error: string | null = null;
  try {
    const supabase = wrapRpc(
      createClient(
        import.meta.env.PUBLIC_SUPABASE_URL,
        import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
        { global: { headers: { Authorization: `Bearer ${token ?? ''}` } } }
      )
    );
    const { error } = await supabase
      .from('admins')
      .select('email', { head: true, count: 'exact' })
      .eq('email', jwtEmail ?? '')
      .limit(1);
    if (!error) rls_ok = true;
    else rls_error = error.message ?? 'unknown';
  } catch (e: any) {
    rls_error = e?.message ?? String(e);
  }

  return json({
    hasAuthHeader: !!token,
    jwtEmail,
    rls_ok,
    rls_error
  });
};

