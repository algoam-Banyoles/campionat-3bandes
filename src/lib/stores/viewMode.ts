import { writable, derived } from 'svelte/store';
import { isAdmin as actualIsAdmin, adminChecked } from './adminAuth';
import { browser } from '$app/environment';

export type ViewMode = 'admin' | 'player';

// Store to manage view mode (admin can switch to player view for testing)
function createViewModeStore() {
  // Load initial value from localStorage if in browser
  const initialValue: ViewMode = browser
    ? (localStorage.getItem('viewMode') as ViewMode) || 'admin'
    : 'admin';

  const { subscribe, set, update } = writable<ViewMode>(initialValue);

  return {
    subscribe,
    setMode: (mode: ViewMode) => {
      if (browser) {
        localStorage.setItem('viewMode', mode);
      }
      set(mode);
    },
    toggleMode: () => {
      update(mode => {
        const newMode = mode === 'admin' ? 'player' : 'admin';
        if (browser) {
          localStorage.setItem('viewMode', newMode);
        }
        return newMode;
      });
    },
    reset: () => {
      if (browser) {
        localStorage.setItem('viewMode', 'admin');
      }
      set('admin');
    }
  };
}

export const viewMode = createViewModeStore();

// Effective admin status: true only if user is actually admin AND viewMode is 'admin'
// Note: Don't check adminChecked here - let the layout handle the loading state
export const effectiveIsAdmin = derived(
  [actualIsAdmin, viewMode],
  ([$actualIsAdmin, $viewMode]) => $actualIsAdmin && $viewMode === 'admin'
);
