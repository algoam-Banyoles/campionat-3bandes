import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

const DAY_MS = 86_400_000;
const DEFAULT_ACCEPT_DAYS = 7;
const DEFAULT_PLAY_DAYS = 7;

// Aquest endpoint revisa reptes fora de termini i aplica la sanció corresponent.
export const POST: RequestHandler = async ({ request }) => {
  try {
    const supabase = serverSupabase(request);

    const { data: config, error: settingsError } = await supabase
      .from('app_settings')
      .select('dies_acceptar_repte, dies_jugar_despres_acceptar')
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (settingsError) {
      return json(
        { ok: false, error: `Error consulta settings: ${settingsError.message}` },
        { status: 500 }
      );
    }

    const acceptDays = config?.dies_acceptar_repte ?? DEFAULT_ACCEPT_DAYS;
    const playDays = config?.dies_jugar_despres_acceptar ?? DEFAULT_PLAY_DAYS;

    const acceptDeadline = new Date(Date.now() - acceptDays * DAY_MS).toISOString();
    const playDeadline = new Date(Date.now() - playDays * DAY_MS).toISOString();

    const { data: expiredAccept, error: acceptError } = await supabase
      .from('challenges')
      .select('id')
      .eq('estat', 'proposat')
      .lt('data_proposta', acceptDeadline);

    if (acceptError) {
      return json(
        { ok: false, error: `Error cercant reptes sense acceptar: ${acceptError.message}` },
        { status: 500 }
      );
    }

    const { data: expiredPlay, error: playError } = await supabase
      .from('challenges')
      .select('id')
      .in('estat', ['acceptat', 'programat'])
      .lt('data_programada', playDeadline);

    if (playError) {
      return json(
        { ok: false, error: `Error cercant reptes sense jugar: ${playError.message}` },
        { status: 500 }
      );
    }

    const penalized: string[] = [];

    for (const ch of expiredAccept ?? []) {
      const { error: rpcError } = await supabase.rpc('apply_challenge_penalty', {
        p_challenge: ch.id,
        p_tipus: 'incompareixenca'
      });
      if (rpcError) {
        return json(
          { ok: false, error: `Error aplicant penalització per no acceptar: ${rpcError.message}` },
          { status: 500 }
        );
      }
      penalized.push(ch.id);
    }

    for (const ch of expiredPlay ?? []) {
      const { error: rpcError } = await supabase.rpc('apply_challenge_penalty', {
        p_challenge: ch.id,
        p_tipus: 'desacord_dates'
      });
      if (rpcError) {
        return json(
          { ok: false, error: `Error aplicant penalització per no jugar: ${rpcError.message}` },
          { status: 500 }
        );
      }
      penalized.push(ch.id);
    }

    return json({ ok: true, penalized }, { status: 200 });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};
