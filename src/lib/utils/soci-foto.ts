import { supabase } from '$lib/supabaseClient';

const BUCKET = 'socis-fotos';
const SIGNED_URL_TTL_SECONDS = 3600; // 1h
const CACHE_TTL_MS = 55 * 60 * 1000; // 55 min (5 min de marge respecte el TTL de Supabase)

type CacheEntry = { url: string; expires: number };
const urlCache = new Map<string, CacheEntry>();

let fotoPathsPromise: Promise<Map<number, string | null>> | null = null;
let fotoPathsFetchedAt = 0;
const PATHS_CACHE_TTL_MS = 2 * 60 * 1000; // 2 min

/**
 * Obté (i cacheja) totes les foto_path dels socis que tenen foto.
 * Una sola crida per sessió (refrescada cada 2 min).
 */
export async function getAllFotoPaths(): Promise<Map<number, string | null>> {
  const now = Date.now();
  if (fotoPathsPromise && now - fotoPathsFetchedAt < PATHS_CACHE_TTL_MS) {
    return fotoPathsPromise;
  }

  fotoPathsFetchedAt = now;
  fotoPathsPromise = (async () => {
    const { data, error } = await supabase
      .from('socis')
      .select('numero_soci, foto_path')
      .not('foto_path', 'is', null);

    if (error) {
      console.error('Error carregant foto_paths:', error);
      return new Map();
    }

    return new Map((data ?? []).map((s) => [s.numero_soci, s.foto_path]));
  })();

  return fotoPathsPromise;
}

/**
 * Retorna una signed URL per la foto d'un soci. Usa cache en memòria.
 * Retorna `null` si: no hi ha foto, no tens permisos (admin), o la BD falla.
 */
export async function getSociFotoUrl(fotoPathOrNumero: string | number): Promise<string | null> {
  let path: string | null = null;

  if (typeof fotoPathOrNumero === 'number') {
    const paths = await getAllFotoPaths();
    path = paths.get(fotoPathOrNumero) ?? null;
  } else {
    path = fotoPathOrNumero;
  }

  if (!path) return null;

  const now = Date.now();
  const cached = urlCache.get(path);
  if (cached && cached.expires > now) {
    return cached.url;
  }

  const { data, error } = await supabase.storage
    .from(BUCKET)
    .createSignedUrl(path, SIGNED_URL_TTL_SECONDS);

  if (error || !data?.signedUrl) {
    return null;
  }

  urlCache.set(path, { url: data.signedUrl, expires: now + CACHE_TTL_MS });
  return data.signedUrl;
}

/**
 * Invalida la cache (útil després de pujar/eliminar una foto).
 */
export function invalidateSociFotoCache(): void {
  urlCache.clear();
  fotoPathsPromise = null;
  fotoPathsFetchedAt = 0;
}
