import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

// This endpoint checks for expired challenges and applies penalties
export const POST: RequestHandler = async ({ request }) => {
  try {
    const supabase = serverSupabase(request);
    // Get app settings for deadlines
    const { data: settings, error: sErr } = await supabase
      .from('app_settings')
      .select('dies_acceptar_repte, dies_jugar_despres_acceptar')
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (sErr || !settings) {
      return json({ ok: false, error: 'No settings found' }, { status: 500 });
    }
    const acceptDays = settings.dies_acceptar_repte ?? 3;
    const playDays = settings.dies_jugar_despres_acceptar ?? 7;
    // Find challenges past acceptance deadline
    const { data: expiredAccept, error: eAcc } = await supabase
      .from('challenges')
      .select('id, data_proposta, estat')
      .eq('estat', 'proposat')
      .lt('data_proposta', new Date(Date.now() - acceptDays * 86400000).toISOString());
    // Find challenges past play deadline
    const { data: expiredPlay, error: ePlay } = await supabase
      .from('challenges')
      .select('id, data_programada, estat')
      .in('estat', ['acceptat', 'programat'])
      .lt('data_programada', new Date(Date.now() - playDays * 86400000).toISOString());
    let penalized: string[] = [];
    // Apply penalty for expired acceptance
    for (const ch of expiredAccept ?? []) {
      const { data: res } = await supabase.rpc('apply_challenge_penalty', {
        p_challenge: ch.id,
        p_tipus: 'no_accept'
      });
      penalized.push(ch.id);
    }
    // Apply penalty for expired play
    for (const ch of expiredPlay ?? []) {
      const { data: res } = await supabase.rpc('apply_challenge_penalty', {
        p_challenge: ch.id,
        p_tipus: 'no_play'
      });
      penalized.push(ch.id);
    }
    return json({ ok: true, penalized }, { status: 200 });
  } catch (e: any) {
    return json({ ok: false, error: e?.message ?? 'Error intern' }, { status: 500 });
  }
};
