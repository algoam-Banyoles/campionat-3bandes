import { json } from '@sveltejs/kit';
import { serverSupabase, requireAdmin } from '$lib/server/adminGuard';

export function GET() {
  return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
}

export async function POST(event) {
  const guard = await requireAdmin(event);
  if (guard) return guard; // 401/403/500

  const supabase = serverSupabase(event);
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

