export type AppSettings = {
  caramboles_objectiu: number;
  max_entrades: number;
  allow_tiebreak: boolean;
  cooldown_min_dies: number;
  cooldown_max_dies: number;
  dies_acceptar_repte: number;
  dies_jugar_despres_acceptar: number;
  ranking_max_jugadors: number;
  pre_inactiu_setmanes: number;
  inactiu_setmanes: number;
  updated_at?: string;
  id?: string;
};

export const REPROGRAMACIONS_LIMIT = 3;

const DEFAULT_SETTINGS: AppSettings = {
  caramboles_objectiu: 20,
  max_entrades: 50,
  allow_tiebreak: true,
  cooldown_min_dies: 3,
  cooldown_max_dies: 7,
  dies_acceptar_repte: 7,
  dies_jugar_despres_acceptar: 7,
  ranking_max_jugadors: 20,
  pre_inactiu_setmanes: 3,
  inactiu_setmanes: 6
};

let cache: AppSettings | null = null;

export async function getSettings(): Promise<AppSettings> {
  if (cache) return cache;
  try {
    const { supabase } = await import('$lib/supabaseClient');
    const { data, error } = await supabase
      .from('app_settings')
      .select('*')
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    cache = { ...DEFAULT_SETTINGS, ...(data ?? {}) };
  } catch {
    cache = DEFAULT_SETTINGS;
  }
  return cache as AppSettings;
}

export function invalidate() {
  cache = null;
}

export async function adminUpdateSettings(
  diesAcceptar: number,
  diesJugar: number,
  preInact: number,
  inact: number
) {
  const { supabase } = await import('$lib/supabaseClient');
  const { error } = await supabase.rpc('admin_update_settings', {
    diesAcceptar,
    diesJugar,
    preInact,
    inact
  });
  if (error) throw error;
  invalidate();
}

