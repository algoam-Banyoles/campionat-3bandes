import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

function isRlsError(e: any): boolean {
  const msg = String(e?.message || '').toLowerCase();
  return msg.includes('row level security') || msg.includes('permission') || msg.includes('policy');
}

export const POST: RequestHandler = async ({ request }) => {
  try {
    const supabase = serverSupabase(request);

    const { data: auth, error: authErr } = await supabase.auth.getUser();
    if (authErr || !auth?.user?.email) {
      return json({ ok: false, error: 'Sessió invàlida' }, { status: 400 });
    }

    const { data: player, error: pErr } = await supabase
      .from('socis')
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

    const { data: event, error: eErr } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .limit(1)
      .maybeSingle();
    if (eErr) {
      if (isRlsError(eErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: eErr.message }, { status: 400 });
    }
    if (!event) {
      return json({ ok: false, error: 'No hi ha cap event actiu' }, { status: 400 });
    }
      const event_id = event.id;
      const { data: rp, error: rpErr } = await supabase
        .from('ranking_positions')
        .select('posicio')
        .eq('event_id', event_id)
        .eq('player_id', player.id)
        .maybeSingle();
      if (rpErr) {
        if (isRlsError(rpErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: rpErr.message }, { status: 400 });
      }
      if (!rp) {
        return json({ ok: false, error: 'No estàs inscrit a l’event actiu' }, { status: 400 });
      }

      const { error: rpcErr } = await supabase.rpc('apply_voluntary_drop', {
        p_event: event_id,
        p_player: player.id
      });
      if (rpcErr) {
        if (isRlsError(rpcErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: rpcErr.message }, { status: 400 });
      }

      return json({ ok: true, message: 'Baixa registrada' });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

