import type { PageServerLoad } from './$types';
import { requireAdmin } from '$lib/server/adminGuard';

export const load: PageServerLoad = async (event) => {
  // Only check admin permissions, don't load data server-side
  await requireAdmin(event);

  return {
    // Return empty structure, data will be loaded client-side
  };
};