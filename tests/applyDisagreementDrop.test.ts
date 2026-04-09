import { describe, it, expect, vi } from 'vitest';
import { applyDisagreementDrop } from '../src/lib/applyDisagreementDrop';

describe('applyDisagreementDrop', () => {
  it('invokes RPC with parameters', async () => {
    const rpc = vi.fn().mockResolvedValue({ error: null });
    const client = { rpc } as any;
    await applyDisagreementDrop(client, 'e1', 100, 200);
    expect(rpc).toHaveBeenCalledWith('apply_disagreement_drop_v2', {
      p_event: 'e1',
      p_soci_a: 100,
      p_soci_b: 200
    });
  });

  it('throws on error', async () => {
    const rpc = vi.fn().mockResolvedValue({ error: { message: 'fail' } });
    const client = { rpc } as any;
    await expect(applyDisagreementDrop(client, 'e1', 100, 200)).rejects.toThrow('fail');
  });
});
