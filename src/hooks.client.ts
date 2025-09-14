import type { HandleFetch } from '@sveltejs/kit';
import { get } from 'svelte/store';
import { authState } from '$lib/stores/auth';
import { ensureFreshToken, signOut } from '$lib/utils/auth-client';

export const handleFetch: HandleFetch = async ({ request, fetch }) => {
  const st = get(authState);
  const headers = new Headers(request.headers);
  if (st.status === 'authenticated' && !headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${st.session.access_token}`);
  }
  if (!headers.has('apikey') && import.meta.env.VITE_PUBLIC_APIKEY) {
    headers.set('apikey', import.meta.env.VITE_PUBLIC_APIKEY);
  }

  let res = await fetch(new Request(request, { headers }));

  if (res.status === 401) {
    const token = await ensureFreshToken();
    if (token) {
      headers.set('Authorization', `Bearer ${token}`);
      res = await fetch(new Request(request, { headers }));
    }
    if (res.status === 401) {
      await signOut();
    }
  }
  return res;
};
