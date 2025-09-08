import type { LayoutLoad } from './$types';
import { supabase } from '$lib/supabaseClient';
import { ensureAdmin } from '$lib/guards/adminOnly';

export const ssr = false;
export const prerender = false;

export const load: LayoutLoad = async () => {
  await ensureAdmin(supabase);
  return {};
};
