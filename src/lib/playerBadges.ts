export type PlayerBadgeSource = {
  player_id: string;
  isMe?: boolean;
  hasActiveChallenge?: boolean;
  cooldownToChallenge?: boolean;
  reptable?: boolean;
  canChallenge?: boolean;
  reason?: string | null;
  protected?: boolean;
  outside?: boolean;
};

export type PlayerBadgeState =
  | { type: 'self' }
  | { type: 'active-challenge' }
  | { type: 'cooldown' }
  | { type: 'can-challenge' }
  | { type: 'reptable'; canChallenge: boolean; reason: string | null }
  | { type: 'protected' }
  | { type: 'outside' };

export function getPlayerBadges(row: PlayerBadgeSource): PlayerBadgeState[] {
  const badges: PlayerBadgeState[] = [];

  if (row.isMe) {
    badges.push({ type: 'self' });
  }

  if (row.hasActiveChallenge) {
    badges.push({ type: 'active-challenge' });
  } else if (row.cooldownToChallenge) {
    badges.push({ type: 'cooldown' });
  } else if (row.isMe) {
    badges.push({ type: 'can-challenge' });
  } else if (row.reptable) {
    badges.push({
      type: 'reptable',
      canChallenge: !!row.canChallenge,
      reason: row.reason ?? null
    });
  }

  if (row.protected) {
    badges.push({ type: 'protected' });
  }

  if (row.outside) {
    badges.push({ type: 'outside' });
  }

  return badges;
}

export type PlayerBadgeDescriptor = {
  state: PlayerBadgeState['type'];
  element: 'span' | 'button';
  className: string;
  text: string;
  title: string;
  ariaLabel: string;
  disabled?: boolean;
};

const CLASS_BY_TYPE: Record<PlayerBadgeState['type'], string> = {
  self:
    'ml-1 inline-block rounded-full bg-yellow-400 px-2.5 py-1 text-xs font-medium text-gray-900 align-middle',
  'active-challenge':
    'ml-1 inline-block rounded-full bg-red-600 px-2.5 py-1 text-xs font-medium text-white align-middle',
  cooldown:
    'ml-1 inline-block rounded-full bg-yellow-300 px-2.5 py-1 text-xs font-medium text-gray-900 align-middle',
  'can-challenge':
    'ml-1 inline-block rounded-full bg-green-600 px-2.5 py-1 text-xs font-medium text-white align-middle',
  reptable:
    'ml-1 rounded-full bg-blue-600 px-2.5 py-1 text-xs font-medium text-white align-middle disabled:opacity-50',
  protected:
    'ml-1 inline-block rounded-full bg-gray-400 px-2.5 py-1 text-xs font-medium text-white align-middle',
  outside:
    'ml-1 inline-block rounded-full bg-gray-200 px-2.5 py-1 text-xs font-medium text-gray-800 align-middle'
};

const TEXT_BY_TYPE: Record<PlayerBadgeState['type'], string> = {
  self: 'Tu',
  'active-challenge': 'Té repte actiu',
  cooldown: 'No pot reptar',
  'can-challenge': 'Pot reptar',
  reptable: 'Reptable',
  protected: 'Protegit',
  outside: 'Fora de rànquing actiu'
};

const TITLE_BY_TYPE = (
  badge: PlayerBadgeState
): string => {
  switch (badge.type) {
    case 'self':
      return 'Tu';
    case 'active-challenge':
      return 'Aquest jugador té un repte actiu (no pot iniciar-ne cap altre).';
    case 'cooldown':
      return 'En cooldown fins passats 7 dies del darrer repte disputat.';
    case 'can-challenge':
      return 'Pots reptar fins a 2 posicions per sobre teu.';
    case 'reptable':
      return badge.canChallenge
        ? 'Aquest jugador és reptable per tu ara mateix.'
        : badge.reason ?? 'No pots reptar';
    case 'protected':
      return 'Protegit (cooldown de ser reptat)';
    case 'outside':
      return 'Fora de rànquing actiu';
  }
  return '';
};

export function buildBadgeDescriptors(
  row: PlayerBadgeSource,
  provider: (source: PlayerBadgeSource) => PlayerBadgeState[] = getPlayerBadges
): PlayerBadgeDescriptor[] {
  return provider(row).map((badge) => {
    const title = TITLE_BY_TYPE(badge);
    return {
      state: badge.type,
      element: badge.type === 'reptable' ? 'button' : 'span',
      className: CLASS_BY_TYPE[badge.type],
      text: TEXT_BY_TYPE[badge.type],
      title,
      ariaLabel: title,
      disabled: badge.type === 'reptable' ? !badge.canChallenge : undefined
    } satisfies PlayerBadgeDescriptor;
  });
}
