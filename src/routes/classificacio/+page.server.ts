import type { PageServerLoad } from './$types';
import type { VPlayerBadges } from '$lib/server/daoAdmin';
import { getPlayerBadges } from '$lib/server/daoAdmin';

export const prerender = false;

export const load: PageServerLoad = async () => {
  try {
    const badges = await getPlayerBadges();
    return { badges };
  } catch (error) {
    console.error('No s\u2019han pogut carregar els badges dels jugadors', error);
    return { badges: null as VPlayerBadges[] | null };
  }
};
