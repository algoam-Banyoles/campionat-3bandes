// src/routes/reptes/penalitzacions/+server.ts
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '$env/static/private';

// Client Supabase per a ÚS DE SERVIDOR (no persisteix sessió)
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false }
});

type PenalitzacioPayload = {
  event_id: string;
  player_id: string;
  tipus: string;   // p.ex. 'incompareixenca' | 'no_acord_dates' | ...
  detalls?: string;
};

export const POST: RequestHandler = async ({ request }) => {
  try {
    const body = (await request.json()) as PenalitzacioPayload;

    // Validacions bàsiques
    if (!body?.event_id || !body?.player_id || !body?.tipus) {
      return json({ ok: false, error: 'Falten camps obligatoris' }, { status: 400 });
    }

    // Deixem que la RLS decideixi (si no és admin, fallarà)
    const { error } = await supabase.from('penalties').insert({
      event_id: body.event_id,
      player_id: body.player_id,
      tipus: body.tipus,
      detalls: body.detalls ?? null
    });

    if (error) {
      // Mapegem errors de RLS a 403 per claredat
      const msg = String(error.message || '').toLowerCase();
      if (msg.includes('row-level security') || msg.includes('permission') || msg.includes('policy')) {
        return json({ ok: false, error: 'Només administradors poden crear penalitzacions' }, { status: 403 });
      }
      throw error;
    }

    return json({ ok: true }, { status: 201 });
  } catch (e: any) {
    return json(
      { ok: false, error: e?.message ?? 'Error intern' },
      { status: 500 }
    );
  }
};
