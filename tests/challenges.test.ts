import { describe, it, expect, vi } from 'vitest';
import { acceptChallenge, refuseChallenge, scheduleChallenge } from '../src/lib/challenges';

describe('challenge helpers', () => {
  it('acceptChallenge updates status', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2024-01-01T00:00:00Z'));
    const eq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn().mockReturnValue({ eq });
    const from = vi.fn().mockReturnValue({ update });
    const client = { from } as any;
    await acceptChallenge(client, 'abc');
    expect(from).toHaveBeenCalledWith('challenges');
    expect(update).toHaveBeenCalledWith({ estat: 'acceptat', data_acceptacio: new Date().toISOString() });
    expect(eq).toHaveBeenCalledWith('id', 'abc');
    vi.useRealTimers();
  });

  it('refuseChallenge updates status', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn().mockReturnValue({ eq });
    const from = vi.fn().mockReturnValue({ update });
    const client = { from } as any;
    await refuseChallenge(client, 'abc');
    expect(update).toHaveBeenCalledWith({ estat: 'refusat' });
  });

  it('scheduleChallenge sets date', async () => {
    const eq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn().mockReturnValue({ eq });
    const from = vi.fn().mockReturnValue({ update });
    const client = { from } as any;
    await scheduleChallenge(client, 'abc', '2024-01-02T00:00:00.000Z');
    expect(update).toHaveBeenCalledWith({ data_programada: '2024-01-02T00:00:00.000Z' });
  });

  it('throws on supabase error', async () => {
    const eq = vi.fn().mockResolvedValue({ error: { message: 'boom' } });
    const update = vi.fn().mockReturnValue({ eq });
    const from = vi.fn().mockReturnValue({ update });
    const client = { from } as any;
    await expect(acceptChallenge(client, 'abc')).rejects.toThrow('boom');
  });
});
