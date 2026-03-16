import { get } from 'svelte/store';
import { isAdmin, adminChecked } from '$lib/stores/adminAuth';
import { user, type UserProfile } from '$lib/stores/auth';
import { formatSupabaseError } from '$lib/ui/alerts';

/**
 * Reusable admin page initialization utility.
 * Waits for admin auth check, then runs the provided load function.
 * Returns reactive state for loading/error that the component can bind to.
 */
export async function initAdminPage(
  loadFn: () => Promise<void>,
  opts?: { redirectIfNoSession?: string }
): Promise<{ loading: boolean; error: string | null }> {
  const result = { loading: true, error: null as string | null };

  // Wait for admin auth check to complete
  if (!get(adminChecked)) {
    await new Promise<void>((resolve) => {
      const unsub = adminChecked.subscribe((checked) => {
        if (checked) {
          unsub();
          resolve();
        }
      });
    });
  }

  if (!get(isAdmin)) {
    result.loading = false;
    return result;
  }

  // Handle optional session redirect
  if (opts?.redirectIfNoSession) {
    const u = get(user) as UserProfile | null;
    if (!u?.email) {
      const { goto } = await import('$app/navigation');
      goto(opts.redirectIfNoSession);
      result.loading = false;
      return result;
    }
  }

  try {
    await loadFn();
  } catch (e) {
    result.error = formatSupabaseError(e);
  } finally {
    result.loading = false;
  }

  return result;
}
