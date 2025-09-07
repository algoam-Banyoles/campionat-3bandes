import { writable } from 'svelte/store';
import type { Session, User } from '@supabase/supabase-js';
import { supabase } from '$lib/supabaseClient';

export const session = writable<Session | null>(null);
export const user = writable<User | null>(null);
export const loadingAuth = writable(true);

async function init() {
  const { data } = await supabase.auth.getSession();
  session.set(data.session ?? null);
  user.set(data.session?.user ?? null);
  loadingAuth.set(false);

  supabase.auth.onAuthStateChange((_event, sess) => {
    session.set(sess ?? null);
    user.set(sess?.user ?? null);
  });
}
init();
