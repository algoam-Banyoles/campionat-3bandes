export type VPlayerBadges = {
  event_id: string;
  player_id: string;
  posicio: number;
  last_play_date: string | null;
  days_since_last: number | null;
  has_active_challenge: boolean;
  in_cooldown: boolean;
  can_be_challenged: boolean;
  cooldown_days_left: number;
};

export async function getPlayerBadges(): Promise<VPlayerBadges[]> {
  const { supabase } = await import('$lib/supabaseClient');
  const { data, error } = await supabase
    .from('v_player_badges')
    .select('event_id, player_id, posicio, last_play_date, days_since_last, has_active_challenge, in_cooldown, can_be_challenged, cooldown_days_left');
  if (error) throw error;
  return (data ?? []) as VPlayerBadges[];
}
