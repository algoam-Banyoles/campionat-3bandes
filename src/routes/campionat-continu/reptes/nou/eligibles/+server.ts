import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

function isRlsError(e: any): boolean {
  const msg = String(e?.message || '').toLowerCase();
  return msg.includes('row level security') || msg.includes('permission') || msg.includes('policy');
}

export const GET: RequestHandler = async ({ request }) => {
  try {
    const supabase = serverSupabase(request);

    const { data: auth, error: authErr } = await supabase.auth.getUser();
    if (authErr || !auth?.user?.email) {
      return json({ ok: false, error: 'Sessió invàlida' }, { status: 400 });
    }

    const { data: player, error: pErr } = await supabase
      .from('players')
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
    const myPlayerId = player.id as string;

    const { data: event, error: eErr } = await supabase
      .from('events')
      .select('id, nom')
      .eq('actiu', true)
      .eq('tipus_competicio', 'ranking_continu')
      .order('creat_el', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (eErr && eErr.code !== 'PGRST116') {
      if (isRlsError(eErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: eErr.message }, { status: 400 });
    }
    if (!event) {
      return json({ ok: false, error: 'No hi ha cap esdeveniment actiu de ranking continu' }, { status: 400 });
    }
    const eventId = event.id as string;

    console.log('🎯 Esdeveniment actiu:', { id: eventId, nom: (event as any).nom });

    // Usar la mateixa consulta que rankingStore per consistència
    const { data: rank, error: rErr } = await supabase
      .from('ranking_positions')
      .select(`
        posicio,
        player_id,
        players!inner (
          numero_soci
        )
      `)
      .eq('event_id', eventId)
      .order('posicio', { ascending: true });
    
    console.log('📊 Consulta rànquing:', { eventId, error: rErr, resultsCount: rank?.length ?? 0 });
    
    if (rErr) {
      if (isRlsError(rErr)) return json({ ok: false, error: 'Permisos insuficients' }, { status: 403 });
      return json({ ok: false, error: rErr.message }, { status: 400 });
    }

    // Obtenir noms dels socis en una query separada
    const numerosSoci = [...new Set(
      (rank ?? [])
        .map((item: any) => item.players?.numero_soci)
        .filter((n: any) => n != null)
    )];

    let socisMap = new Map<number, string>();
    if (numerosSoci.length > 0) {
      const { data: socisData, error: socisError } = await supabase
        .from('socis')
        .select('numero_soci, nom')
        .in('numero_soci', numerosSoci);

      if (!socisError && socisData) {
        socisData.forEach((soci: any) => {
          socisMap.set(soci.numero_soci, soci.nom);
        });
      }
    }
    const allRank = (rank ?? []).map((r: any) => {
      const numeroSoci = r.players?.numero_soci;
      const nom = numeroSoci ? socisMap.get(numeroSoci) : null;
      return {
        posicio: r.posicio,
        player_id: r.player_id,
        nom: nom ?? '—'
      };
    });

    // Debug: mostrar informació
    console.log('🔍 Debug rànquing:');
    console.log('  - myPlayerId:', myPlayerId);
    console.log('  - Total jugadors al rànquing:', allRank.length);
    console.log('  - IDs al rànquing:', allRank.map(r => r.player_id));

    const mine = allRank.find((r) => r.player_id === myPlayerId) ?? null;
    if (!mine) {
      console.error('❌ No trobat al rànquing!');
      console.error('  - Buscant:', myPlayerId, '(tipus:', typeof myPlayerId, ')');
      console.error('  - Primer ID del rànquing:', allRank[0]?.player_id, '(tipus:', typeof allRank[0]?.player_id, ')');
      return json({ 
        ok: false, 
        error: `No formes part del rànquing actual. (ID: ${myPlayerId})`,
        debug: {
          myPlayerId,
          rankingIds: allRank.map(r => r.player_id),
          totalInRanking: allRank.length
        }
      }, { status: 400 });
    }
    console.log('✅ Trobat al rànquing! Posició:', mine.posicio);
    const myPos = mine.posicio as number;

    const reptables: { posicio: number; player_id: string; nom: string }[] = [];
    const noReptables: { posicio: number; player_id: string; nom: string; motiu: string }[] = [];

    for (const r of allRank) {
      if (r.player_id === myPlayerId) continue;
      const { data: chk, error: eChk } = await supabase.rpc('can_create_challenge', {
        p_event: eventId,
        p_reptador: myPlayerId,
        p_reptat: r.player_id
      });
      if (eChk) {
        noReptables.push({ ...r, motiu: 'no disponible' });
        continue;
      }
      const res = (chk as any)?.[0];
      if (res?.ok) {
        reptables.push(r);
      } else {
        let motiu = res?.reason ?? 'no disponible';
        const lower = motiu.toLowerCase();
        if (lower.includes('repte actiu')) motiu = 'té un repte actiu';
        else if (lower.includes('temps mínim')) motiu = 'cooldown no complert';
        else if (lower.includes('diferència de posicions')) motiu = 'fora del marge de posicions';
        noReptables.push({ ...r, motiu });
      }
    }

    return json(
      {
        ok: true,
        my_player_id: myPlayerId,
        my_pos: myPos,
        event_id: eventId,
        reptables,
        no_reptables: noReptables
      },
      { status: 200 }
    );
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};

