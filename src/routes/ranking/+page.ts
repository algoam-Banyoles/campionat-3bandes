import type { PageLoad } from './$types';
import type { VPlayerBadges } from '$lib/playerBadges';

const emptyBadges: VPlayerBadges[] = [];

export const load: PageLoad = async () => {
  if (!import.meta.env.SSR) {
    return { badges: emptyBadges, badgesLoaded: false };
  }

  try {
    const { getPlayerBadges } = await import('$lib/server/daoAdmin');
    const badges = await getPlayerBadges();
    return { badges, badgesLoaded: true };
  } catch (error) {
    return { badges: emptyBadges, badgesLoaded: false };
  }
};
