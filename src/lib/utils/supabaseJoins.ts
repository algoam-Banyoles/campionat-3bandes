/**
 * Utilitats per a normalitzar respostes de Supabase amb joins via FK.
 *
 * Postgrest pot retornar relacions FK com a objecte únic o com a array
 * (depenent del tipus de relació detectat). Aquestes funcions normalitzen
 * el resultat sempre a un objecte únic (o `null`) per a evitar la lògica
 * `Array.isArray(...) ? rawS[0] : rawS` repetida arreu del codi.
 *
 * Veure CLAUDE.md secció "Patrons Supabase".
 */

/**
 * Resol una relació FK que pot venir com a objecte o array a un objecte únic.
 * Si l'array és buit o el valor és falsy retorna `null`.
 */
export function fkOne<T>(value: T | T[] | null | undefined): T | null {
  if (value == null) return null;
  if (Array.isArray(value)) return value[0] ?? null;
  return value;
}

/**
 * Subset mínim de `socis` que retornen els joins habituals (nom + cognoms).
 */
export interface SociJoin {
  nom: string | null;
  cognoms: string | null;
  numero_soci?: number | null;
  email?: string | null;
}

/**
 * Normalitza el camp `socis` d'una fila amb FK a un únic objecte amb els
 * camps `nom`/`cognoms`/`numero_soci` segurs (mai `undefined`).
 */
export function normalizeSociFromFK(value: unknown): SociJoin {
  const soci = fkOne(value as SociJoin | SociJoin[] | null | undefined);
  return {
    nom: soci?.nom ?? '',
    cognoms: soci?.cognoms ?? '',
    numero_soci: soci?.numero_soci ?? null,
    email: soci?.email ?? null
  };
}

/**
 * Construeix un nom complet "Nom Cognoms" a partir d'un join FK de socis.
 * Retorna cadena buida si no hi ha dades.
 */
export function fullNameFromFK(value: unknown): string {
  const s = normalizeSociFromFK(value);
  return `${s.nom ?? ''} ${s.cognoms ?? ''}`.trim();
}
