import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { requireAdmin, serverSupabase } from '$lib/server/adminGuard';

export const DELETE: RequestHandler = async (event) => {
  try {
    const guard = await requireAdmin(event);
    if (guard) return guard; // 401/403/500

    const id = event.params.id;
    if (!id) {
      return json({ ok: false, error: 'ID requerit' }, { status: 400 });
    }

    const supabase = serverSupabase(event);

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

