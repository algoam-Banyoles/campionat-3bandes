import { supabase } from '$lib/supabaseClient';
import { get } from 'svelte/store';
import { user } from '$lib/authStore';

export async function isAdmin(): Promise<boolean> {
  const u = get(user);
  if (!u?.email) return false;
  const { data, error } = await supabase
    .from('admins')
    .select('email')
    .eq('email', u.email)
    .limit(1)
    .maybeSingle();

  if (error) {
    console.error('isAdmin error', error);
    return false;
  }
  return !!data;
}
