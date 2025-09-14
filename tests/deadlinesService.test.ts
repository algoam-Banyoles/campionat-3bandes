import { describe, it, expect, vi } from 'vitest';
import { runDeadlines } from '../src/lib/deadlinesService';

describe('deadlinesService', () => {
  it('calls RPC and returns result', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { ok: true, caducats_sense_acceptar: 1, anullats_sense_jugar: 2 }, error: null });
    const client = { rpc } as any;
    const res = await runDeadlines(client);
    expect(rpc).toHaveBeenCalledWith('run_challenge_deadlines');
    expect(res).toEqual({ ok: true, caducats_sense_acceptar: 1, anullats_sense_jugar: 2 });
  });

  it('throws on error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'boom' } });
    const client = { rpc } as any;
    await expect(runDeadlines(client)).rejects.toThrow('boom');
  });
});

