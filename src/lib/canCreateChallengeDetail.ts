import type { SupabaseClient } from '@supabase/supabase-js';

export type CanCreateChallengeDetailResult = {
  ok: boolean;
  reason?: string | null;
};

export async function canCreateChallengeDetail(
  supabase: SupabaseClient,
  eventId: string,
  reptadorSoci: number,
  reptatSoci: number
): Promise<CanCreateChallengeDetailResult> {
  const { data, error } = await supabase.rpc('can_create_challenge_detail_v2', {
    p_event: eventId,
    p_reptador_soci: reptadorSoci,
    p_reptat_soci: reptatSoci
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

