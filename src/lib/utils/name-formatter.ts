/**
 * Partícules que NO generen inicial en el nom propi
 * (preposicions i articles àtons en català/castellà)
 */
const PARTICLES = new Set([
	'de', 'del', 'd\'', 'des', 'el', 'la', 'les', 'los', 'dels', 'l\'',
	'en', 'i', 'y', 'al', 'da', 'das', 'do', 'dos', 'e'
]);

function isParticle(word: string): boolean {
	return PARTICLES.has(word.toLowerCase());
}

/**
 * Retorna el nom en format curt: inicials del nom + primer cognom.
 *
 * Exemples:
 *   shortName('Joan', 'Garcia López')        → 'J. Garcia'
 *   shortName('Joan Pere', 'Garcia')         → 'J.P. Garcia'
 *   shortName('Maria del Mar', 'López')      → 'M.M. López'
 *   shortName('Juan', 'de la Cruz Santos')   → 'J. de la Cruz'
 */
export function shortName(nom: string, cognoms: string): string {
	// Inicials: filtrar partícules, prendre la primera lletra de cada paraula significant
	const nomWords = nom.trim().split(/\s+/);
	const initials = nomWords
		.filter((w) => w.length > 0 && !isParticle(w))
		.map((w) => w.charAt(0).toUpperCase() + '.')
		.join('');

	// Primer cognom: recollir partícules inicials + primera paraula significativa
	const cognomsWords = cognoms.trim().split(/\s+/);
	let i = 0;
	let firstSurname = '';
	while (i < cognomsWords.length && isParticle(cognomsWords[i])) {
		firstSurname += cognomsWords[i] + ' ';
		i++;
	}
	if (i < cognomsWords.length) {
		firstSurname += cognomsWords[i];
	}
	firstSurname = firstSurname.trim() || cognoms.trim();

	if (!initials) return firstSurname;
	return `${initials} ${firstSurname}`;
}
