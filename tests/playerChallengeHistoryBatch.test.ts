/**
 * Test de la funció batch `getPlayerChallengeHistoriesBatch`. Mockejem
 * `supabase` perquè la query no surti del procés. La funció és lògica de
 * pure data-grouping un cop tenim la resposta.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock supabase abans d'importar res que en depengui
const mockOrder = vi.fn();
const mockLimit = vi.fn();
const mockOr = vi.fn();
const mockEq = vi.fn();
const mockSelect = vi.fn();
const mockFrom = vi.fn();

vi.mock('$lib/supabaseClient', () => ({
  supabase: {
    from: (...args: any[]) => mockFrom(...args)
  }
}));

import { getPlayerChallengeHistoriesBatch } from '../src/lib/stores/playerChallengeHistory';

function setupQueryReturnRows(rows: any[]) {
  mockLimit.mockResolvedValue({ data: rows, error: null });
  mockOr.mockReturnValue({ order: mockOrder });
  mockOrder.mockReturnValue({ limit: mockLimit });
  mockEq.mockReturnValue({ or: mockOr });
  mockSelect.mockReturnValue({ eq: mockEq });
  mockFrom.mockReturnValue({ select: mockSelect });
}

describe('getPlayerChallengeHistoriesBatch', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('retorna Map buit si no hi ha socis', async () => {
    const result = await getPlayerChallengeHistoriesBatch([], 'event-1', 6);
    expect(result.size).toBe(0);
    expect(mockFrom).not.toHaveBeenCalled();
  });

  it('agrupa correctament resultats per soci (reptador guanya)', async () => {
    setupQueryReturnRows([
      {
        id: 'm1',
        data_joc: '2026-01-01',
        resultat: 'guanya_reptador',
        challenge_id: 'c1',
        challenges: { reptador_soci_numero: 100, reptat_soci_numero: 200, event_id: 'e1' }
      }
    ]);
    const result = await getPlayerChallengeHistoriesBatch([100, 200], 'e1', 6);
    expect(result.get(100)).toEqual(['W']);
    expect(result.get(200)).toEqual(['L']);
  });

  it('reptat guanya per walkover_reptat', async () => {
    setupQueryReturnRows([
      {
        id: 'm1',
        data_joc: '2026-01-01',
        resultat: 'walkover_reptat',
        challenge_id: 'c1',
        challenges: { reptador_soci_numero: 100, reptat_soci_numero: 200, event_id: 'e1' }
      }
    ]);
    const result = await getPlayerChallengeHistoriesBatch([100, 200], 'e1', 6);
    expect(result.get(100)).toEqual(['L']);
    expect(result.get(200)).toEqual(['W']);
  });

  it('respecta el límit per soci', async () => {
    const rows = Array.from({ length: 10 }, (_, i) => ({
      id: `m${i}`,
      data_joc: `2026-01-${String(i + 1).padStart(2, '0')}`,
      resultat: 'guanya_reptador',
      challenge_id: `c${i}`,
      challenges: { reptador_soci_numero: 100, reptat_soci_numero: 999, event_id: 'e1' }
    }));
    setupQueryReturnRows(rows);
    const result = await getPlayerChallengeHistoriesBatch([100], 'e1', 3);
    expect(result.get(100)?.length).toBe(3);
  });

  it('un mateix match amb 2 socis del top — registrats per a tots dos', async () => {
    setupQueryReturnRows([
      {
        id: 'm1',
        data_joc: '2026-01-01',
        resultat: 'guanya_reptador',
        challenge_id: 'c1',
        challenges: { reptador_soci_numero: 100, reptat_soci_numero: 200, event_id: 'e1' }
      }
    ]);
    const result = await getPlayerChallengeHistoriesBatch([100, 200, 300], 'e1', 6);
    expect(result.get(100)).toEqual(['W']);
    expect(result.get(200)).toEqual(['L']);
    expect(result.has(300)).toBe(false); // 300 no participa en cap match
  });

  it('error a la query → retorna Map buit', async () => {
    mockLimit.mockResolvedValue({ data: null, error: { message: 'simulated' } });
    mockOr.mockReturnValue({ order: mockOrder });
    mockOrder.mockReturnValue({ limit: mockLimit });
    mockEq.mockReturnValue({ or: mockOr });
    mockSelect.mockReturnValue({ eq: mockEq });
    mockFrom.mockReturnValue({ select: mockSelect });

    const result = await getPlayerChallengeHistoriesBatch([100], 'e1', 6);
    expect(result.size).toBe(0);
  });
});
