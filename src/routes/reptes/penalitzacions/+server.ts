// src/routes/reptes/penalitzacions/+server.ts
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';
import { getSupabaseEnv } from '$lib/server/env';

type PenalitzacioPayload = {
  event_id: string;
  player_id: string;
  tipus: string;   // 'incompareixenca' | 'no_acord_dates' | ...
  detalls?: string | null;

};

function mkRls403() {
  return json({ ok: false, error: 'Només administradors poden crear penalitzacions' }, { status: 403 });
}

export const GET: RequestHandler = async () => {
  const notes: string[] = [];
  let env_ok = true;
  let can_select_admins = false;

  try {
    // Només comprovem existència, no revel·lem claus
    const { url, key } = getSupabaseEnv();
    if (!url || !key) env_ok = false;
  } catch (e:any) {
    env_ok = false;
    notes.push(e?.message ?? 'No .env / PUBLIC_ variables');
  }

  try {
    const supabase = serverSupabase();
    const { error } = await supabase.from('admins').select('email', { count: 'exact', head: true }).limit(1);
    if (!error) can_select_admins = true;
    else notes.push(`admins select error: ${error.message}`);
  } catch (e:any) {
    notes.push(`admins select exception: ${e?.message ?? e}`);
  }

  return json({ env_ok, can_select_admins, notes });
};

export const POST: RequestHandler = async ({ request }) => {
  try {
    const body = (await request.json()) as PenalitzacioPayload;
    if (!body?.event_id || !body?.player_id || !body?.tipus) {
      return json({ ok: false, error: 'Falten camps obligatoris (event_id, player_id, tipus)' }, { status: 400 });
    }

    const supabase = serverSupabase();
    const { error } = await supabase.from('penalties').insert({
      event_id: body.event_id,
      player_id: body.player_id,
      tipus: body.tipus,
      detalls: body.detalls ?? null
    });

    if (error) {
      const msg = String(error.message || '').toLowerCase();
      if (msg.includes('row-level security') || msg.includes('permission') || msg.includes('policy')) {
        return mkRls403();
      }
      const code = (error as any).code;
      const detail = (error as any).details || (error as any).detail;
      if (code === '42P01' || code === '42703') {
        return json({ ok: false, error: 'Configuració de taula/columnes', code, detail }, { status: 500 });
      }
      if (code === '23503' || code === '23505') {
        return json({ ok: false, error: 'Validació de dades', code, detail }, { status: 400 });
      }
      return json({ ok: false, error: error.message, code, detail, hint: (error as any).hint }, { status: 500 });
    }

    return json({ ok: true }, { status: 201 });
  } catch (e:any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

