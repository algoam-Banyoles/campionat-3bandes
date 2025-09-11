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
    const myPos = rp.posicio as number;

    const { data: below, error: bErr } = await supabase
      .from('ranking_positions')
      .select('player_id,posicio')
      .eq('event_id', event_id)
      .gt('posicio', myPos)
      .order('posicio', { ascending: true });
    if (bErr) {
      if (isRlsError(bErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: bErr.message }, { status: 400 });
    }

    const { error: delErr } = await supabase
      .from('ranking_positions')
      .delete()
      .eq('event_id', event_id)
      .eq('player_id', player.id);
    if (delErr) {
      if (isRlsError(delErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: delErr.message }, { status: 400 });
    }

    const history: any[] = [];
    history.push({
      event_id,
      player_id: player.id,
      posicio_anterior: myPos,
      posicio_nova: null,
      motiu: 'baixa',
      ref_challenge: null
    });

    for (const b of below ?? []) {
      const { error } = await supabase
        .from('ranking_positions')
        .update({ posicio: (b.posicio as number) - 1 })
        .eq('event_id', event_id)
        .eq('player_id', b.player_id);
      if (error) {
        if (isRlsError(error)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: error.message }, { status: 400 });
      }
      history.push({
        event_id,
        player_id: b.player_id,
        posicio_anterior: b.posicio,
        posicio_nova: (b.posicio as number) - 1,
        motiu: 'puja per baixa',
        ref_challenge: null
      });
    }

    const { data: wait, error: wErr } = await supabase
      .from('waiting_list')
      .select('player_id')
      .eq('event_id', event_id)
      .order('ordre', { ascending: true })
      .limit(1)
      .maybeSingle();
    if (wErr) {
      if (isRlsError(wErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: wErr.message }, { status: 400 });
    }

    if (wait?.player_id) {
      const { error: insErr } = await supabase
        .from('ranking_positions')
        .insert({ event_id, player_id: wait.player_id, posicio: 20 });
      if (insErr) {
        if (isRlsError(insErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: insErr.message }, { status: 400 });
      }

      const { error: delWErr } = await supabase
        .from('waiting_list')
        .delete()
        .eq('event_id', event_id)
        .eq('player_id', wait.player_id);
      if (delWErr) {
        if (isRlsError(delWErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: delWErr.message }, { status: 400 });
      }

      history.push({
        event_id,
        player_id: wait.player_id,
        posicio_anterior: null,
        posicio_nova: 20,
        motiu: 'entra per baixa',
        ref_challenge: null
      });
    }

    if (history.length) {
      const { error: histErr } = await supabase
        .from('history_position_changes')
        .insert(history);
      if (histErr) {
        if (isRlsError(histErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: histErr.message }, { status: 400 });
      }
    }

    return json({ ok: true, message: 'Baixa registrada' });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

