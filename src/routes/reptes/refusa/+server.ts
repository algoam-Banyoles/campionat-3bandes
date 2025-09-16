import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

function isRlsError(e: any): boolean {
  const msg = String(e?.message || '').toLowerCase();
  return msg.includes('row level security') || msg.includes('permission') || msg.includes('policy');
}

export const POST: RequestHandler = async ({ request }) => {
  try {
    let body: { id?: string; motiu?: string | null } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const id = body?.id;
    const motiu = typeof body?.motiu === 'string' ? body.motiu : null;
    if (!id) {
      return json({ ok: false, error: 'Falta id' }, { status: 400 });
    }

    const supabase = serverSupabase(request);

    const { data: auth, error: authErr } = await supabase.auth.getUser();
    if (authErr || !auth?.user?.email) {
      return json({ ok: false, error: 'Sessió invàlida' }, { status: 400 });
    }

    const { data: adm, error: admErr } = await supabase
      .from('admins')
      .select('email')
      .eq('email', auth.user.email)
      .maybeSingle();
    if (admErr) {
      if (isRlsError(admErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: admErr.message }, { status: 400 });
    }
    const isAdmin = !!adm;

    let playerId: string | null = null;
    if (!isAdmin) {
      const { data: player, error: pErr } = await supabase
        .from('players')
        .select('id')
        .eq('email', auth.user.email)
        .maybeSingle();
      if (pErr) {
        if (isRlsError(pErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: pErr.message }, { status: 400 });
      }
      if (!player) {
        return json({ ok: false, error: 'Usuari sense jugador associat' }, { status: 400 });
      }
      playerId = player.id;
    }

    const { data: challenge, error: cErr } = await supabase
      .from('challenges')
      .select('id,reptat_id,estat')
      .eq('id', id)
      .maybeSingle();
    if (cErr) {
      if (isRlsError(cErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: cErr.message }, { status: 400 });
    }
    if (!challenge) {
      return json({ ok: false, error: 'Repte no trobat' }, { status: 404 });
    }

    if (!isAdmin && challenge.reptat_id !== playerId) {
      return json({ ok: false, error: 'Només el reptat pot refusar el repte' }, { status: 400 });
    }
    if (challenge.estat !== 'proposat') {
      return json({ ok: false, error: 'El repte no està en estat proposat' }, { status: 400 });
    }

    const { error: upErr } = await supabase
      .from('challenges')
      .update({ estat: 'refusat' })
      .eq('id', id);
    if (upErr) {
      if (isRlsError(upErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: upErr.message }, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};
