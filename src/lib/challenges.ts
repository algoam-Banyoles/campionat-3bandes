import type { SupabaseClient } from '@supabase/supabase-js';

export async function acceptChallenge(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase
    .from('challenges')
    .update({ estat: 'acceptat', data_acceptacio: new Date().toISOString() })
    .eq('id', id);
  if (error) throw new Error(error.message);
}

export async function refuseChallenge(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase
    .from('challenges')
    .update({ estat: 'refusat' })
    .eq('id', id);
  if (error) throw new Error(error.message);
}

export async function scheduleChallenge(
  supabase: SupabaseClient,
  id: string,
  isoDate: string
): Promise<void> {
  const { error } = await supabase
    .from('challenges')
    .update({ data_programada: isoDate })
    .eq('id', id);
  if (error) throw new Error(error.message);
}

