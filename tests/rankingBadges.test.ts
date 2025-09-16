import { describe, expect, it, vi } from 'vitest';
import { fetchBadgeMap, getBadgeView } from '../src/lib/badgeView';
import type { VPlayerBadges } from '../src/lib/playerBadges';

describe('badge rendering', () => {
  const badgeFixtures: VPlayerBadges[] = [
    {
      event_id: 'event-1',
      player_id: 'p1',
      posicio: 1,
      last_play_date: '2024-01-01',
      days_since_last: 0,
      has_active_challenge: true,
      in_cooldown: false,
      can_be_challenged: false,
      cooldown_days_left: 0
    },
    {
      event_id: 'event-1',
      player_id: 'p2',
      posicio: 2,
      last_play_date: '2024-01-02',
      days_since_last: 1,
      has_active_challenge: false,
      in_cooldown: true,
      can_be_challenged: false,
      cooldown_days_left: 3
    },
    {
      event_id: 'event-1',
      player_id: 'p3',
      posicio: 3,
      last_play_date: '2024-01-03',
      days_since_last: 2,
      has_active_challenge: false,
      in_cooldown: false,
      can_be_challenged: true,
      cooldown_days_left: 0
    }
  ];

  it('maps player badges to the correct view labels', async () => {
    const mockGetBadges = vi.fn<[], Promise<VPlayerBadges[]>>().mockResolvedValue(badgeFixtures);

    const map = await fetchBadgeMap(mockGetBadges);

    expect(mockGetBadges).toHaveBeenCalledTimes(1);

    const activeView = getBadgeView(map.get('p1'));
    const cooldown = map.get('p2');
    const challengeableView = getBadgeView(map.get('p3'));

    expect(activeView).not.toBeNull();
    expect(activeView?.text).toBe('Repte actiu');
    expect(activeView?.label).toBe('Repte actiu');

    expect(cooldown).not.toBeNull();
    expect(cooldown?.in_cooldown).toBe(true);
    expect(cooldown?.cooldown_days_left).toBe(3);
    expect(getBadgeView(cooldown)).toBeNull();

    expect(challengeableView).not.toBeNull();
    expect(challengeableView?.text).toBe('Es pot reptar');
    expect(challengeableView?.label).toBe('Es pot reptar');
  });

  it('produces consistent markup for the three badge states', async () => {
    const map = await fetchBadgeMap(async () => badgeFixtures);
    const html = badgeFixtures
      .map((badge) => {
        if (badge.in_cooldown) {
          const days = badge.cooldown_days_left;
          const article = days === 1 ? 'a' : 'en';
          const unit = days === 1 ? 'dia' : 'dies';
          return `<span class="px-2 py-0.5 text-xs rounded bg-orange-100 text-orange-700">No es pot reptar (falt${article} ${days} ${unit})</span>`;
        }
        const view = getBadgeView(map.get(badge.player_id));
        if (!view) return '';
        return `<span class="${view.className}" aria-label="${view.label}">${view.text}</span>`;
      })
      .join('');

    expect(html).toMatchSnapshot();
  });

  it('returns null when there is no badge information', () => {
    expect(getBadgeView(undefined)).toBeNull();
    expect(getBadgeView(null)).toBeNull();
  });
});
