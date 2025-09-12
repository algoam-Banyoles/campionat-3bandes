import { json } from '@sveltejs/kit';
import { requireAdmin } from '$lib/server/adminGuard';
import { createClient } from '@supabase/supabase-js';

export async function POST(event) {
  await requireAdmin(event);

  const token =
    event.cookies.get('sb-access-token') ??
    event.request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ??
    '';
  const supabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    { global: { headers: { Authorization: `Bearer ${token}` } } }
  );

  const { clearWaiting = false } = await event.request.json().catch(() => ({}));
  const { data, error } = await supabase.rpc('reset_event_to_initial', {
    p_event: null,
    p_clear_waiting: !!clearWaiting
  });
  if (error) {
    return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
  }
  return json({ ok: true, ...(data ?? {}) });
}

