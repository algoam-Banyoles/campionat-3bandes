import type { SupabaseClient } from '@supabase/supabase-js';
import { authFetch } from '$lib/utils/http';

export type ChallengeParticipants = {
  reptador_id: string | null;
  reptat_id: string | null;
};

export function isParticipant(
  mePlayerId: string | null,
  repte: ChallengeParticipants | null | undefined
): boolean {
  if (!mePlayerId || !repte) return false;
  return mePlayerId === repte.reptador_id || mePlayerId === repte.reptat_id;
}

export async function acceptChallenge(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase
    .from('challenges')
    .update({ estat: 'acceptat', data_acceptacio: new Date().toISOString() })
    .eq('id', id);
  if (error) throw new Error(error.message);
}

export async function refuseChallenge(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase
    .from('challenges')
    .update({ estat: 'refusat' })
    .eq('id', id);
  if (error) throw new Error(error.message);
}

export async function scheduleChallenge(
  _supabase: SupabaseClient,
  id: string,
  isoDate: string
): Promise<void> {
  const res = await authFetch('/campionat-continu/reptes/programar', {
    method: 'POST',
    body: JSON.stringify({ id, data_iso: isoDate })
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body?.ok === false) {
    throw new Error(body?.error || 'Error programant repte');
  }
}


export async function resolveAccessChallenge(
  supabase: SupabaseClient,
  challengeId: string,
  winner: 'reptador' | 'reptat'
): Promise<{ ok: boolean; error?: string }> {
  const { data, error } = await supabase.rpc('resolve_access_challenge', {
    challenge_id: challengeId,
    winner
  });
  if (error) throw new Error(error.message);
  const res = (data as any) ?? { ok: false };
  if (!res.ok) throw new Error(res.error || 'Error resolent repte d\'accés');
  return res;
}

