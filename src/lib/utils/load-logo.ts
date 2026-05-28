import { base } from '$app/paths';

/**
 * Carrega el logo del club com a data URL (base64). Així es pot incrustar
 * directament al <img src> i no depèn de cap URL externa, fet que garanteix
 * que es vegi correctament a la finestra emergent d'impressió.
 *
 * Retorna cadena buida si falla — els modals tenen fallback a la URL directa.
 */
export async function loadLogoDataUrl(): Promise<string> {
	try {
		const r = await fetch(`${base}/logo.png`);
		if (!r.ok) return '';
		const blob = await r.blob();
		return await new Promise<string>((resolve, reject) => {
			const reader = new FileReader();
			reader.onloadend = () => resolve(reader.result as string);
			reader.onerror = reject;
			reader.readAsDataURL(blob);
		});
	} catch {
		return '';
	}
}

/** @deprecated Es manté per compatibilitat. Usa loadLogoDataUrl. */
export async function loadLogoSvg(): Promise<string> {
	return loadLogoDataUrl();
}
