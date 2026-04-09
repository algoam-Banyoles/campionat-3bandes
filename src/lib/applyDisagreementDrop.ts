import type { SupabaseClient } from '@supabase/supabase-js';

export async function applyDisagreementDrop(
  supabase: SupabaseClient,
  eventId: string,
  sociA: number,
  sociB: number
): Promise<void> {
  const { error } = await supabase.rpc('apply_disagreement_drop_v2', {
    p_event: eventId,
    p_soci_a: sociA,
    p_soci_b: sociB
  });
  if (error) throw new Error(error.message);
}
