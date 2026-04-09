import { describe, it, expect, vi } from 'vitest';
import { canCreateChallengeDetail } from '../src/lib/canCreateChallengeDetail';

describe('canCreateChallengeDetail', () => {
  it('calls RPC _v2 and returns result', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { ok: true }, error: null });
    const client = { rpc } as any;
    const res = await canCreateChallengeDetail(client, 'e1', 10, 20);
    expect(rpc).toHaveBeenCalledWith('can_create_challenge_detail_v2', {
      p_event: 'e1',
      p_reptador_soci: 10,
      p_reptat_soci: 20
    });
    expect(res).toEqual({ ok: true });
  });

  it('returns reason on error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'fail' } });
    const client = { rpc } as any;
    const res = await canCreateChallengeDetail(client, 'e1', 10, 20);
    expect(res).toEqual({ ok: false, reason: 'fail' });
  });
});
