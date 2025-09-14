import { writable } from 'svelte/store';

export type Toast = {
  id: number;
  message: string;
  type: 'info' | 'success' | 'error';
};

export const toasts = writable<Toast[]>([]);

export function addToast(message: string, type: Toast['type'] = 'info', timeout = 3000) {
  const id = Date.now();
  toasts.update((t) => [...t, { id, message, type }]);
  setTimeout(() => {
    toasts.update((t) => t.filter((x) => x.id !== id));
  }, timeout);
}
