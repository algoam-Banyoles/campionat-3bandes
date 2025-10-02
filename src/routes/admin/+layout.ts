import type { LayoutLoad } from './$types';

export const ssr = false;
export const prerender = false;

export const load: LayoutLoad = async () => {
  // Admin check is now handled in +layout.svelte using effectiveIsAdmin
  // This allows the viewMode toggle to work properly
  return {};
};
