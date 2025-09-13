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
    let body: { id?: string; data_iso?: string } | null = null;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const id = body?.id;
    const data_iso = body?.data_iso;
    if (!id) return json({ ok: false, error: 'Falta id' }, { status: 400 });
    if (!data_iso) return json({ ok: false, error: 'Falta data_iso' }, { status: 400 });
    if (!isIsoString(data_iso)) return json({ ok: false, error: 'Format de data ISO incorrecte' }, { status: 400 });

    const supabase = serverSupabase(request);

    const { data: auth, error: authErr } = await supabase.auth.getUser();
    if (authErr || !auth?.user?.email) {
      return json({ ok: false, error: 'Sessió invàlida' }, { status: 400 });
    }

    const { data: adm, error: admErr } = await supabase.rpc('is_admin', {
      p_email: auth.user.email
    });
    if (admErr) {
      if (isRlsError(admErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: admErr.message }, { status: 400 });
    }
    const isAdmin = !!adm;

    const { data: chal, error: chalErr } = await supabase
      .from('challenges')
      .select('data_programada,reprogram_count')
      .eq('id', id)
      .maybeSingle();
    if (chalErr) {
      if (isRlsError(chalErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: chalErr.message }, { status: 400 });
    }
    if (!chal) return json({ ok: false, error: 'Repte no trobat' }, { status: 404 });

    const alreadyProgrammed = chal.data_programada && chal.data_programada !== data_iso;
    if (alreadyProgrammed && !isAdmin) {
      const count = chal.reprogram_count ?? 0;
      if (count >= 1) {
        return json(
          { ok: false, error: 'Només una reprogramació; contacta un administrador' },
          { status: 403 }
        );
      }
    }

    const updates: any = { data_programada: data_iso, estat: 'programat' };
    if (alreadyProgrammed) {
      updates.reprogram_count = (chal.reprogram_count ?? 0) + 1;
    }

    const { error: upErr } = await supabase.from('challenges').update(updates).eq('id', id);
    if (upErr) {
      if (isRlsError(upErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: upErr.message }, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

