import { base } from '$app/paths';

/**
 * Carrega el SVG del logo del club com a text per incrustar-lo amb {@html}.
 * Fer-ho inline elimina dependència de URLs absolutes (necessaria per a la
 * finestra emergent d'impressió, que no té base URL i no resol /logo-billar.svg).
 *
 * Retorna cadena buida si falla — el modal hauria de funcionar igualment.
 */
export async function loadLogoSvg(): Promise<string> {
	try {
		const r = await fetch(`${base}/logo-billar.svg`);
		if (!r.ok) return '';
		const text = await r.text();
		// Eliminar amplada/altura fixes del SVG perquè s'adapti al contenidor.
		return text
			.replace(/\swidth="[^"]*"/i, '')
			.replace(/\sheight="[^"]*"/i, '');
	} catch {
		return '';
	}
}
