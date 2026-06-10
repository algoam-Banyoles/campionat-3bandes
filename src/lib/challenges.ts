import type { SupabaseClient } from '@supabase/supabase-js';
import { authFetch } from '$lib/utils/http';

export type ChallengeParticipants = {
  reptador_soci_numero: number | null;
  reptat_soci_numero: number | null;
};

export function isParticipant(
  meSociNumero: number | null,
  repte: ChallengeParticipants | null | undefined
): boolean {
  if (!meSociNumero || !repte) return false;
  return meSociNumero === repte.reptador_soci_numero || meSociNumero === repte.reptat_soci_numero;
}

/**
 * Accepta un repte a través de l'endpoint servidor guardat.
 * L'endpoint valida que l'estat sigui 'proposat' i que l'usuari sigui el reptat (o admin).
 */
export async function acceptChallenge(id: string): Promise<void> {
  const res = await authFetch('/campionat-continu/reptes/accepta', {
    method: 'POST',
    body: JSON.stringify({ id, data_iso: null })
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body?.ok === false) {
    throw new Error(body?.error || 'Error acceptant el repte');
  }
}

/**
 * Refusa un repte a través de l'endpoint servidor guardat.
 * L'endpoint valida que l'estat sigui 'proposat' i que l'usuari sigui el reptat (o admin).
 */
export async function refuseChallenge(id: string): Promise<void> {
  const res = await authFetch('/campionat-continu/reptes/refusa', {
    method: 'POST',
    body: JSON.stringify({ id })
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body?.ok === false) {
    throw new Error(body?.error || 'Error refusant el repte');
  }
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
  if (!res.ok) throw new Error(res.error || 'Error resolent repte d\'acces');
  return res;
}

