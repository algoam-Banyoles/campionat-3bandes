import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

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
    if (!adm) return json({ ok: false, error: 'No autoritzat' }, { status: 403 });

    const { data: chal, error: chalErr } = await supabase
      .from('challenges')
      .select('event_id,reptador_id,reptat_id,pos_reptador,pos_reptat')
      .eq('id', challenge_id)
      .maybeSingle();
    if (chalErr) {
      if (isRlsError(chalErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: chalErr.message }, { status: 400 });
    }
    if (!chal) return json({ ok: false, error: 'Repte no trobat' }, { status: 404 });

    if (tipus === 'incompareixenca') {
      const now = new Date().toISOString();
      const { error: mErr } = await supabase.from('matches').insert({
        challenge_id,
        data_joc: now,
        caramboles_reptador: 0,
        caramboles_reptat: 0,
        entrades: 0,
        resultat: 'walkover_reptador',
        tiebreak: false,
        tiebreak_reptador: null,
        tiebreak_reptat: null
      });
      if (mErr) {
        if (isRlsError(mErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: mErr.message }, { status: 400 });
      }

      const { error: upErr } = await supabase
        .from('challenges')
        .update({ estat: 'jugat' })
        .eq('id', challenge_id);
      if (upErr) {
        if (isRlsError(upErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: upErr.message }, { status: 400 });
      }

      const { error: rpcErr } = await supabase.rpc('apply_match_result', { p_challenge: challenge_id });
      if (rpcErr) {
        if (isRlsError(rpcErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: rpcErr.message }, { status: 400 });
      }
    } else if (tipus === 'desacord_dates') {
      const { event_id, reptador_id, reptat_id, pos_reptador, pos_reptat } = chal;

      const { data: belowT, error: bTErr } = await supabase
        .from('ranking_positions')
        .select('player_id')
        .eq('event_id', event_id)
        .eq('posicio', (pos_reptat ?? 0) + 1)
        .maybeSingle();
      if (bTErr) {
        if (isRlsError(bTErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: bTErr.message }, { status: 400 });
      }

      const { data: belowR, error: bRErr } = await supabase
        .from('ranking_positions')
        .select('player_id')
        .eq('event_id', event_id)
        .eq('posicio', (pos_reptador ?? 0) + 1)
        .maybeSingle();
      if (bRErr) {
        if (isRlsError(bRErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: bRErr.message }, { status: 400 });
      }

      if (belowT?.player_id && belowT.player_id !== reptador_id && belowT.player_id !== reptat_id) {
        const { error } = await supabase
          .from('ranking_positions')
          .update({ posicio: pos_reptat })
          .eq('event_id', event_id)
          .eq('player_id', belowT.player_id);
        if (error) {
          if (isRlsError(error)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
          return json({ ok: false, error: error.message }, { status: 400 });
        }
      }

      if (belowR?.player_id && belowR.player_id !== reptador_id && belowR.player_id !== reptat_id && belowR.player_id !== belowT?.player_id) {
        const { error } = await supabase
          .from('ranking_positions')
          .update({ posicio: pos_reptador })
          .eq('event_id', event_id)
          .eq('player_id', belowR.player_id);
        if (error) {
          if (isRlsError(error)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
          return json({ ok: false, error: error.message }, { status: 400 });
        }
      }

      const { error: upR } = await supabase
        .from('ranking_positions')
        .update({ posicio: (pos_reptador ?? 0) + 1 })
        .eq('event_id', event_id)
        .eq('player_id', reptador_id);
      if (upR) {
        if (isRlsError(upR)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: upR.message }, { status: 400 });
      }

      const { error: upT } = await supabase
        .from('ranking_positions')
        .update({ posicio: (pos_reptat ?? 0) + 1 })
        .eq('event_id', event_id)
        .eq('player_id', reptat_id);
      if (upT) {
        if (isRlsError(upT)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: upT.message }, { status: 400 });
      }

      const { error: chalUp } = await supabase
        .from('challenges')
        .update({ estat: 'anullat' })
        .eq('id', challenge_id);
      if (chalUp) {
        if (isRlsError(chalUp)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: chalUp.message }, { status: 400 });
      }

      const { error: penErr } = await supabase.from('penalties').insert([
        { event_id, player_id: reptador_id, tipus: 'desacord_dates' },
        { event_id, player_id: reptat_id, tipus: 'desacord_dates' }
      ]);
      if (penErr) {
        if (isRlsError(penErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: penErr.message }, { status: 400 });
      }
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

