import { describe, it, expect, vi } from 'vitest';
import { runDeadlines } from '../src/lib/deadlinesService';

describe('deadlinesService', () => {
  it('calls maintenance RPC and returns friendly result', async () => {
    const payload = [
      { kind: 'challenges_overdue', payload: { challenges_processed: 2 } },
      { kind: 'inactivity', payload: { inactivity_processed: 1 } }
    ];
    const rpc = vi.fn().mockResolvedValue({ data: payload, error: null });
    const client = { rpc } as any;
    const res = await runDeadlines(client, 'admin@example.com');
    expect(rpc).toHaveBeenCalledWith('admin_run_maintenance_and_log', {
      p_triggered_by: 'admin:admin@example.com'
    });
    expect(res).toEqual({
      challengesProcessed: 2,
      inactivityProcessed: 1,
      raw: payload
    });
  });

  it('throws on error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'boom' } });
    const client = { rpc } as any;
    await expect(runDeadlines(client)).rejects.toThrow('boom');
  });
});
