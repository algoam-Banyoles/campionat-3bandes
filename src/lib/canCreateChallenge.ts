import type { SupabaseClient } from '@supabase/supabase-js';

export type CanCreateChallengeResult = {
  ok: boolean;
  reason: string | null;
  warning: string | null;
};

export async function canCreateChallenge(
  supabase: SupabaseClient,
  eventId: string,
  reptadorSoci: number,
  reptatSoci: number
): Promise<CanCreateChallengeResult> {
  const { data, error } = await supabase.rpc('can_create_challenge_v2', {
    p_event: eventId,
    p_reptador_soci: reptadorSoci,
    p_reptat_soci: reptatSoci
  });
  if (error) return { ok: false, reason: error.message, warning: null };
  const result = data as CanCreateChallengeResult[] | null;
  if (!result || result.length === 0) return { ok: false, reason: 'No result', warning: null };
  return result[0];
}
