import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { requireAdmin } from '$lib/server/adminGuard';
import { createClient } from '@supabase/supabase-js';

export const PATCH: RequestHandler = async (event) => {
  try {
    let body: { id?: string; direction?: 'up' | 'down' } | null = null;
    try {
      body = await event.request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const id = body?.id;
    const direction = body?.direction;
    if (!id || (direction !== 'up' && direction !== 'down')) {
      return json({ ok: false, error: 'Falten camps' }, { status: 400 });
    }

    await requireAdmin(event);

    const token =
      event.cookies.get('sb-access-token') ??
      event.request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ??
      '';
    const supabase = createClient(
      import.meta.env.PUBLIC_SUPABASE_URL,
      import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
      { global: { headers: { Authorization: `Bearer ${token}` } } }
    );

    const { data: row, error: rErr } = await supabase
      .from('waiting_list')
      .select('id, event_id, ordre')
      .eq('id', id)
      .maybeSingle();
    if (rErr) {
      return json({ ok: false, error: 'Error obtenint fila' }, { status: 400 });
    }
    if (!row) {
      return json({ ok: false, error: 'Entrada no trobada' }, { status: 404 });
    }

    const current = row.ordre as number;
    const target = direction === 'up' ? current - 1 : current + 1;
    if (target < 1) {
      return json({ ok: true });
    }

    const { data: neighbor, error: nErr } = await supabase
      .from('waiting_list')
      .select('id, ordre')
      .eq('event_id', row.event_id)
      .eq('ordre', target)
      .maybeSingle();
    if (nErr) {
      return json({ ok: false, error: 'Error obtenint veí' }, { status: 400 });
    }
    if (!neighbor) {
      return json({ ok: true });
    }

    const { error: up1 } = await supabase
      .from('waiting_list')
      .update({ ordre: current })
      .eq('id', neighbor.id);
    if (up1) {
      return json({ ok: false, error: 'Error actualitzant ordre' }, { status: 400 });
    }

    const { error: up2 } = await supabase
      .from('waiting_list')
      .update({ ordre: target })
      .eq('id', row.id);
    if (up2) {
      return json({ ok: false, error: 'Error actualitzant ordre' }, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

