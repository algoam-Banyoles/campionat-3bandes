import { describe, it, expect } from 'vitest';
import { toLocalInput, parseLocalToIso, sameIsoMinute } from './dates';

describe('toLocalInput', () => {
  it('converteix ISO vàlid a format local', () => {
    const iso = new Date(2024, 4, 12, 14, 30).toISOString();
    const local = toLocalInput(iso);
    expect(local).not.toBe('');
    expect(parseLocalToIso(local)).toBe(iso);
  });

  it('retorna buit per ISO invàlid', () => {
    expect(toLocalInput('foo')).toBe('');
  });
});

describe('parseLocalToIso', () => {
  it('accepta format sense segons', () => {
    const expected = new Date(2024, 4, 12, 14, 30).toISOString();
    expect(parseLocalToIso('2024-05-12T14:30')).toBe(expected);
  });
  it('accepta format amb segons', () => {
    const expected = new Date(2024, 4, 12, 14, 30, 15).toISOString();
    expect(parseLocalToIso('2024-05-12T14:30:15')).toBe(expected);
  });
  it('detecta format invàlid', () => {
    expect(parseLocalToIso('2024-13-40T25:61')).toBeNull();
  });
  it('detecta data impossible', () => {
    expect(parseLocalToIso('2024-02-30T10:00')).toBeNull();
  });
});

describe('sameIsoMinute', () => {
  it('retorna true per ISO al mateix minut', () => {
    const a = '2024-05-12T14:30:00.000Z';
    const b = '2024-05-12T14:30:59.999Z';
    expect(sameIsoMinute(a, b)).toBe(true);
  });
  it('retorna false per minuts diferents', () => {
    const a = '2024-05-12T14:30:00.000Z';
    const b = '2024-05-12T14:31:00.000Z';
    expect(sameIsoMinute(a, b)).toBe(false);
  });
});
