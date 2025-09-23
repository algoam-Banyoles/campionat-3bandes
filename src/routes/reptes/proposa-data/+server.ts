import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { getSupabaseEnv } from '$lib/server/env';
import { wrapRpc } from '$lib/errors';

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
    const authHeader = request.headers.get('authorization') || request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return json({ ok: false, error: 'No autenticat' }, { status: 401 });
    }
    const token = authHeader.slice(7).trim();

    let body: { challenge_id?: string; data_programada?: string } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const challenge_id = body?.challenge_id;
    const data_programada = body?.data_programada;
    if (!challenge_id) return json({ ok: false, error: 'Falta challenge_id' }, { status: 400 });
    if (!data_programada) return json({ ok: false, error: 'Falta data_programada' }, { status: 400 });
    if (!isIsoString(data_programada)) return json({ ok: false, error: 'Format de data ISO incorrecte' }, { status: 400 });

    const { url, key } = getSupabaseEnv();
    const supabase = wrapRpc(
      createClient(url, key, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: `Bearer ${token}` } }
      })
    );

    const { data: auth, error: authErr } = await supabase.auth.getUser();
    if (authErr || !auth?.user?.email) {
      return json({ ok: false, error: 'Sessió inv\u00e0lida' }, { status: 400 });
    }
    const email = auth.user.email;

    const { data: player, error: pErr } = await supabase
      .from('players')
      .select('id')
      .eq('email', email)
      .maybeSingle();
    if (pErr) {
      if (isRlsError(pErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: pErr.message }, { status: 400 });
    }
    if (!player) {
      return json({ ok: false, error: 'Usuari sense jugador associat' }, { status: 400 });
    }

    const { data: challenge, error: cErr } = await supabase
      .from('challenges')
      .select('reptador_id,reptat_id,estat')
      .eq('id', challenge_id)
      .maybeSingle();
    if (cErr) {
      if (isRlsError(cErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: cErr.message }, { status: 400 });
    }
    if (!challenge) {
      return json({ ok: false, error: 'Repte no trobat' }, { status: 404 });
    }

    if (![challenge.reptador_id, challenge.reptat_id].includes(player.id)) {
      return json({ ok: false, error: 'Nom\u00e9s participants del repte' }, { status: 403 });
    }

    const finals = ['jugat', 'refusat', 'caducat', 'anullat'];
    if (finals.includes(challenge.estat)) {
      return json({ ok: false, error: 'Repte en estat final' }, { status: 409 });
    }

    const { error: upErr } = await supabase
      .from('challenges')
      .update({ data_programada })
      .eq('id', challenge_id);
    if (upErr) {
      if (isRlsError(upErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: upErr.message }, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

