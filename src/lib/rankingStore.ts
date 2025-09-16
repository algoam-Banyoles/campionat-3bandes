// src/lib/rankingStore.ts
import { writable } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';

export type RankingRow = {
  posicio: number;
  player_id: string;
  nom: string;
  mitjana: number | null;
  estat: string;
};

export const ranking = writable<RankingRow[]>([]);

export async function refreshRanking(): Promise<void> {
  const { data, error } = await supabase.rpc('get_ranking');
  if (error) {
    console.warn('[rankingStore] get_ranking error:', error.message);
    ranking.set([]);
    return;
  }
  ranking.set((data as RankingRow[]) ?? []);
}
