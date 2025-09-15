import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { VPlayerBadges } from '../src/lib/playerBadges';

const selectMock = vi.fn();
const fromMock = vi.fn(() => ({ select: selectMock }));

vi.mock('$lib/supabaseClient', () => ({
  supabase: {
    from: fromMock
  }
}));

import { getPlayerBadges } from '../src/lib/playerBadges';

describe('getPlayerBadges', () => {
  beforeEach(() => {
    selectMock.mockReset();
    fromMock.mockClear();
  });

  it('retrieves badge data from supabase', async () => {
    const sample: VPlayerBadges[] = [
      {
        event_id: 'event-1',
        player_id: 'player-1',
        posicio: 1,
        last_play_date: '2024-01-01',
        days_since_last: 2,
        has_active_challenge: true,
        in_cooldown: false,
        can_be_challenged: false
      }
    ];
    selectMock.mockResolvedValue({ data: sample, error: null });

    const result = await getPlayerBadges();

    expect(fromMock).toHaveBeenCalledWith('v_player_badges');
    expect(selectMock).toHaveBeenCalledWith('*');
    expect(result).toEqual(sample);
  });

  it('throws when supabase returns an error', async () => {
    const supabaseError = { message: 'boom' } as const;
    selectMock.mockResolvedValue({ data: null, error: supabaseError });

    await expect(getPlayerBadges()).rejects.toBe(supabaseError);
  });

  it('returns an empty array when supabase has no rows', async () => {
    selectMock.mockResolvedValue({ data: null, error: null });

    const result = await getPlayerBadges();

    expect(result).toEqual([]);
  });
});
