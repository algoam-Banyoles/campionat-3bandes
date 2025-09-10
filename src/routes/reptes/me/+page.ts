// src/routes/reptes/me/+page.ts
import type { PageLoad } from './$types';
import type { AppSettings } from '$lib/settings';
import { getSettings } from '$lib/settings';

export const load: PageLoad = async () => {
  // Carrega la configuració (client-friendly; getSettings ja fa import dinàmic)
  const settings: AppSettings = await getSettings();

  return {
    settings
  };
};