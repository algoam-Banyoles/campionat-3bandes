import type { SupabaseClient } from '@supabase/supabase-js';

export async function applyDisagreementDrop(
  supabase: SupabaseClient,
  eventId: string,
  playerA: string,
  playerB: string
): Promise<void> {
  const { error } = await supabase.rpc('apply_disagreement_drop', {
    event_id: eventId,
    player_a: playerA,
    player_b: playerB
  });
  if (error) throw new Error(error.message);
}
