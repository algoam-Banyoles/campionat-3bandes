/**
 * Helpers de cerca/format de jugadors al calendari de campionats socials.
 * Extrets de `SocialLeagueCalendarViewer.svelte` per a fer-los testables.
 */

export interface JugadorLike {
  nom?: string | null;
  cognoms?: string | null;
  numero_soci?: number | string | null;
  socis?: { nom?: string | null; cognoms?: string | null } | null;
  [key: string]: any;
}

export interface PlayerSuggestion {
  id: number | string;
  jugador: JugadorLike;
  displayName: string;
}

/**
 * Format curt: "I. Cognom" (inicial del nom + primer cognom).
 * Si no es troben dades, retorna el text per defecte.
 */
export function formatPlayerName(jugador: JugadorLike | string | null | undefined): string {
  if (!jugador) return 'Jugador desconegut';

  let playerData: JugadorLike;
  if (typeof jugador === 'string') {
    try {
      playerData = JSON.parse(jugador);
    } catch {
      return jugador;
    }
  } else {
    playerData = jugador;
  }

  if (playerData.nom && playerData.cognoms) {
    return shortName(playerData.nom, playerData.cognoms);
  }

  if (playerData.socis?.nom && playerData.socis?.cognoms) {
    return shortName(playerData.socis.nom, playerData.socis.cognoms);
  }

  if (playerData.nom) return playerData.nom;

  return 'Nom no disponible';
}

function shortName(nom: string, cognoms: string): string {
  const inicialNom = nom.trim().charAt(0).toUpperCase();
  const primerCognom = cognoms.trim().split(' ')[0];
  return `${inicialNom}. ${primerCognom}`;
}

/**
 * Comprova si una partida implica un jugador concret pel seu `soci_numero`.
 */
export function matchPlayerById(match: any, playerId: string | number): boolean {
  return (
    match?.jugador1_soci_numero === playerId ||
    match?.jugador2_soci_numero === playerId
  );
}

/**
 * Comprova si un jugador encaixa amb un text de cerca (case-insensitive).
 * Suporta dades antigues (`nom`/`cognoms` planes) i noves (via FK `socis`).
 */
export function matchPlayerSearchText(jugador: JugadorLike | string | null | undefined, searchLower: string): boolean {
  if (!jugador) return false;

  let playerData: JugadorLike;
  if (typeof jugador === 'string') {
    try {
      playerData = JSON.parse(jugador);
    } catch {
      return jugador.toLowerCase().includes(searchLower);
    }
  } else {
    playerData = jugador;
  }

  if (playerData.socis?.nom && playerData.socis?.cognoms) {
    const nomComplet = `${playerData.socis.nom} ${playerData.socis.cognoms}`.toLowerCase();
    if (nomComplet.includes(searchLower)) return true;
    if (playerData.socis.nom.toLowerCase().includes(searchLower)) return true;
    if (playerData.socis.cognoms.toLowerCase().includes(searchLower)) return true;
  }

  if (playerData.numero_soci && String(playerData.numero_soci).includes(searchLower)) return true;

  if (playerData.nom && playerData.cognoms) {
    const nomComplet = `${playerData.nom} ${playerData.cognoms}`.toLowerCase();
    if (nomComplet.includes(searchLower)) return true;
  }

  if (playerData.nom && playerData.nom.toLowerCase().includes(searchLower)) return true;
  if (playerData.cognoms && playerData.cognoms.toLowerCase().includes(searchLower)) return true;

  return false;
}

/**
 * Genera fins a 10 suggeriments de jugadors únics que coincideixen amb el text.
 */
export function generatePlayerSuggestions(matches: any[], searchText: string): PlayerSuggestion[] {
  if (searchText.length < 2) return [];

  const searchLower = searchText.toLowerCase().trim();
  const uniquePlayers = new Map<string | number, PlayerSuggestion>();

  for (const match of matches) {
    const sides = [
      { jugador: match.jugador1, sociNumero: match.jugador1_soci_numero },
      { jugador: match.jugador2, sociNumero: match.jugador2_soci_numero }
    ];
    for (const { jugador, sociNumero } of sides) {
      if (!jugador || !sociNumero) continue;
      if (uniquePlayers.has(sociNumero)) continue;
      if (matchPlayerSearchText(jugador, searchLower)) {
        uniquePlayers.set(sociNumero, {
          id: sociNumero,
          jugador,
          displayName: formatPlayerName(jugador)
        });
      }
    }
  }

  return Array.from(uniquePlayers.values())
    .sort((a, b) => a.displayName.localeCompare(b.displayName))
    .slice(0, 10);
}
