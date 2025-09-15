import type { PageLoad } from './$types';
import { supabase } from '$lib/supabaseClient';

export const ssr = false;
export const prerender = false;

export const load: PageLoad = async () => {
  const { data, error } = await supabase
    .from('app_settings')
    .select(
      'id, caramboles_objectiu, max_entrades, allow_tiebreak, cooldown_min_dies, cooldown_max_dies, dies_acceptar_repte, dies_jugar_despres_acceptar, ranking_max_jugadors, pre_inactiu_setmanes, inactiu_setmanes, updated_at'
    )
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  return {
    settings: data ?? null,
    loadError: error?.message ?? null
  };
};
