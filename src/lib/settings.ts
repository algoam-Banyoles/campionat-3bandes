// src/lib/settings.ts
import { supabase } from '$lib/supabaseClient';

export type AppSettings = {
  id?: string;
  caramboles_objectiu: number;
  max_entrades: number;
  allow_tiebreak: boolean;
  cooldown_min_dies: number;
  cooldown_max_dies: number;
  dies_acceptar_repte: number;
  dies_jugar_despres_acceptar: number;
  ranking_max_jugadors: number;
  updated_at?: string;
};

const DEFAULTS: AppSettings = {
  caramboles_objectiu: 20,
  max_entrades: 50,
  allow_tiebreak: true,
  cooldown_min_dies: 3,
  cooldown_max_dies: 7,
  dies_acceptar_repte: 7,
  dies_jugar_despres_acceptar: 7,
  ranking_max_jugadors: 20
};

let _cache: { value: AppSettings; ts: number } | null = null;

export async function getSettings(force = false): Promise<AppSettings> {
  if (!force && _cache && Date.now() - _cache.ts < 60_000) return _cache.value;
  const { data, error } = await supabase
    .from('app_settings')
    .select('id,caramboles_objectiu,max_entrades,allow_tiebreak,cooldown_min_dies,cooldown_max_dies,dies_acceptar_repte,dies_jugar_despres_acceptar,ranking_max_jugadors,updated_at')
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  const value = error ? DEFAULTS : (data ?? DEFAULTS);
  _cache = { value, ts: Date.now() };
  return value;
}

export function invalidateSettingsCache() {
  _cache = null;
}
