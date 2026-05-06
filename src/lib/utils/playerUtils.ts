/**
 * Utilitats per al formatatge de noms de jugadors
 */

/**
 * Formateja el nom complet d'un jugador a format: Inicials + Primer cognom
 *
 * Detecta el connector català "i" entre els dos cognoms i el tracta correctament.
 *
 * Exemples:
 * - "Albert Gómez Ametller" -> "A. Gómez"
 * - "Joan Garcia i Pujol" -> "J. Garcia"   (format català amb "i")
 * - "José María Campos Gonzalez" -> "J. M. Campos"
 * - "Francesc Pi i Margall" -> "F. Pi"
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
    return parts[0];
  }

  // Detectar el connector català "i" (en minúscula i envoltat d'altres paraules).
  // Format típic: "Nom [Nom2…] Cognom1 i Cognom2"
  const iIndex = parts.findIndex(
    (p, i) => i > 0 && i < parts.length - 1 && p.toLowerCase() === 'i'
  );

  let noms: string[];
  let cognoms: string[];

  if (iIndex > 0) {
    // Cas català: tot el que hi ha just abans de "i" és el primer cognom;
    // la resta a l'esquerra (excloent el primer cognom) són noms.
    noms = parts.slice(0, iIndex - 1);
    cognoms = [parts[iIndex - 1], parts.slice(iIndex + 1).join(' ')];
  } else {
    // Format estàndard: assumim que l'últim segment és cognom; si hi ha 3+ parts,
    // també tractem el penúltim com a cognom (cas dos cognoms sense "i").
    cognoms = [parts[parts.length - 1]];
    noms = parts.slice(0, -1);

    if (parts.length > 2) {
      cognoms.unshift(parts[parts.length - 2]);
      noms.pop();
    }
  }

  // Si tot són cognoms (cas degenerat: nom complet sense nom de pila), retornem
  // només el primer cognom — és el màxim que podem inferir.
  if (noms.length === 0) {
    return cognoms[0];
  }

  const inicials = noms
    .map(nom => nom.charAt(0).toUpperCase() + '.')
    .join(' ');

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
 * Tipus laxe per als camps mínims d'un soci necessaris per formatar el nom.
 * Acceptem null/undefined perquè els JOINs de Supabase poden retornar valors
 * absents quan la relació és opcional.
 */
export type SociNomLike = {
  nom?: string | null;
  cognoms?: string | null;
} | null | undefined;

/**
 * Construeix el nom complet (`nom + cognoms`) a partir d'un objecte amb camps
 * de soci. Retorna cadena buida si no hi ha dades. Cal usar-la sempre que
 * tinguem un JOIN tipus `players(socis(nom, cognoms))` en lloc de llegir
 * `players.nom` (que pot estar desincronitzat — vegeu Fase 5a a quality-baseline).
 */
export function nomComplertSoci(soci: SociNomLike): string {
  if (!soci) return '';
  return `${soci.nom ?? ''} ${soci.cognoms ?? ''}`.trim();
}

/**
 * Igual que `nomComplertSoci` però aplicant `formatarNomJugador` (inicials +
 * primer cognom).
 */
export function nomFormatatSoci(soci: SociNomLike): string {
  return formatarNomJugador(nomComplertSoci(soci));
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