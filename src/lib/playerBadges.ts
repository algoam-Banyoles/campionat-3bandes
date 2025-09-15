export type VPlayerBadges = {
  player_id: string;
  has_active_challenge: boolean;
  in_cooldown: boolean;
  can_be_challenged: boolean;
  days_since_last: number | null;
};

export async function getPlayerBadges(): Promise<VPlayerBadges[]> {
  try {
    const { supabase } = await import('$lib/supabaseClient');
    const { data, error } = await supabase
      .from('v_player_badges')
      .select('player_id,has_active_challenge,in_cooldown,can_be_challenged,days_since_last');
    if (error) {
      console.warn('[playerBadges] v_player_badges error:', error.message);
      return [];
    }
    return (data ?? []) as VPlayerBadges[];
  } catch (e) {
    console.warn('[playerBadges] Unexpected error loading badges:', e);
    return [];
  }
}
