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
    let body: { id?: string; dates_iso?: string[] } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const id = body?.id;
    const dates_iso = Array.isArray(body?.dates_iso) ? body!.dates_iso : [];
    if (!id) {
      return json({ ok: false, error: 'Falta id' }, { status: 400 });
    }
    if (dates_iso.length === 0) {
      return json({ ok: false, error: 'Falta almenys una data' }, { status: 400 });
    }
    if (dates_iso.length > 3) {
      return json({ ok: false, error: 'M\u00e0xim 3 dates' }, { status: 400 });
    }
    for (const d of dates_iso) {
      if (typeof d !== 'string' || !isIsoString(d)) {
        return json({ ok: false, error: 'Format de data ISO incorrecte' }, { status: 400 });
      }
    }

    const supabase = serverSupabase(request);

    const { data: auth, error: authErr } = await supabase.auth.getUser();
    if (authErr || !auth?.user?.email) {
      return json({ ok: false, error: 'Sessió inv\u00e0lida' }, { status: 400 });
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

    let mySociNumero: number | null = null;
    if (!isAdmin) {
      const { data: soci, error: sErr } = await supabase
        .from('socis')
        .select('numero_soci')
        .eq('email', auth.user.email)
        .maybeSingle();
      if (sErr) {
        if (isRlsError(sErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
        return json({ ok: false, error: sErr.message }, { status: 400 });
      }
      if (!soci) {
        return json({ ok: false, error: 'Usuari sense soci associat' }, { status: 400 });
      }
      mySociNumero = soci.numero_soci;
    }

    const { data: challenge, error: cErr } = await supabase
      .from('challenges')
      .select('id,reptat_soci_numero,estat')
      .eq('id', id)
      .maybeSingle();
    if (cErr) {
      if (isRlsError(cErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: cErr.message }, { status: 400 });
    }
    if (!challenge) {
      return json({ ok: false, error: 'Repte no trobat' }, { status: 404 });
    }

    if (!isAdmin && challenge.reptat_soci_numero !== mySociNumero) {
      return json({ ok: false, error: 'Nom\u00e9s el reptat pot proposar noves dates' }, { status: 400 });
    }
    if (challenge.estat !== 'proposat') {
      return json({ ok: false, error: 'El repte no est\u00e0 en estat proposat' }, { status: 400 });
    }

    const { error: upErr } = await supabase
      .from('challenges')
      .update({ dates_proposades: dates_iso })
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
