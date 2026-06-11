import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

const DAY_MS = 86_400_000;
const DEFAULT_ACCEPT_DAYS = 7;
const DEFAULT_PLAY_DAYS = 7;

// Aquest endpoint revisa reptes fora de termini i aplica la sanció corresponent.
// Requereix la capçalera 'x-cron-secret' amb el valor de la variable CRON_SECRET.
export const POST: RequestHandler = async ({ request }) => {
  // ── Autenticació per secret compartit ──────────────────────────────────────
  const cronSecret = process.env.CRON_SECRET;
  if (!cronSecret) {
    console.error('[check-expired] CRON_SECRET no està configurat al servidor.');
    return json({ ok: false, error: 'Configuració del servidor incorrecta' }, { status: 500 });
  }

  const incomingSecret = request.headers.get('x-cron-secret');
  if (!incomingSecret || incomingSecret !== cronSecret) {
    return json({ ok: false, error: 'No autoritzat' }, { status: 401 });
  }

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

    // Deadline per acceptar: reptes en estat 'proposat' amb data_proposta antiga
    const acceptDeadline = new Date(Date.now() - acceptDays * DAY_MS).toISOString();

    // Deadline per jugar: reptes en estat 'acceptat' o 'programat' amb
    // data_acceptacio antiga. Usem data_acceptacio perquè:
    //   - 'acceptat': data_programada és NULL (el jugador no ha proposat data),
    //     de manera que la comparació contra data_programada mai donaria resultats.
    //   - 'programat': el termini ha de comptar des de l'acceptació, no des de
    //     la data de la partida (que podria estar força en el futur però igualment
    //     caducada si l'acceptació va ser fa massa temps).
    const playDeadlineISO = new Date(Date.now() - playDays * DAY_MS).toISOString();

    // ── Reptes sense acceptar ──────────────────────────────────────────────
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

    // ── Reptes acceptats/programats però no jugats dins el termini ─────────
    const { data: expiredPlay, error: playError } = await supabase
      .from('challenges')
      .select('id')
      .in('estat', ['acceptat', 'programat'])
      .lt('data_acceptacio', playDeadlineISO);

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
