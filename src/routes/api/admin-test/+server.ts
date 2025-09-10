// src/routes/api/admin-test/+server.ts
import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';

export const GET: RequestHandler = async ({ request }) => {
  try {
    const supabase = serverSupabase(request); // passa Authorization cap a Supabase
    const { data: session, error: sErr } = await supabase.auth.getUser();
    const who = session?.user?.email ?? null;
    const { data, error } = await supabase
      .from('admins')
      .select('email')
      .maybeSingle();
    return json({
      who,
      admin_row: data ?? null,
      error: error?.message ?? null
    });
  } catch (e: any) {
    return json({ who: null, admin_row: null, error: e?.message ?? 'error' }, { status: 500 });
  }
};
