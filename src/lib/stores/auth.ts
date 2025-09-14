import { writable, derived } from 'svelte/store';

export type UserProfile = { id: string; email: string; roles: string[] };

export type AuthState =
  | { status: 'loading'; session: null; user: null }
  | { status: 'anonymous'; session: null; user: null }
  | { status: 'authenticated'; session: { access_token: string }; user: UserProfile };

export const authState = writable<AuthState>({ status: 'loading', session: null, user: null });

export const roles = derived(authState, ($a) => ($a.status === 'authenticated' ? $a.user.roles : []));
export const isAdmin = derived(roles, ($r) => $r.includes('admin'));
export const userId = derived(authState, ($a) => ($a.status === 'authenticated' ? $a.user.id : null));
export const isLoading = derived(authState, ($a) => $a.status === 'loading');
export const isAnon = derived(authState, ($a) => $a.status === 'anonymous');

// Compat exports for existing code
export const user = derived(authState, ($a) => ($a.status === 'authenticated' ? $a.user : null));
export const status = derived(authState, ($a) => $a.status);
export const adminStore = isAdmin;
export const token = derived(authState, ($a) => ($a.status === 'authenticated' ? $a.session.access_token : null));
