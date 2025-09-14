import { describe, it, expect, vi } from 'vitest';
import { applyDisagreementDrop } from '../src/lib/applyDisagreementDrop';

describe('applyDisagreementDrop', () => {
  it('invokes RPC with parameters', async () => {
    const rpc = vi.fn().mockResolvedValue({ error: null });
    const client = { rpc } as any;
    await applyDisagreementDrop(client, 'e1', 'pA', 'pB');
    expect(rpc).toHaveBeenCalledWith('apply_disagreement_drop', {
      event_id: 'e1',
      player_a: 'pA',
      player_b: 'pB'
    });
  });

  it('throws on error', async () => {
    const rpc = vi.fn().mockResolvedValue({ error: { message: 'fail' } });
    const client = { rpc } as any;
    await expect(applyDisagreementDrop(client, 'e1', 'pA', 'pB')).rejects.toThrow('fail');
  });
});
