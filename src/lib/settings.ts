export type AppSettings = {
  caramboles_objectiu: number;
  max_entrades: number;
  allow_tiebreak: boolean;
  cooldown_min_dies: number;
  cooldown_max_dies: number;
  dies_acceptar_repte: number;
  dies_jugar_despres_acceptar: number;
  ranking_max_jugadors: number;
  reprogramacions_limit: number;
  updated_at?: string;
  id?: string;
};

const DEFAULT_SETTINGS: AppSettings = {
  caramboles_objectiu: 20,
  max_entrades: 50,
  allow_tiebreak: true,
  cooldown_min_dies: 3,
  cooldown_max_dies: 7,
  dies_acceptar_repte: 7,
  dies_jugar_despres_acceptar: 7,
  ranking_max_jugadors: 20,
  reprogramacions_limit: 3
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
    cache = data ?? DEFAULT_SETTINGS;
  } catch {
    cache = DEFAULT_SETTINGS;
  }
    return cache as AppSettings;
}

export function invalidate() {
  cache = null;
}

