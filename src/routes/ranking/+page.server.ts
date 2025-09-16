import type { PageServerLoad } from './$types';
import type { VPlayerBadges } from '$lib/playerBadges';

const emptyBadges: VPlayerBadges[] = [];

export const load: PageServerLoad = async () => {
  try {
    const { getPlayerBadges } = await import('$lib/server/daoAdmin');
    const badges = await getPlayerBadges();
    return { badges, badgesLoaded: true };
  } catch (error) {
    return { badges: emptyBadges, badgesLoaded: false };
  }
};
