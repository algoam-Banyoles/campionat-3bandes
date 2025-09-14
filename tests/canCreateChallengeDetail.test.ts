import { describe, it, expect, vi } from 'vitest';
import { canCreateChallengeDetail } from '../src/lib/canCreateChallengeDetail';

describe('canCreateChallengeDetail', () => {
  it('calls RPC and returns result', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { ok: true }, error: null });
    const client = { rpc } as any;
    const res = await canCreateChallengeDetail(client, 'e1', 'p1', 'p2');
    expect(rpc).toHaveBeenCalledWith('can_create_challenge_detail', {
      event_id: 'e1',
      reptador_id: 'p1',
      reptat_id: 'p2'
    });
    expect(res).toEqual({ ok: true });
  });

  it('returns reason on error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'fail' } });
    const client = { rpc } as any;
    const res = await canCreateChallengeDetail(client, 'e1', 'p1', 'p2');
    expect(res).toEqual({ ok: false, reason: 'fail' });
  });
});
