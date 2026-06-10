export const ERROR_MESSAGES: Record<string, string> = {
  'No es pot reptar a un mateix': 'No et pots reptar a tu mateix',
  'no_self_challenge': 'No et pots reptar a tu mateix',
  "L'event no és actiu": 'Event inactiu',
  event_inactive: 'Event inactiu',
  'El reptador no és un jugador actiu': 'Reptador inactiu',
  challenger_inactive: 'Reptador inactiu',
  'El reptat no és un jugador actiu': 'Reptat inactiu',
  challenged_inactive: 'Reptat inactiu',
  "El reptador no està al rànquing de l'event": 'El reptador no és al rànquing',
  challenger_not_in_ranking: 'El reptador no és al rànquing',
  "El reptat no està al rànquing de l'event": 'El reptat no és al rànquing',
  challenged_not_in_ranking: 'El reptat no és al rànquing',
  rank_gap_too_big: 'Diferència de posicions massa gran',
  active_challenge_exists: 'Ja hi ha un repte actiu',
  cooldown_min_not_met: 'Temps mínim entre reptes no complert',
  cooldown_max_exceeded: 'Temps màxim entre reptes excedit',
  no_player_behind: 'No es pot aplicar la penalització: no hi ha cap jugador darrere…'
};

export function mapError(reason?: string | null): string | undefined {
  if (!reason) return reason ?? undefined;
  const direct = ERROR_MESSAGES[reason];
  if (direct) return direct;
  if (reason.startsWith('Només es pot reptar')) {
    return ERROR_MESSAGES['rank_gap_too_big'];
  }
  if (reason.startsWith("Has d'esperar")) {
    return ERROR_MESSAGES['cooldown_min_not_met'];
  }
  if (reason.startsWith('El reptador o el reptat ja té un repte actiu')) {
    return ERROR_MESSAGES['active_challenge_exists'];
  }
  if (reason.startsWith("S'ha excedit el temps màxim")) {
    return ERROR_MESSAGES['cooldown_max_exceeded'];
  }
  if (reason.startsWith('No hi ha cap jugador darrere')) {
    return ERROR_MESSAGES['no_player_behind'];
  }
  return reason;
}

export function wrapRpc<T extends { rpc: Function }>(client: T): T {
  const original = client.rpc.bind(client);
  client.rpc = async (fn: string, params?: any, options?: any) => {
    const res = await original(fn, params, options);
    if (res?.error?.message) {
      res.error.message = mapError(res.error.message);
    }
    const apply = (obj: any) => {
      if (obj && typeof obj === 'object') {
        if ('reason' in obj && typeof obj.reason === 'string') {
          obj.reason = mapError(obj.reason);
        }
        if ('warning' in obj && typeof obj.warning === 'string') {
          obj.warning = mapError(obj.warning);
        }
      }
    };
    if (Array.isArray(res?.data)) res.data.forEach(apply);
    else apply(res?.data);
    return res;
  };
  return client;
}
