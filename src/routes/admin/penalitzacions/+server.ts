import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';
import { checkIsAdmin } from '$lib/roles';

function isRlsError(e: any): boolean {
  const msg = String(e?.message || '').toLowerCase();
  return msg.includes('row level security') || msg.includes('permission') || msg.includes('policy');
}

export const POST: RequestHandler = async ({ request }) => {
  try {
    let body: { challenge_id?: string; tipus?: string } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const challenge_id = body?.challenge_id;
    const tipus = body?.tipus;
    if (!challenge_id || !tipus) {
      return json({ ok: false, error: 'Falten challenge_id o tipus' }, { status: 400 });
    }
    if (tipus !== 'incompareixenca' && tipus !== 'desacord_dates') {
      return json({ ok: false, error: 'Tipus no suportat' }, { status: 400 });
    }

    const isAdmin = await checkIsAdmin();
    if (!isAdmin) {
      return json({ ok: false, error: 'Només admins' }, { status: 403 });
    }

    const supabase = serverSupabase(request);
    const { error } = await supabase.rpc('apply_challenge_penalty', {
      p_challenge: challenge_id,
      p_tipus: tipus
    });

    if (error) {
      if (isRlsError(error)) {
        return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      }
      return json({ ok: false, error: error.message }, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

