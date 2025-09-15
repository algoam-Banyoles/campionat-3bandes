import { supabase } from '$lib/supabaseClient';

export type VPlayerBadges = {
  event_id: string;
  player_id: string;
  posicio: number;
  last_play_date: string | null;
  days_since_last: number | null;
  has_active_challenge: boolean;
  in_cooldown: boolean;
  can_be_challenged: boolean;
};

export async function getPlayerBadges(): Promise<VPlayerBadges[]> {
  const { data, error } = await supabase
    .from('v_player_badges')
    .select('*');
  if (error) throw error;
  return (data ?? []) as VPlayerBadges[];
}
