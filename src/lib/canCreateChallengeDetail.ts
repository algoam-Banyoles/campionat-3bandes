import type { SupabaseClient } from '@supabase/supabase-js';

export type CanCreateChallengeDetailResult = {
  ok: boolean;
  reason?: string | null;
};

export async function canCreateChallengeDetail(
  supabase: SupabaseClient,
  eventId: string,
  reptadorId: string,
  reptatId: string
): Promise<CanCreateChallengeDetailResult> {
  const { data, error } = await supabase.rpc('can_create_challenge_detail', {
    event_id: eventId,
    reptador_id: reptadorId,
    reptat_id: reptatId
  });
  if (error) {
    return { ok: false, reason: error.message };
  }
  // Supabase RPC may return single object or array
  const result = Array.isArray(data) ? data[0] : data;
  if (!result) {
    return { ok: false, reason: 'No result' };
  }
  return result as CanCreateChallengeDetailResult;
}

