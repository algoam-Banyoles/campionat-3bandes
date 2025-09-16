import { describe, it, expect, vi } from 'vitest';
import { resolveAccessChallenge } from '../src/lib/challenges';

describe('resolveAccessChallenge', () => {
  it('calls RPC with params and returns result', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { ok: true }, error: null });
    const client = { rpc } as any;
    const res = await resolveAccessChallenge(client, 'abc', 'reptador');
    expect(rpc).toHaveBeenCalledWith('resolve_access_challenge', {
      challenge_id: 'abc',
      winner: 'reptador'
    });
    expect(res).toEqual({ ok: true });
  });

  it('throws on rpc error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'boom' } });
    const client = { rpc } as any;
    await expect(resolveAccessChallenge(client, 'id', 'reptat')).rejects.toThrow('boom');
  });

  it('throws when response not ok', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { ok: false, error: 'x' }, error: null });
    const client = { rpc } as any;
    await expect(resolveAccessChallenge(client, 'id', 'reptat')).rejects.toThrow('x');
  });
});

