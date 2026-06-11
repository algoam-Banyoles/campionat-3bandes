import { describe, it, expect, vi, beforeEach } from 'vitest';
vi.mock('$lib/utils/http', () => ({ authFetch: vi.fn() }));
import { authFetch } from '$lib/utils/http';
import { acceptChallenge, refuseChallenge, scheduleChallenge } from '../src/lib/challenges';

function mockResponse(ok: boolean, body: unknown) {
  return { ok, json: async () => body } as any;
}

describe('challenge helpers', () => {
  beforeEach(() => {
    (authFetch as any).mockReset();
  });

  it('acceptChallenge posts to the guarded endpoint', async () => {
    (authFetch as any).mockResolvedValue(mockResponse(true, { ok: true }));
    await acceptChallenge('abc');
    expect(authFetch).toHaveBeenCalledWith('/campionat-continu/reptes/accepta', {
      method: 'POST',
      body: JSON.stringify({ id: 'abc', data_iso: null })
    });
  });

  it('refuseChallenge posts to the guarded endpoint', async () => {
    (authFetch as any).mockResolvedValue(mockResponse(true, { ok: true }));
    await refuseChallenge('abc');
    expect(authFetch).toHaveBeenCalledWith('/campionat-continu/reptes/refusa', {
      method: 'POST',
      body: JSON.stringify({ id: 'abc' })
    });
  });

  it('scheduleChallenge posts to backend', async () => {
    (authFetch as any).mockResolvedValue(mockResponse(true, { ok: true }));
    await scheduleChallenge({} as any, 'abc', '2024-01-02T00:00:00.000Z');
    expect(authFetch).toHaveBeenCalledWith('/campionat-continu/reptes/programar', {
      method: 'POST',
      body: JSON.stringify({ id: 'abc', data_iso: '2024-01-02T00:00:00.000Z' })
    });
  });

  it('throws with the server error message on failure', async () => {
    (authFetch as any).mockResolvedValue(mockResponse(false, { ok: false, error: 'boom' }));
    await expect(acceptChallenge('abc')).rejects.toThrow('boom');
  });

  it('throws a generic Catalan message when the body is not JSON', async () => {
    (authFetch as any).mockResolvedValue({
      ok: false,
      json: async () => {
        throw new Error('not json');
      }
    } as any);
    await expect(refuseChallenge('abc')).rejects.toThrow('Error refusant el repte');
  });
});
