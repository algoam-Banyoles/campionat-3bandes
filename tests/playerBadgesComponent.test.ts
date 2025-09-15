import { describe, it, expect, vi } from 'vitest';
import type { PlayerBadgeState } from '../src/lib/playerBadges';
import { buildBadgeDescriptors } from '../src/lib/playerBadges';

const baseRow = { player_id: 'player-1' };

const runWith = (states: PlayerBadgeState[]) => {
  const provider = vi.fn().mockReturnValue(states);
  const badges = buildBadgeDescriptors(baseRow as any, provider);
  expect(provider).toHaveBeenCalledWith(baseRow);
  return badges;
};

describe('PlayerBadges descriptors', () => {
  it('creates active challenge badge descriptor', () => {
    const [badge] = runWith([{ type: 'active-challenge' }]);
    expect(badge.element).toBe('span');
    expect(badge.text).toBe('Té repte actiu');
    expect(badge.ariaLabel).toBe('Aquest jugador té un repte actiu (no pot iniciar-ne cap altre).');
    expect(badge.className).toContain('bg-red-600');
  });

  it('creates cooldown badge descriptor', () => {
    const [badge] = runWith([{ type: 'cooldown' }]);
    expect(badge.text).toBe('No pot reptar');
    expect(badge.ariaLabel).toBe('En cooldown fins passats 7 dies del darrer repte disputat.');
    expect(badge.className).toContain('bg-yellow-300');
  });

  it('creates can-challenge descriptor for self', () => {
    const [badge] = runWith([{ type: 'can-challenge' }]);
    expect(badge.text).toBe('Pot reptar');
    expect(badge.ariaLabel).toBe('Pots reptar fins a 2 posicions per sobre teu.');
    expect(badge.className).toContain('bg-green-600');
  });

  it('creates enabled reptable descriptor', () => {
    const states: PlayerBadgeState[] = [{ type: 'reptable', canChallenge: true, reason: 'Disponible' }];
    const [badge] = runWith(states);
    expect(badge.element).toBe('button');
    expect(badge.text).toBe('Reptable');
    expect(badge.ariaLabel).toBe('Aquest jugador és reptable per tu ara mateix.');
    expect(badge.disabled).toBe(false);
  });

  it('creates disabled reptable descriptor', () => {
    const states: PlayerBadgeState[] = [{ type: 'reptable', canChallenge: false, reason: 'No pots reptar' }];
    const [badge] = runWith(states);
    expect(badge.disabled).toBe(true);
    expect(badge.ariaLabel).toBe('No pots reptar');
  });

  it('creates protected descriptor', () => {
    const [badge] = runWith([{ type: 'protected' }]);
    expect(badge.text).toBe('Protegit');
    expect(badge.ariaLabel).toBe('Protegit (cooldown de ser reptat)');
    expect(badge.className).toContain('bg-gray-400');
  });

  it('creates outside descriptor', () => {
    const [badge] = runWith([{ type: 'outside' }]);
    expect(badge.text).toBe('Fora de rànquing actiu');
    expect(badge.ariaLabel).toBe('Fora de rànquing actiu');
    expect(badge.className).toContain('bg-gray-200');
  });

  it('creates self descriptor', () => {
    const [badge] = runWith([{ type: 'self' }]);
    expect(badge.text).toBe('Tu');
    expect(badge.ariaLabel).toBe('Tu');
    expect(badge.className).toContain('bg-yellow-400');
  });

  it('matches snapshot for multiple badges', () => {
    const states: PlayerBadgeState[] = [
      { type: 'self' },
      { type: 'active-challenge' },
      { type: 'protected' }
    ];
    const provider = vi.fn().mockReturnValue(states);
    const badges = buildBadgeDescriptors(baseRow as any, provider).map(({ state, element, text, ariaLabel, className, disabled }) => ({
      state,
      element,
      text,
      ariaLabel,
      className,
      disabled: disabled ?? false
    }));
    expect(badges).toMatchSnapshot();
  });
});
