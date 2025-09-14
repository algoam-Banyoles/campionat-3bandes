import type { SupabaseClient } from '@supabase/supabase-js';

export type RunDeadlinesResult = {
  ok: boolean;
  caducats_sense_acceptar: number;
  anullats_sense_jugar: number;
};

export async function runDeadlines(
  supabase: SupabaseClient
): Promise<RunDeadlinesResult> {
  const { data, error } = await supabase.rpc('run_challenge_deadlines');
  if (error) throw new Error(error.message);
  const result = Array.isArray(data) ? data[0] : data;
  if (!result) throw new Error('No result');
  return result as RunDeadlinesResult;
}

