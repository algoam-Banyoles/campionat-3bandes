// src/routes/admin/reptes/[id]/resultat/+page.ts
import type { PageLoad } from './$types';
import type { AppSettings } from '$lib/settings';
import { getSettings } from '$lib/settings';

export const ssr = false;

export const load: PageLoad = async () => {
  const settings: AppSettings = await getSettings();
  return { settings };
};
