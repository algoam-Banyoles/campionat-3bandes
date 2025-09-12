import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { checkIsAdmin } from '$lib/roles';
import { serverSupabase } from '$lib/server/supabaseAdmin';

export const POST: RequestHandler = async ({ request }) => {
  try {
    let body: { clearWaiting?: boolean } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const clearWaiting = !!body?.clearWaiting;

    const isAdmin = await checkIsAdmin();
    if (!isAdmin) {
      return json({ ok: false, error: 'Només admins' }, { status: 403 });
    }

    const supabase = serverSupabase(request);
    const { data, error } = await supabase.rpc('reset_event_to_initial', {
      p_event: null,
      p_clear_waiting: clearWaiting
    });
    if (error) {
      return json({ ok: false, error: 'Error resetejant campionat' }, { status: 400 });
    }

    return json({ ok: true, restored: data ?? 0 });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

