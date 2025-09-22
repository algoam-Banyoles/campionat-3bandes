import { getPlayerBadges, type VPlayerBadges } from '$lib/playerBadges';

export type BadgeView = {
  label: string;
  text: string;
  className: string;
};

const ACTIVE_BADGE: BadgeView = {
  label: 'Repte actiu',
  text: 'Repte actiu',
  className: 'rounded bg-blue-100 px-1.5 py-0.5 text-xs font-medium text-blue-700'
};

const CHALLENGEABLE_BADGE: BadgeView = {
  label: 'Es pot reptar',
  text: 'Es pot reptar',
  className: 'rounded bg-green-100 px-1.5 py-0.5 text-xs font-medium text-green-700'
};

export function getBadgeView(badge: VPlayerBadges | undefined | null): BadgeView | null {
  if (!badge) return null;
  if (badge.has_active_challenge) {
    return ACTIVE_BADGE;
  }
  if (badge.in_cooldown) {
    return null;
  }
  if (badge.can_be_challenged) {
    return CHALLENGEABLE_BADGE;
  }
  return null;
}

export async function fetchBadgeMap(
  getBadges: () => Promise<VPlayerBadges[]> = getPlayerBadges
): Promise<Map<string, VPlayerBadges>> {
  const list = await getBadges();
  return new Map(list.map((badge) => [badge.player_id, badge]));
}
