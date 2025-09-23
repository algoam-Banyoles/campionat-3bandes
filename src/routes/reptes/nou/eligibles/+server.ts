import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

function isRlsError(e: any): boolean {
  const msg = String(e?.message || '').toLowerCase();
  return msg.includes('row level security') || msg.includes('permission') || msg.includes('policy');
}

export const GET: RequestHandler = async ({ request }) => {
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
    const myPlayerId = player.id as string;

    const { data: event, error: eErr } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .order('creat_el', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (eErr) {
      if (isRlsError(eErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: eErr.message }, { status: 400 });
    }
    if (!event) {
      return json({ ok: false, error: 'No hi ha cap esdeveniment actiu' }, { status: 400 });
    }
    const eventId = event.id as string;

    const { data: rank, error: rErr } = await supabase
      .from('ranking_positions')
      .select('posicio, player_id, players!inner(nom)')
      .eq('event_id', eventId)
      .order('posicio', { ascending: true });
    if (rErr) {
      if (isRlsError(rErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: rErr.message }, { status: 400 });
    }

    const allRank = (rank ?? []).map((r: any) => ({
      posicio: r.posicio,
      player_id: r.player_id,
      nom: r.players?.nom ?? '—'
    }));

    const mine = allRank.find((r) => r.player_id === myPlayerId) ?? null;
    if (!mine) {
      return json({ ok: false, error: 'No formes part del rànquing actual.' }, { status: 400 });
    }
    const myPos = mine.posicio as number;

    const reptables: { posicio: number; player_id: string; nom: string }[] = [];
    const noReptables: { posicio: number; player_id: string; nom: string; motiu: string }[] = [];

    for (const r of allRank) {
      if (r.player_id === myPlayerId) continue;
      const { data: chk, error: eChk } = await supabase.rpc('can_create_challenge', {
        p_event: eventId,
        p_reptador: myPlayerId,
        p_reptat: r.player_id
      });
      if (eChk) {
        noReptables.push({ ...r, motiu: 'no disponible' });
        continue;
      }
      const res = (chk as any)?.[0];
      if (res?.ok) {
        reptables.push(r);
      } else {
        let motiu = res?.reason ?? 'no disponible';
        const lower = motiu.toLowerCase();
        if (lower.includes('repte actiu')) motiu = 'té un repte actiu';
        else if (lower.includes('temps mínim')) motiu = 'cooldown no complert';
        else if (lower.includes('diferència de posicions')) motiu = 'fora del marge de posicions';
        noReptables.push({ ...r, motiu });
      }
    }

    return json(
      {
        ok: true,
        my_player_id: myPlayerId,
        my_pos: myPos,
        event_id: eventId,
        reptables,
        no_reptables: noReptables
      },
      { status: 200 }
    );
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

