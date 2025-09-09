import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL } from '$env/static/public';
import { SUPABASE_SERVICE_ROLE_KEY } from '$env/static/private';

function cutoffDate() {
  return new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
}

async function swapPositions(supabase: any, c: any, motiuWin: string, motiuLose: string) {
  await supabase
    .from('ranking_positions')
    .update({ posicio: c.pos_reptat })
    .eq('event_id', c.event_id)
    .eq('player_id', c.reptador_id);

  await supabase
    .from('ranking_positions')
    .update({ posicio: c.pos_reptador })
    .eq('event_id', c.event_id)
    .eq('player_id', c.reptat_id);

  await supabase.from('history_position_changes').insert([
    {
      event_id: c.event_id,
      player_id: c.reptador_id,
      posicio_anterior: c.pos_reptador,
      posicio_nova: c.pos_reptat,
      motiu: motiuWin,
      ref_challenge: c.id
    },
    {
      event_id: c.event_id,
      player_id: c.reptat_id,
      posicio_anterior: c.pos_reptat,
      posicio_nova: c.pos_reptador,
      motiu: motiuLose,
      ref_challenge: c.id
    }
  ]);
}

async function dropOnePosition(
  supabase: any,
  eventId: string,
  playerId: string,
  current: number,
  challengeId: string
) {
  const newPos = current + 1;
  const { data: other } = await supabase
    .from('ranking_positions')
    .select('player_id')
    .eq('event_id', eventId)
    .eq('posicio', newPos)
    .maybeSingle();

  if (other?.player_id) {
    await supabase
      .from('ranking_positions')
      .update({ posicio: current })
      .eq('event_id', eventId)
      .eq('player_id', other.player_id);
  }

  await supabase
    .from('ranking_positions')
    .update({ posicio: newPos })
    .eq('event_id', eventId)
    .eq('player_id', playerId);

  await supabase.from('history_position_changes').insert({
    event_id: eventId,
    player_id: playerId,
    posicio_anterior: current,
    posicio_nova: newPos,
    motiu: 'desacord en la data',
    ref_challenge: challengeId
  });
}

export const POST = async () => {
  const supabase = createClient(PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const cutoff = cutoffDate();

  // 1) Challenges proposats sense resposta
  const { data: props } = await supabase
    .from('challenges')
    .select('id,event_id,reptador_id,reptat_id,pos_reptador,pos_reptat')
    .eq('estat', 'proposat')
    .lte('data_proposta', cutoff);

  for (const c of props ?? []) {
    await supabase.from('challenges').update({ estat: 'anullat' }).eq('id', c.id);
    if (c.pos_reptador != null && c.pos_reptat != null) {
      await swapPositions(
        supabase,
        c,
        'victoria per incompareixença/refus',
        'derrota per incompareixença/refus'
      );
    }
  }

  // 2) Challenges acceptats sense programar
  const { data: accs } = await supabase
    .from('challenges')
    .select('id,event_id,reptador_id,reptat_id')
    .eq('estat', 'acceptat')
    .lte('data_acceptacio', cutoff);

  for (const c of accs ?? []) {
    await supabase.from('challenges').update({ estat: 'anullat' }).eq('id', c.id);

    const { data: ranking } = await supabase
      .from('ranking_positions')
      .select('player_id,posicio')
      .eq('event_id', c.event_id)
      .in('player_id', [c.reptador_id, c.reptat_id]);

    const posR = ranking?.find((r) => r.player_id === c.reptador_id)?.posicio;
    const posT = ranking?.find((r) => r.player_id === c.reptat_id)?.posicio;

    if (posR != null) await dropOnePosition(supabase, c.event_id, c.reptador_id, posR, c.id);
    if (posT != null) await dropOnePosition(supabase, c.event_id, c.reptat_id, posT, c.id);
  }

  return json({ processedProposats: props?.length ?? 0, processedAcceptats: accs?.length ?? 0 });
};
