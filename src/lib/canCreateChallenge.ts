import type { SupabaseClient } from '@supabase/supabase-js';

export type CanCreateChallengeResult = {
  ok: boolean;
  reason: string | null;
  warning: string | null;
};

export async function canCreateChallenge(
  supabase: SupabaseClient,
  eventId: string,
  reptadorId: string,
  reptatId: string
): Promise<CanCreateChallengeResult> {
  const { data, error } = await supabase.rpc('can_create_challenge', {
    p_event: eventId,
    p_reptador: reptadorId,
    p_reptat: reptatId
  });
  if (error) return { ok: false, reason: error.message, warning: null };
  const result = data as CanCreateChallengeResult[] | null;
  if (!result || result.length === 0) return { ok: false, reason: 'No result', warning: null };
  return result[0];
}
