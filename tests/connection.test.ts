import { describe, it, expect, vi } from 'vitest';
import { withSupabase, SupabaseTimeoutError } from '$lib/utils/supabase';
import {
  CircuitOpenError,
  OperationTimeoutError
} from '$lib/connection/connectionManager';

describe('withSupabase timeout', () => {
  it('llança SupabaseTimeoutError si l\'operació no resol dins el termini', async () => {
    const promise = withSupabase(
      () => new Promise<never>(() => {
        /* mai resol */
      }),
      { timeoutMs: 50 }
    );

    await expect(promise).rejects.toBeInstanceOf(SupabaseTimeoutError);
  });

  it('retorna el resultat si l\'operació resol abans del timeout', async () => {
    const result = await withSupabase(async () => 'ok', { timeoutMs: 200 });
    expect(result).toBe('ok');
  });
});

describe('connectionManager — circuit breaker i timeouts', () => {
  it('OperationTimeoutError es llança si un intent supera perAttemptTimeoutMs', async () => {
    // Importem dinàmicament per evitar inicialitzar el singleton fora de browser
    const { connectionManager } = await import('$lib/connection/connectionManager');

    const promise = connectionManager.executeWithRetry(
      () => new Promise<never>(() => {
        /* hang */
      }),
      'background',
      { maxRetries: 0, perAttemptTimeoutMs: 50 }
    );

    await expect(promise).rejects.toBeInstanceOf(OperationTimeoutError);
  });

  it('obre el circuit després de 5 errors consecutius i fail-fast el 6è', async () => {
    const { connectionManager } = await import('$lib/connection/connectionManager');

    const failing = vi.fn(() => Promise.reject(new Error('boom')));

    // 5 crides amb 0 retries → 5 fallades consecutives → circuit obert
    for (let i = 0; i < 5; i++) {
      await expect(
        connectionManager.executeWithRetry(failing, 'background', {
          maxRetries: 0,
          perAttemptTimeoutMs: 1000
        })
      ).rejects.toBeTruthy();
    }

    // La 6a crida ha de fallar de forma immediata sense invocar `failing`
    const callsBefore = failing.mock.calls.length;
    await expect(
      connectionManager.executeWithRetry(failing, 'background', {
        maxRetries: 0,
        perAttemptTimeoutMs: 1000
      })
    ).rejects.toBeInstanceOf(CircuitOpenError);
    expect(failing.mock.calls.length).toBe(callsBefore);
  });
});
