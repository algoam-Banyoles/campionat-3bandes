import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { checkIsAdmin } from '$lib/roles';
import { serverSupabase } from '$lib/server/supabaseAdmin';

export const DELETE: RequestHandler = async ({ params, request }) => {
  try {
    const isAdmin = await checkIsAdmin();
    if (!isAdmin) {
      return json({ ok: false, error: 'Només admins' }, { status: 403 });
    }

    const id = params.id;
    if (!id) {
      return json({ ok: false, error: 'ID requerit' }, { status: 400 });
    }

    const supabase = serverSupabase(request);
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

