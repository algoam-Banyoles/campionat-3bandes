import { json } from '@sveltejs/kit';
import type { RequestEvent } from '@sveltejs/kit';

export async function POST(event: RequestEvent) {
  let body: { access_token?: string; refresh_token?: string; expires_at?: number };
  try {
    body = await event.request.json();
  } catch {
    return json({ ok: false, error: 'JSON inv\xE0lid' }, { status: 400 });
  }
  const { access_token, refresh_token, expires_at } = body;
  if (!access_token || !refresh_token || !expires_at) {
    return json({ ok: false, error: 'Falten tokens o expiraci\xF3' }, { status: 400 });
  }
  const secure = event.url.protocol === 'https:';
  const expires = new Date(expires_at * 1000);
  const opts = { httpOnly: true, sameSite: 'lax' as const, path: '/', secure, expires };
  event.cookies.set('sb-access-token', access_token, opts);
  event.cookies.set('sb-refresh-token', refresh_token, opts);
  event.cookies.set('sb-expires-at', String(expires_at), opts);
  return json({ ok: true });
}

export function DELETE(event: RequestEvent) {
  const secure = event.url.protocol === 'https:';
  const opts = { path: '/', secure, httpOnly: true, sameSite: 'lax' as const };
  event.cookies.delete('sb-access-token', opts);
  event.cookies.delete('sb-refresh-token', opts);
  event.cookies.delete('sb-expires-at', opts);
  return json({ ok: true });
}
