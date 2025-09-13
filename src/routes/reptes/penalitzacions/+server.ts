import { json } from '@sveltejs/kit';
import { serverSupabase, requireAdmin } from '$lib/server/adminGuard';

const PENALTY_TYPES = ['incompareixenca', 'desacord_dates'] as const;

export function GET() {
  return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
}

export async function POST(event) {
  const guard = await requireAdmin(event);
  if (guard) return guard; // 401/403/500

  const supabase = serverSupabase(event);
  let payload: { challenge_id?: string; tipus?: string };
  try {
    payload = await event.request.json();
  } catch {
    return json({ error: 'JSON invàlid' }, { status: 400 });
  }
  const { challenge_id, tipus } = payload;
  if (!challenge_id || !tipus) {
    return json({ error: 'Falten camps: challenge_id, tipus' }, { status: 400 });
  }
  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!UUID_RE.test(challenge_id)) {
    return json({ error: 'challenge_id invàlid' }, { status: 400 });
  }
  if (!PENALTY_TYPES.includes(tipus as any)) {
    return json({ error: 'Tipus no suportat' }, { status: 400 });
  }

  const { data: chal, error: chalErr } = await supabase
    .from('challenges')
    .select('id')
    .eq('id', challenge_id)
    .maybeSingle();
  if (chalErr) {
    if ((chalErr as any).code === '22P02') {
      return json({ error: 'challenge_id invàlid' }, { status: 400 });
    }
    return json({ error: "No s'ha pogut comprovar el repte" }, { status: 500 });
  }
  if (!chal) {
    return json({ error: 'Repte no trobat' }, { status: 404 });
  }

  const { data, error } = await supabase.rpc('apply_challenge_penalty', {
    p_challenge: challenge_id,
    p_tipus: tipus
  });
  if (error) {
    return json({ error: 'Error aplicant penalització' }, { status: 500 });
  }
  return json({ ok: true, ...(data ?? {}) });
}

