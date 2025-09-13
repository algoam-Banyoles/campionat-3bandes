import type { SupabaseClient } from '@supabase/supabase-js';

export type CanCreateAccessResult = {
  ok: boolean;
  reason: string | null;
};

export async function canCreateAccessChallenge(
  supabase: SupabaseClient,
  eventId: string,
  reptadorId: string,
  reptatId: string
): Promise<CanCreateAccessResult> {
  const { data, error } = await supabase.rpc('can_create_access_challenge', {
    p_event: eventId,
    p_reptador: reptadorId,
    p_reptat: reptatId
  });
  if (error) return { ok: false, reason: error.message };
  const result = data as CanCreateAccessResult[] | null;
  if (!result || result.length === 0) return { ok: false, reason: 'No result' };
  return result[0];
}
