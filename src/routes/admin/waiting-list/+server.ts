import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { checkIsAdmin } from '$lib/roles';
import { serverSupabase } from '$lib/server/supabaseAdmin';

export const GET: RequestHandler = async ({ request }) => {
  try {
    const isAdmin = await checkIsAdmin();
    if (!isAdmin) {
      return json({ ok: false, error: 'Només admins' }, { status: 403 });
    }

    const supabase = serverSupabase(request);
    const { data: event, error: eErr } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .limit(1)
      .maybeSingle();
    if (eErr) {
      return json({ ok: false, error: 'Error obtenint event actiu' }, { status: 400 });
    }
    if (!event) {
      return json({ ok: false, error: 'No hi ha cap event actiu' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('waiting_list')
      .select('id, player_id, ordre, data_inscripcio, players (nom)')
      .eq('event_id', event.id)
      .order('ordre', { ascending: true });
    if (error) {
      return json({ ok: false, error: 'Error obtenint llista d\u2019espera' }, { status: 400 });
    }

    const rows = (data ?? []).map((r: any) => ({
      id: r.id,
      player_id: r.player_id,
      nom: r.players?.nom ?? '',
      ordre: r.ordre,
      data_inscripcio: r.data_inscripcio
    }));

    return json({ rows });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

export const POST: RequestHandler = async ({ request }) => {
  try {
    let body: { player_id?: string; ordre?: number } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const player_id = body?.player_id;
    let ordre = body?.ordre;
    if (!player_id) {
      return json({ ok: false, error: 'Falta player_id' }, { status: 400 });
    }

    const isAdmin = await checkIsAdmin();
    if (!isAdmin) {
      return json({ ok: false, error: 'Només admins' }, { status: 403 });
    }

    const supabase = serverSupabase(request);
    const { data: event, error: eErr } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .limit(1)
      .maybeSingle();
    if (eErr) {
      return json({ ok: false, error: 'Error obtenint event actiu' }, { status: 400 });
    }
    if (!event) {
      return json({ ok: false, error: 'No hi ha cap event actiu' }, { status: 400 });
    }

    const { data: rp, error: rpErr } = await supabase
      .from('ranking_positions')
      .select('id')
      .eq('event_id', event.id)
      .eq('player_id', player_id)
      .maybeSingle();
    if (rpErr) {
      return json({ ok: false, error: 'Error verificant r\u00E0nquing' }, { status: 400 });
    }
    if (rp) {
      return json({ ok: false, error: 'Jugador ja inscrit' }, { status: 400 });
    }

    const { data: wl, error: wlErr } = await supabase
      .from('waiting_list')
      .select('id')
      .eq('event_id', event.id)
      .eq('player_id', player_id)
      .maybeSingle();
    if (wlErr) {
      return json({ ok: false, error: 'Error verificant llista d\u2019espera' }, { status: 400 });
    }
    if (wl) {
      return json({ ok: false, error: 'Jugador ja en llista d\u2019espera' }, { status: 400 });
    }

    if (ordre == null) {
      const { data: maxRow, error: mErr } = await supabase
        .from('waiting_list')
        .select('ordre')
        .eq('event_id', event.id)
        .order('ordre', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (mErr) {
        return json({ ok: false, error: 'Error calculant ordre' }, { status: 400 });
      }
      ordre = (maxRow?.ordre ?? 0) + 1;
    }

    const { error: insErr } = await supabase
      .from('waiting_list')
      .insert({ event_id: event.id, player_id, ordre });
    if (insErr) {
      return json({ ok: false, error: 'No s\u2019ha pogut afegir' }, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

