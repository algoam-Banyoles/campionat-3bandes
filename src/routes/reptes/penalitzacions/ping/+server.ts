import type { RequestHandler } from './$types';
import { json } from '@sveltejs/kit';
import { serverSupabase } from '$lib/server/supabaseAdmin';
import { getSupabaseEnv } from '$lib/server/env';

export const GET: RequestHandler = async () => {
  const notes: string[] = [];
  let env_ok = true;
  let can_select_admins = false;

  try {
    const { url, key } = getSupabaseEnv();
    if (!url || !key) env_ok = false;
  } catch (e:any) {
    env_ok = false;
    notes.push(e?.message ?? 'No .env / PUBLIC_ variables');
  }

  try {
    const supabase = serverSupabase();
    const { error } = await supabase.from('admins').select('email', { count: 'exact', head: true }).limit(1);
    if (!error) can_select_admins = true;
    else notes.push(`admins select error: ${error.message}`);
  } catch (e:any) {
    notes.push(`admins select exception: ${e?.message ?? e}`);
  }

  return json({ env_ok, can_select_admins, notes });
};
