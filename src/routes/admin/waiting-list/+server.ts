import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { requireAdmin, serverSupabase } from '$lib/server/adminGuard';

export const GET: RequestHandler = async (event) => {
  try {
    const guard = await requireAdmin(event);
    if (guard) return guard; // 401/403/500

    const supabase = serverSupabase(event);
    const { data: eventRow, error: eErr } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .limit(1)
      .maybeSingle();
    if (eErr) {
      return json({ ok: false, error: 'Error obtenint event actiu' }, { status: 400 });
    }
    if (!eventRow) {
      return json({ ok: false, error: 'No hi ha cap event actiu' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('waiting_list')
      .select('id, soci_numero, ordre, data_inscripcio, socis!waiting_list_soci_numero_fkey(nom, cognoms)')
      .eq('event_id', eventRow.id)
      .order('ordre', { ascending: true });
    if (error) {
      return json({ ok: false, error: "Error obtenint llista d'espera" }, { status: 400 });
    }

    const rows = (data ?? []).map((r: any) => {
      const soci = Array.isArray(r.socis) ? r.socis[0] : r.socis;
      const nom = soci ? `${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim() : '';
      return {
        id: r.id,
        soci_numero: r.soci_numero,
        nom,
        ordre: r.ordre,
        data_inscripcio: r.data_inscripcio
      };
    });

    return json({ rows });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

export const POST: RequestHandler = async (event) => {
  try {
    let body: { soci_numero?: number; ordre?: number } | null = null;
    try {
      body = await event.request.json();
    } catch {
      return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
    }

    const soci_numero = body?.soci_numero;
    let ordre = body?.ordre;
    if (!soci_numero) {
      return json({ ok: false, error: 'Falta soci_numero' }, { status: 400 });
    }

    const guard = await requireAdmin(event);
    if (guard) return guard; // 401/403/500

    const supabase = serverSupabase(event);
    const { data: eventRow, error: eErr } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .limit(1)
      .maybeSingle();
    if (eErr) {
      return json({ ok: false, error: 'Error obtenint event actiu' }, { status: 400 });
    }
    if (!eventRow) {
      return json({ ok: false, error: 'No hi ha cap event actiu' }, { status: 400 });
    }

    const { data: rp, error: rpErr } = await supabase
      .from('ranking_positions')
      .select('id')
      .eq('event_id', eventRow.id)
      .eq('soci_numero', soci_numero)
      .maybeSingle();
    if (rpErr) {
      return json({ ok: false, error: 'Error verificant ranquing' }, { status: 400 });
    }
    if (rp) {
      return json({ ok: false, error: 'Jugador ja inscrit' }, { status: 400 });
    }

    const { data: wl, error: wlErr } = await supabase
      .from('waiting_list')
      .select('id')
      .eq('event_id', eventRow.id)
      .eq('soci_numero', soci_numero)
      .maybeSingle();
    if (wlErr) {
      return json({ ok: false, error: "Error verificant llista d'espera" }, { status: 400 });
    }
    if (wl) {
      return json({ ok: false, error: "Jugador ja en llista d'espera" }, { status: 400 });
    }

    if (ordre == null) {
      const { data: maxRow, error: mErr } = await supabase
        .from('waiting_list')
        .select('ordre')
        .eq('event_id', eventRow.id)
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
      .insert({ event_id: eventRow.id, soci_numero, ordre });
    if (insErr) {
      return json({ ok: false, error: "No s'ha pogut afegir" }, { status: 400 });
    }

    return json({ ok: true });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

