import { json, type RequestEvent } from '@sveltejs/kit';
import { serverSupabase, requireAdmin } from '$lib/server/adminGuard';

export async function GET(event: RequestEvent) {
  const guard = await requireAdmin(event);
  if (guard) return guard; // 401/403/500

  const supabase = serverSupabase(event);
  const { data: userData, error } = await supabase.auth.getUser();
  return json({
    hasCookieToken: Boolean(event.cookies.get('sb-access-token')),
    hasAuthHeader: Boolean(event.request.headers.get('authorization')),
    email: userData?.user?.email ?? null,
    authError: error?.message ?? null
  });
}

