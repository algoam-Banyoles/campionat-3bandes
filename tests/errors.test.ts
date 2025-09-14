import { describe, it, expect, vi } from 'vitest';
import { mapError, wrapRpc } from '../src/lib/errors';

describe('error mapping', () => {
  const cases: [string, string][] = [
    ['No es pot reptar a un mateix', 'No et pots reptar a tu mateix'],
    ["L'event no és actiu", 'Event inactiu'],
    ['El reptador no és un jugador actiu', 'Reptador inactiu'],
    ['El reptat no és un jugador actiu', 'Reptat inactiu'],
    ["El reptador no està al rànquing de l'event", 'El reptador no és al rànquing'],
    ["El reptat no està al rànquing de l'event", 'El reptat no és al rànquing'],
    ['Només es pot reptar fins a 2 posicions per sobre', 'Diferència de posicions massa gran'],
    ['El reptador o el reptat ja té un repte actiu', 'Ja hi ha un repte actiu'],
    ["Has d'esperar 3 dies més", 'Temps mínim entre reptes no complert'],
    ["S'ha excedit el temps màxim entre reptes jugats", 'Temps màxim entre reptes excedit'],
    ['no_player_behind', 'No es pot aplicar la penalització: no hi ha cap jugador darrere…'],
    ['No hi ha cap jugador darrere', 'No es pot aplicar la penalització: no hi ha cap jugador darrere…']
  ];

  for (const [input, output] of cases) {
    it(`maps "${input}"`, () => {
      expect(mapError(input)).toBe(output);
    });
  }

  it('wrapRpc maps error and reason', async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: { ok: false, reason: 'No es pot reptar a un mateix', warning: "S'ha excedit el temps màxim entre reptes jugats" },
      error: { message: "Has d'esperar 1 dies més" }
    });
    const client: any = { rpc };
    wrapRpc(client);
    const res = await client.rpc('fn');
    expect(res.error.message).toBe('Temps mínim entre reptes no complert');
    expect(res.data.reason).toBe('No et pots reptar a tu mateix');
    expect(res.data.warning).toBe('Temps màxim entre reptes excedit');
  });
});
