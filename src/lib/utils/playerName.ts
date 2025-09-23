const CONNECTOR_WORDS = new Set([
  'de',
  'del',
  'la',
  'les',
  'lo',
  'los',
  'las',
  'el',
  'els',
  'van',
  'von',
  'da',
  'das',
  'dos',
  'des',
  'dei',
  'della',
  'dalla',
  'delle',
  'dello',
  'degli',
  'di',
  'do',
  'y',
  'i'
]);

function normalizeConnector(part: string): string {
  return part
    .trim()
    .toLowerCase()
    .replace(/[’']/g, '');
}

function splitParts(value: string): string[] {
  return value
    .trim()
    .split(/[\s-]+/)
    .map((part) => part.trim())
    .filter((part) => part.length > 0);
}

function buildInitials(parts: string[]): string {
  if (parts.length === 0) return '';

  const filtered = parts.filter((part) => !CONNECTOR_WORDS.has(normalizeConnector(part)));
  const relevant = filtered.length > 0 ? filtered : parts.slice(0, 1);

  return relevant
    .map((part) => part.charAt(0).toLocaleUpperCase('ca'))
    .join('.');
}

function extractFirstSurname(cognoms: string): string {
  const parts = splitParts(cognoms);
  if (parts.length === 0) return '';

  const surnameParts: string[] = [];
  for (const part of parts) {
    surnameParts.push(part);
    if (!CONNECTOR_WORDS.has(normalizeConnector(part))) {
      break;
    }
  }

  return surnameParts.join(' ');
}

/**
 * Format a player name as "Inicials. Primer cognom". Works with composed names
 * and surnames that include connector words (de, del, van, ...).
 */
export function formatPlayerDisplayName(nom: string, cognoms?: string | null): string {
  const safeNom = nom?.trim() ?? '';
  const safeCognoms = cognoms?.trim() ?? '';

  if (!safeNom && !safeCognoms) {
    return '';
  }

  const firstNameParts = splitParts(safeNom);
  const initials = buildInitials(firstNameParts);

  if (safeCognoms) {
    const surname = extractFirstSurname(safeCognoms);
    if (initials && surname) return `${initials}. ${surname}`;
    if (initials) return `${initials}.`;
    return surname;
  }

  if (firstNameParts.length === 1) {
    return firstNameParts[0];
  }

  const surnameFallback = firstNameParts[firstNameParts.length - 1];
  const givenNames = firstNameParts.slice(0, -1);
  const fallbackInitials = buildInitials(givenNames);

  if (fallbackInitials && surnameFallback) {
    return `${fallbackInitials}. ${surnameFallback}`;
  }

  return safeNom;
}
