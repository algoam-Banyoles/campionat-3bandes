/**
 * Utilitats per al formatatge de noms de jugadors
 */

/**
 * Formateja el nom complet d'un jugador a format: Inicials + Primer cognom
 *
 * Exemples:
 * - "Albert Gómez Ametller" -> "A. Gómez"
 * - "José María Campos Gonzalez" -> "J. M. Campos"
 * - "Juan Felix Santos Gonzalez" -> "J. F. Santos"
 *
 * @param nomComplet - El nom complet del jugador
 * @returns El nom formatat amb inicials i primer cognom
 */
export function formatarNomJugador(nomComplet: string): string {
  if (!nomComplet || nomComplet.trim() === '') {
    return '';
  }

  const parts = nomComplet.trim().split(/\s+/);

  if (parts.length === 0) {
    return '';
  }

  if (parts.length === 1) {
    // Si només hi ha una paraula, retorna-la tal com està
    return parts[0];
  }

  // Separar noms i cognoms
  // Assumim que l'últim segment és sempre un cognom
  const cognoms = [parts[parts.length - 1]];
  const noms = parts.slice(0, -1);

  // Si hi ha més d'una paraula abans de l'últim cognom, assumim que el penúltim també és cognom
  if (parts.length > 2) {
    cognoms.unshift(parts[parts.length - 2]);
    noms.pop(); // Treiem el penúltim del array de noms
  }

  // Crear inicials dels noms
  const inicials = noms
    .map(nom => nom.charAt(0).toUpperCase() + '.')
    .join(' ');

  // Primer cognom
  const primerCognom = cognoms[0];

  return `${inicials} ${primerCognom}`;
}

/**
 * Formateja una llista de jugadors aplicant el format estàndard
 *
 * @param jugadors - Array d'objectes jugador amb propietat 'nom'
 * @returns Array amb els noms formatats
 */
export function formatarLlistaJugadors<T extends { nom: string }>(
  jugadors: T[]
): (T & { nomFormatat: string })[] {
  return jugadors.map(jugador => ({
    ...jugador,
    nomFormatat: formatarNomJugador(jugador.nom)
  }));
}

/**
 * Obté les inicials d'un nom complet (només les lletres inicials sense punts)
 *
 * @param nomComplet - El nom complet del jugador
 * @returns Les inicials sense punts (ex: "AGM" per "Albert Gómez Ametller")
 */
export function obtenirInicials(nomComplet: string): string {
  if (!nomComplet || nomComplet.trim() === '') {
    return '';
  }

  return nomComplet
    .trim()
    .split(/\s+/)
    .map(part => part.charAt(0).toUpperCase())
    .join('');
}

/**
 * Verifica si un nom té un format vàlid per al formateig
 *
 * @param nomComplet - El nom complet del jugador
 * @returns true si el nom es pot formatar correctament
 */
export function esNomValid(nomComplet: string): boolean {
  if (!nomComplet || nomComplet.trim() === '') {
    return false;
  }

  const parts = nomComplet.trim().split(/\s+/);
  return parts.length >= 2; // Mínim nom + cognom
}