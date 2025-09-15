import { beforeEach, describe, expect, it, vi } from 'vitest';

const supabaseMock = vi.hoisted(() => ({
  from: vi.fn(),
  select: vi.fn()
}));

vi.mock('$lib/supabaseClient', () => {
  const select = vi.fn();
  const from = vi.fn(() => ({ select }));
  supabaseMock.from = from;
  supabaseMock.select = select;
  return {
    supabase: { from }
  };
});

import { getPlayerBadges } from '../src/lib/playerBadges';

beforeEach(() => {
  supabaseMock.select.mockReset();
  supabaseMock.from.mockClear();
});

describe('getPlayerBadges', () => {
  it('returns player badges when query succeeds', async () => {
    const rows = [
      {
        event_id: 'event-1',
        player_id: 'player-1',
        posicio: 1,
        last_play_date: '2024-01-01',
        days_since_last: 3,
        has_active_challenge: true,
        in_cooldown: false,
        can_be_challenged: false
      }
    ];
    supabaseMock.select.mockResolvedValue({ data: rows, error: null });

    const result = await getPlayerBadges();

    expect(supabaseMock.from).toHaveBeenCalledWith('v_player_badges');
    expect(supabaseMock.select).toHaveBeenCalledWith('*');
    expect(result).toEqual(rows);
  });

  it('returns empty array when no rows', async () => {
    supabaseMock.select.mockResolvedValue({ data: null, error: null });

    const result = await getPlayerBadges();

    expect(result).toEqual([]);
  });

  it('throws when supabase returns error', async () => {
    const err = new Error('select failed');
    supabaseMock.select.mockResolvedValue({ data: null, error: err });

    await expect(getPlayerBadges()).rejects.toBe(err);
  });
});
