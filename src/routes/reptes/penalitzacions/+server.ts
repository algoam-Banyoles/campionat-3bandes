import { json } from '@sveltejs/kit';
import { serverSupabase, requireAdmin } from '$lib/server/adminGuard';

export async function POST(event) {
  const guard = await requireAdmin(event);
  if (guard) return guard; // 401/403/500

  const supabase = serverSupabase(event);
  let payload: { challenge_id?: string; tipus?: 'incompareixenca' | 'desacord_dates' };
  try {
    payload = await event.request.json();
  } catch {
    return new Response(JSON.stringify({ error: 'JSON invàlid' }), { status: 400 });
  }
  const { challenge_id, tipus } = payload;
  if (!challenge_id || !tipus) {
    return new Response(JSON.stringify({ error: 'Falten camps: challenge_id, tipus' }), { status: 400 });
  }
  const { data, error } = await supabase.rpc('apply_challenge_penalty', {
    p_challenge: challenge_id,
    p_tipus: tipus
  });
  if (error) {
    return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
  }
  return json({ ok: true, ...(data ?? {}) });
}

