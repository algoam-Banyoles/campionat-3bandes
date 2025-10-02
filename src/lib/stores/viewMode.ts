import { writable, derived } from 'svelte/store';
import { isAdmin as actualIsAdmin } from './adminAuth';

export type ViewMode = 'admin' | 'player';

// Store to manage view mode (admin can switch to player view for testing)
function createViewModeStore() {
  const { subscribe, set, update } = writable<ViewMode>('admin');

  return {
    subscribe,
    setMode: (mode: ViewMode) => set(mode),
    toggleMode: () => update(mode => mode === 'admin' ? 'player' : 'admin'),
    reset: () => set('admin')
  };
}

export const viewMode = createViewModeStore();

// Effective admin status: true only if user is actually admin AND viewMode is 'admin'
export const effectiveIsAdmin = derived(
  [actualIsAdmin, viewMode],
  ([$actualIsAdmin, $viewMode]) => $actualIsAdmin && $viewMode === 'admin'
);
