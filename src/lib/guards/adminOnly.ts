import type { SupabaseClient } from '@supabase/supabase-js';
import { error } from '@sveltejs/kit';

export async function ensureAdmin(supabase: SupabaseClient): Promise<void> {
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  const email = userData.user?.email ?? null;
  if (userErr || !email) {
    throw error(403, 'Només admins');
  }

  const { data, error: adminErr } = await supabase
    .from('admins')
    .select('email')
    .eq('email', email)
    .limit(1)
    .maybeSingle();

  if (adminErr || !data) {
    throw error(403, 'Només admins');
  }
}
