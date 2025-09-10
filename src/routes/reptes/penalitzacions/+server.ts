import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';
import { getSupabaseEnv } from '$lib/server/env';

type PenalitzacioPayload = {
  event_id: string;
  player_id: string;
  tipus: string; // ex: 'incompareixenca' | 'no_acord_dates' | ...
  detalls?: string;
};

export const GET: RequestHandler = async () => {
  const notes: string[] = [];
  let env_ok = false;
  let can_select_admins = false;

  try {
    getSupabaseEnv();
    env_ok = true;
  } catch (e: any) {
    notes.push(e?.message ?? 'Falta configuració de Supabase');
  }

  if (env_ok) {
    try {
      const supabase = serverSupabase();
      const { error } = await supabase.from('admins').select('1').limit(1);
      if (!error) {
        can_select_admins = true;
      } else {
        const msg = String(error.message || '').toLowerCase();
        if (
          msg.includes('permission') ||
          msg.includes('policy') ||
          msg.includes('row-level security')
        ) {
          notes.push('RLS/permission denied a admins');
        } else if (error.code === '42P01') {
          notes.push('taula admins no existeix');
        } else {
          notes.push(error.message);
        }
      }
    } catch (e: any) {
      notes.push(e?.message ?? 'Error consultant admins');
    }
  }

  return json({ env_ok, can_select_admins, notes });
};

export const POST: RequestHandler = async ({ request }) => {
  let body: PenalitzacioPayload;
  try {
    body = (await request.json()) as PenalitzacioPayload;
  } catch {
    return json({ ok: false, error: 'JSON invàlid' }, { status: 400 });
  }

  if (!body.event_id || !body.player_id || !body.tipus) {
    return json({ ok: false, error: 'Falten camps obligatoris' }, { status: 400 });
  }

  try {
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
        return json(
          { ok: false, error: 'Només administradors poden crear penalitzacions' },
          { status: 403 }
        );
      }

      const code = error.code;
      if (code === '42P01' || code === '42703') {
        return json(
          { ok: false, error: error.message, code, detail: error.details ?? error.hint ?? null },
          { status: 500 }
        );
      }

      if (code === '23503' || code === '23505') {
        return json(
          { ok: false, error: error.details ?? error.message, code },
          { status: 400 }
        );
      }

      return json(
        { ok: false, error: error.message, code, hint: error.hint, detail: error.details },
        { status: 500 }
      );
    }

    return json({ ok: true }, { status: 201 });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

