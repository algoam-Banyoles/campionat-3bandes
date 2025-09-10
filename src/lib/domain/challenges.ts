export type CanCreateResult = { ok: boolean; reason: string | null; warning: string | null };

export async function canCreateChallenge(
  supabase: any,
  eventId: string,
  reptadorId: string,
  reptatId: string
): Promise<CanCreateResult> {
  const { data, error } = await supabase.rpc('can_create_challenge', {
    p_event: eventId,
    p_reptador: reptadorId,
    p_reptat: reptatId
  });
  if (error) return { ok: false, reason: error.message, warning: null };
  if (!data || data.length === 0) return { ok: false, reason: 'No result', warning: null };
  return data[0] as CanCreateResult;
}
