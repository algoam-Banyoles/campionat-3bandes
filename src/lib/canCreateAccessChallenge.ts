import type { SupabaseClient } from '@supabase/supabase-js';

export type CanCreateAccessResult = {
  ok: boolean;
  reason: string | null;
};

export async function canCreateAccessChallenge(
  supabase: SupabaseClient,
  eventId: string,
  reptadorSoci: number,
  reptatSoci: number
): Promise<CanCreateAccessResult> {
  const { data, error } = await supabase.rpc('can_create_access_challenge_v2', {
    p_event: eventId,
    p_reptador_soci: reptadorSoci,
    p_reptat_soci: reptatSoci
  });
  if (error) return { ok: false, reason: error.message };
  const result = data as CanCreateAccessResult[] | null;
  if (!result || result.length === 0) return { ok: false, reason: 'No result' };
  return result[0];
}
