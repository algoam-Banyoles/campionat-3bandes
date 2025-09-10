export function toLocalInput(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function parseLocalToIso(local: string | null): string | null {
  if (!local) return null;
  const s = local.trim().replace(' ', 'T');
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?$/);
  if (!m) return null;
  const [, y, mo, d, h, mi, ss = '0', ms = '0'] = m;
  const Y = Number(y), M = Number(mo) - 1, D = Number(d);
  const H = Number(h), I = Number(mi), S = Number(ss), MS = Number(ms.padEnd(3, '0'));
  const dt = new Date(Y, M, D, H, I, S, MS);
  if (isNaN(dt.getTime())) return null;
  if (
    dt.getFullYear() !== Y ||
    dt.getMonth() !== M ||
    dt.getDate() !== D ||
    dt.getHours() !== H ||
    dt.getMinutes() !== I ||
    dt.getSeconds() !== S
  ) return null;
  return dt.toISOString();
}

export function sameIsoMinute(a: string, b: string): boolean {
  const da = new Date(a);
  const db = new Date(b);
  if (isNaN(da.getTime()) || isNaN(db.getTime())) return false;
  const ma = Math.floor(da.getTime() / 60000);
  const mb = Math.floor(db.getTime() / 60000);
  return ma === mb;
}
