import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

// Si s'usen cookies cal `credentials: 'include'` i, amb JWT,
// enviar `Authorization: Bearer <token>`

function isRlsError(e: any): boolean {
  const msg = String(e?.message || '').toLowerCase();
  return msg.includes('row level security') || msg.includes('permission') || msg.includes('policy');
}

export const POST: RequestHandler = async ({ request }) => {
  try {
    let body: {
      event_id?: string;
      reptador_id?: string;
      reptat_id?: string;
      dates_proposades?: string[];
      observacions?: string | null;
      tipus?: string;
    } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const event_id = body?.event_id;
    const reptador_id = body?.reptador_id;
    const reptat_id = body?.reptat_id;
    const dates_proposades = Array.isArray(body?.dates_proposades)
      ? body!.dates_proposades
      : [];
    const observacions = body?.observacions ?? null;
    const tipus = body?.tipus ?? 'normal';

    if (!event_id || !reptador_id || !reptat_id || dates_proposades.length === 0) {
      return json({ ok: false, error: 'Falten camps obligatoris' }, { status: 400 });
    }

    const supabase = serverSupabase(request);

    const { data: auth, error: authErr } = await supabase.auth.getUser();
    if (authErr || !auth?.user?.email) {
      return json({ ok: false, error: 'Sessió no iniciada' }, { status: 401 });
    }

    const { data: adminRow, error: admErr } = await supabase
      .from('admins')
      .select('email')
      .eq('email', auth.user.email)
      .limit(1)
      .maybeSingle();
    if (admErr) {
      return json({ ok: false, error: admErr.message }, { status: 400 });
    }
    const isAdmin = !!adminRow;

    let reptadorId = reptador_id;
    if (!isAdmin) {
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
      if (player.id !== reptador_id) {
        return json(
          { ok: false, error: "No pots crear reptes en nom d'altres" },
          { status: 403 }
        );
      }
      reptadorId = player.id;
    }
    const statuses = ['proposat', 'acceptat', 'programat'];

    const { count: c1, error: e1 } = await supabase
      .from('challenges')
      .select('id', { count: 'exact', head: true })
      .eq('event_id', event_id)
      .in('estat', statuses)
      .or(`reptador_id.eq.${reptadorId},reptat_id.eq.${reptadorId}`);
    if (e1) {
      if (isRlsError(e1)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: e1.message }, { status: 400 });
    }
    if ((c1 ?? 0) > 0) {
      return json({ ok: false, error: 'Ja tens un repte actiu per a aquest esdeveniment' }, { status: 400 });
    }

    const { count: c2, error: e2 } = await supabase
      .from('challenges')
      .select('id', { count: 'exact', head: true })
      .eq('event_id', event_id)
      .in('estat', statuses)
      .or(`reptador_id.eq.${reptat_id},reptat_id.eq.${reptat_id}`);
    if (e2) {
      if (isRlsError(e2)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: e2.message }, { status: 400 });
    }
    if ((c2 ?? 0) > 0) {
      return json({ ok: false, error: 'El jugador reptat ja té un repte actiu per a aquest esdeveniment' }, { status: 400 });
    }

    // Valida que el repte compleix la normativa
    const rpc = tipus === 'access' ? 'can_create_access_challenge' : 'can_create_challenge';
    const { data: chk, error: chkErr } = await supabase.rpc(rpc, {
      p_event: event_id,
      p_reptador: reptadorId,
      p_reptat: reptat_id
    });
    if (chkErr) {
      if (isRlsError(chkErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: chkErr.message }, { status: 400 });
    }
    const resChk = (chk as any)?.[0];
    if (!resChk?.ok) {
      return json({ ok: false, error: resChk?.reason ?? 'Repte no permès' }, { status: 400 });
    }

    const { error: insErr } = await supabase.from('challenges').insert({
      event_id,
      reptador_id: reptadorId,
      reptat_id,
      tipus,
      estat: 'proposat',
      dates_proposades,
      observacions
    });
    if (insErr) {
      if (isRlsError(insErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: insErr.message }, { status: 400 });
    }

    return json({ ok: true }, { status: 201 });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

