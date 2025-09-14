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

    const { data: out, error: rpcErr } = await supabase.rpc('programar_repte', {
      p_challenge: id,
      p_data: data_iso,
      p_actor_email: auth.user.email
    });
    if (rpcErr) {
      if (isRlsError(rpcErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: rpcErr.message }, { status: 400 });
    }
    if (!out?.ok) {
      return json(out, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

