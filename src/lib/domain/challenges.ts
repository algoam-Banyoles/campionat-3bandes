export type CanCreateResult = { ok: boolean; reason: string | null };

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
  if (error) return { ok: false, reason: error.message };
  if (!data || data.length === 0) return { ok: false, reason: 'No result' };
  return data[0];
}
