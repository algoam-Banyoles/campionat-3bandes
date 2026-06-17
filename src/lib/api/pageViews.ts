import { supabase } from '$lib/supabaseClient';

export interface PageViewTotals {
  total_views: number;
  unique_visitors: number;
  authed_views: number;
  anon_views: number;
}

export interface SectionStat {
  section: string;
  views: number;
  visitors: number;
  authed_views: number;
}

export interface DailyStat {
  day: string; // 'YYYY-MM-DD'
  views: number;
  visitors: number;
}

export interface TopPath {
  path: string;
  section: string;
  views: number;
  visitors: number;
}

interface RangeOpts {
  fromISO: string;
  toISO: string;
  includeAdmin: boolean;
}

/** Etiquetes en català per a cada secció derivada. */
export const SECTION_LABELS: Record<string, string> = {
  inici: 'Inici',
  general: 'General',
  'campionats-socials': 'Campionats socials',
  'campionat-continu': 'Rànquing continu',
  handicap: 'Hàndicap',
  admin: 'Administració',
  jugador: 'Perfils de jugador',
  altres: 'Altres'
};

export function sectionLabel(section: string): string {
  return SECTION_LABELS[section] ?? section;
}

export async function getPageViewTotals(opts: RangeOpts): Promise<PageViewTotals> {
  const { data, error } = await supabase.rpc('get_page_view_totals', {
    p_from: opts.fromISO,
    p_to: opts.toISO,
    p_include_admin: opts.includeAdmin
  });
  if (error) throw error;
  const row = (data ?? [])[0] as PageViewTotals | undefined;
  return (
    row ?? { total_views: 0, unique_visitors: 0, authed_views: 0, anon_views: 0 }
  );
}

export async function getSectionStats(opts: RangeOpts): Promise<SectionStat[]> {
  const { data, error } = await supabase.rpc('get_page_view_section_stats', {
    p_from: opts.fromISO,
    p_to: opts.toISO,
    p_include_admin: opts.includeAdmin
  });
  if (error) throw error;
  return (data ?? []) as SectionStat[];
}

export async function getDailyStats(opts: RangeOpts): Promise<DailyStat[]> {
  const { data, error } = await supabase.rpc('get_page_view_daily', {
    p_from: opts.fromISO,
    p_to: opts.toISO,
    p_include_admin: opts.includeAdmin
  });
  if (error) throw error;
  return (data ?? []) as DailyStat[];
}

export async function getTopPaths(
  opts: RangeOpts & { limit?: number }
): Promise<TopPath[]> {
  const { data, error } = await supabase.rpc('get_page_view_top_paths', {
    p_from: opts.fromISO,
    p_to: opts.toISO,
    p_include_admin: opts.includeAdmin,
    p_limit: opts.limit ?? 20
  });
  if (error) throw error;
  return (data ?? []) as TopPath[];
}
