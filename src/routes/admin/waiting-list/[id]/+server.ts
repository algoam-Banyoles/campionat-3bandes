import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { requireAdmin } from '$lib/server/adminGuard';
import { createClient } from '@supabase/supabase-js';

export const DELETE: RequestHandler = async (event) => {
  try {
    await requireAdmin(event);

    const id = event.params.id;
    if (!id) {
      return json({ ok: false, error: 'ID requerit' }, { status: 400 });
    }

    const token =
      event.cookies.get('sb-access-token') ??
      event.request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ??
      '';
    const supabase = createClient(
      import.meta.env.PUBLIC_SUPABASE_URL,
      import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
      { global: { headers: { Authorization: `Bearer ${token}` } } }
    );

    const { error } = await supabase
      .from('waiting_list')
      .delete()
      .eq('id', id);
    if (error) {
      return json({ ok: false, error: 'No s\u2019ha pogut eliminar' }, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

