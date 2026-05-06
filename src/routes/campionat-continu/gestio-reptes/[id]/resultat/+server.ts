import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { requireAdmin, serverSupabase } from '$lib/server/adminGuard';

function isInt(v: any): boolean {
  return typeof v === 'number' && Number.isInteger(v);
}

export const POST: RequestHandler = async (event) => {
  const guard = await requireAdmin(event);
  if (guard) return guard;

  let body: any = null;
  try {
    body = await event.request.json();
  } catch {
    return json({ ok: false, error: 'Cos JSON requerit' }, { status: 400 });
  }

  const id = event.params.id;
  const {
    data_iso,
    carR,
    carT,
    entrades,
    serieR,
    serieT,
    tbR,
    tbT,
    tipusResultat,
  } = body ?? {};

  if (!data_iso || typeof data_iso !== 'string') {
    return json({ ok: false, error: 'Falta data_iso' }, { status: 400 });
  }
  const d = new Date(data_iso);
  if (isNaN(d.getTime()) || d.toISOString() !== data_iso) {
    return json({ ok: false, error: 'Data invàlida' }, { status: 400 });
  }

  if (tipusResultat !== 'normal' && tipusResultat !== 'walkover_reptador' && tipusResultat !== 'walkover_reptat') {
    return json({ ok: false, error: 'tipusResultat invàlid' }, { status: 400 });
  }

  const supabase = serverSupabase(event);

  const { data: cfg } = await supabase
    .from('app_settings')
    .select('caramboles_objectiu,max_entrades,allow_tiebreak')
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  const settings = cfg ?? { caramboles_objectiu: 20, max_entrades: 50, allow_tiebreak: true };

  if (tipusResultat === 'normal') {
    if (!isInt(carR) || carR < 0) return json({ ok: false, error: 'Caràmboles reptador invàlid' }, { status: 400 });
    if (!isInt(carT) || carT < 0) return json({ ok: false, error: 'Caràmboles reptat invàlid' }, { status: 400 });
    if (!isInt(entrades) || entrades < 0) return json({ ok: false, error: 'Entrades invàlides' }, { status: 400 });
    if (!isInt(serieR) || serieR < 0) return json({ ok: false, error: 'Sèrie màxima reptador invàlida' }, { status: 400 });
    if (!isInt(serieT) || serieT < 0) return json({ ok: false, error: 'Sèrie màxima reptat invàlida' }, { status: 400 });
    if (serieR > carR) return json({ ok: false, error: 'Sèrie màxima reptador no pot superar caràmboles' }, { status: 400 });
    if (serieT > carT) return json({ ok: false, error: 'Sèrie màxima reptat no pot superar caràmboles' }, { status: 400 });
    if (carR > settings.caramboles_objectiu || carT > settings.caramboles_objectiu)
      return json({ ok: false, error: `Caràmboles màximes: ${settings.caramboles_objectiu}.` }, { status: 400 });
    if (entrades > settings.max_entrades)
      return json({ ok: false, error: `Entrades màximes: ${settings.max_entrades}.` }, { status: 400 });

    const isTie = carR === carT;
    if (isTie) {
      if (!settings.allow_tiebreak)
        return json({ ok: false, error: 'Empat de caràmboles i el tie-break està desactivat a Configuració.' }, { status: 400 });
      if (!isInt(tbR) || !isInt(tbT))
        return json({ ok: false, error: 'Resultat de tie-break ha de ser enter.' }, { status: 400 });
      if (tbR < 0 || tbT < 0)
        return json({ ok: false, error: 'Els resultats del tie-break no poden ser negatius.' }, { status: 400 });
      if (tbR === tbT)
        return json({ ok: false, error: 'El tie-break no pot acabar en empat.' }, { status: 400 });
    }
  }

  let resultat: string;
  if (tipusResultat === 'normal') {
    if (carR === carT) {
      resultat = tbR > tbT ? 'empat_tiebreak_reptador' : 'empat_tiebreak_reptat';
    } else {
      resultat = carR > carT ? 'guanya_reptador' : 'guanya_reptat';
    }
  } else {
    resultat = tipusResultat;
  }

  const isWalkover = tipusResultat !== 'normal';
  const hasTB = tipusResultat === 'normal' && carR === carT;

  const insertRow: any = {
    challenge_id: id,
    data_joc: data_iso,
    caramboles_reptador: isWalkover ? 0 : carR,
    caramboles_reptat: isWalkover ? 0 : carT,
    entrades: isWalkover ? 0 : entrades,
    serie_max_reptador: isWalkover ? 0 : serieR,
    serie_max_reptat: isWalkover ? 0 : serieT,
    resultat,
    tiebreak: hasTB,
    tiebreak_reptador: hasTB ? tbR : null,
    tiebreak_reptat: hasTB ? tbT : null
  };

  const { error: e1 } = await supabase
    .from('matches')
    .insert(insertRow)
    .select('id')
    .single();
  if (e1) return json({ ok: false, error: e1.message }, { status: 400 });

  const { error: e2 } = await supabase
    .from('challenges')
    .update({ estat: 'jugat' })
    .eq('id', id);
  if (e2) return json({ ok: false, error: e2.message }, { status: 400 });

  const { data: d3, error: e3 } = await supabase.rpc('apply_match_result', { p_challenge: id });
  let rpcMsg: string | null = null;
  if (e3) {
    rpcMsg = `Rànquing NO actualitzat (RPC): ${e3.message}`;
  } else {
    const r = Array.isArray(d3) && d3[0] ? d3[0] : null;
    if (r?.swapped) rpcMsg = 'Rànquing actualitzat: intercanvi de posicions fet.';
    else rpcMsg = `Rànquing sense canvis${r?.reason ? ' (' + r.reason + ')' : ''}.`;
  }

  return json({ ok: true, rpcMsg });
};

