import { describe, it, expect } from 'vitest';

function parseLocalToIso(local: string | null): string | null {
  if (!local) return null;
  let s = local.trim().replace(' ', 'T');
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?$/);
  if (!m) {
    const dt2 = new Date(s);
    return isNaN(dt2.getTime()) ? null : dt2.toISOString();
  }
  const [, y, mo, d, h, mi, ss = '0', ms = '0'] = m;
  const Y = Number(y), M = Number(mo) - 1, D = Number(d);
  const H = Number(h), I = Number(mi), S = Number(ss), MS = Number(ms.padEnd(3, '0'));
  const dt = new Date(Y, M, D, H, I, S, MS);
  if (isNaN(dt.getTime())) return null;
  if (dt.getFullYear() !== Y || dt.getMonth() !== M || dt.getDate() !== D || dt.getHours() !== H || dt.getMinutes() !== I) return null;
  return dt.toISOString();
}

function validateDates(inputs: (string | null)[]): string | null {
  const parsed = inputs.map(v => parseLocalToIso(v)).filter(Boolean) as string[];
  if (parsed.length === 0) return 'Cal almenys una data';
  if (parsed.length > 3) return 'No pots proposar més de tres dates';
  return null;
}

describe('parseLocalToIso', () => {
  it('converteix un format local vàlid a ISO', () => {
    expect(parseLocalToIso('2024-05-12T14:30')).toBe('2024-05-12T14:30:00.000Z');
  });

  it('retorna null per format invàlid', () => {
    expect(parseLocalToIso('2024-13-40T25:61')).toBeNull();
  });
});

describe('validació de dates', () => {
  it('requereix mínim 1 i màxim 3 dates', () => {
    expect(validateDates([])).toBeTruthy();
    expect(validateDates(['2024-05-12T14:30'])).toBeNull();
    const many = ['2024-05-12T14:30', '2024-05-13T10:00', '2024-05-14T11:00', '2024-05-15T09:00'];
    expect(validateDates(many)).toBeTruthy();
  });
});

describe('comparació exacta ISO', () => {
  it('compara ISO proposades amb acceptada', () => {
    const proposed = ['2024-05-12T14:30:00.000Z', '2024-05-13T10:00:00.000Z'];
    expect(proposed.includes('2024-05-12T14:30:00.000Z')).toBe(true);
    expect(proposed.includes('2024-05-12T14:30:00Z')).toBe(false);
  });
});
