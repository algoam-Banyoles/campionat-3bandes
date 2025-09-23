import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

function isIsoString(s: string): boolean {
  const d = new Date(s);
  return !isNaN(d.getTime()) && d.toISOString() === s;
}

function isRlsError(e: any): boolean {
  const msg = String(e?.message || '').toLowerCase();
  return msg.includes('row level security') || msg.includes('permission') || msg.includes('policy');
}

export const POST: RequestHandler = async ({ request }) => {
  try {
    let body: { id?: string; data_iso?: string | null } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const id = body?.id;
    const data_iso = body?.data_iso ?? null;
    if (!id) {
      return json({ ok: false, error: 'Falta id' }, { status: 400 });
    }
    if (data_iso !== null && typeof data_iso !== 'string') {
      return json({ ok: false, error: 'data_iso ha de ser cadena ISO o null' }, { status: 400 });
    }
    if (data_iso !== null && !isIsoString(data_iso)) {
      return json({ ok: false, error: 'Format de data ISO incorrecte' }, { status: 400 });
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
      .select('id,reptat_id,estat,dates_proposades')
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
      return json({ ok: false, error: 'Només el reptat pot acceptar el repte' }, { status: 400 });
    }
    if (challenge.estat !== 'proposat') {
      return json({ ok: false, error: 'El repte no està en estat proposat' }, { status: 400 });
    }

    const now = new Date().toISOString();
    if (data_iso !== null) {
      const dates = Array.isArray(challenge.dates_proposades) ? challenge.dates_proposades : [];
      if (!dates.includes(data_iso)) {
        return json({ ok: false, error: 'Data no és a la llista proposada' }, { status: 400 });
      }
      const { error: upErr } = await supabase
        .from('challenges')
        .update({ estat: 'programat', data_acceptacio: now, data_programada: data_iso })
        .eq('id', id);
      if (upErr) {
        if (isRlsError(upErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: upErr.message }, { status: 400 });
      }
    } else {
      const { error: upErr } = await supabase
        .from('challenges')
        .update({ estat: 'acceptat', data_acceptacio: now, data_programada: null })
        .eq('id', id);
      if (upErr) {
        if (isRlsError(upErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: upErr.message }, { status: 400 });
      }
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

