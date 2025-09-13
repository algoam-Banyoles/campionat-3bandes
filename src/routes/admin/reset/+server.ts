import { json } from '@sveltejs/kit';
import { serverSupabase, requireAdmin } from '$lib/server/adminGuard';

export function GET() {
  return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
}

export async function POST(event) {
  const guard = await requireAdmin(event);
  if (guard) return guard; // 401/403/500

  const supabase = serverSupabase(event);
  const { data, error } = await supabase.rpc('reset_full_competition');
  if (error) {
    return json(
      { error: "No s'ha pogut reiniciar el campionat" },
      { status: 500 }
    );
  }
  return json(data ?? {}, { status: 200 });
}

