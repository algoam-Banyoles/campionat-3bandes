/**
 * Punt d'entrada de la capa d'adaptadors de gestió unificada de partides.
 *
 * Re-exporta els tipus, els adaptadors individuals i `loadAllMatches`:
 * una funció que executa tots els adaptadors en paral·lel i fusiona els
 * resultats. Un origen caigut NO buida la llista (usa Promise.allSettled).
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import type { UnifiedMatch, MatchSource, AdapterError, MatchAdapter } from './types';
import { socialAdapter } from './socialAdapter';
import { continuAdapter } from './continuAdapter';
import { handicapAdapter } from './handicapAdapter';

// Re-exports de tipus
export type { UnifiedMatch, MatchSource, AdapterError, MatchAdapter };
export type {
  UnifiedPlayer,
  UnifiedSlot,
  UnifiedStatus,
  UnifiedCapabilities,
  UnifiedMeta,
  SocialMeta,
  ContinuMeta,
  HandicapMeta,
  ResultInput,
  SocialResultInput,
  SocialNoShowInput,
  ContinuResultInput,
  HandicapResultInput,
  EnterResultResponse
} from './types';

// Re-exports d'adaptadors (per si algun caller vol cridar-los directament)
export { socialAdapter, continuAdapter, handicapAdapter };

// ── Registre d'adaptadors ──────────────────────────────────────────────────

export const adapters: Record<MatchSource, MatchAdapter> = {
  social: socialAdapter,
  continu: continuAdapter,
  handicap: handicapAdapter
};

// ── Opcions de càrrega ─────────────────────────────────────────────────────

export interface LoadAllMatchesOpts {
  /**
   * Si true, inclou les partides jugades (per a vistes d'historial).
   * Per defecte false (vista operativa: pendents + programades).
   */
  includeJugades?: boolean;
  /**
   * Subconjunt d'orígens a carregar. Per defecte tots tres.
   */
  sources?: MatchSource[];
}

// ── Resultat de loadAllMatches ─────────────────────────────────────────────

export interface LoadAllMatchesResult {
  matches: UnifiedMatch[];
  /** Errors per origen (un origen caigut no impedeix mostrar els altres) */
  errors: AdapterError[];
}

// ── Funció principal ───────────────────────────────────────────────────────

/**
 * Executa tots els adaptadors (o un subconjunt) en paral·lel i fusiona els
 * resultats en una llista única. Si un adaptador falla, l'error es recull a
 * `errors` però els altres orígens continuen mostrant-se.
 */
export async function loadAllMatches(
  supabase: SupabaseClient,
  opts: LoadAllMatchesOpts = {}
): Promise<LoadAllMatchesResult> {
  const { includeJugades = false, sources = ['social', 'continu', 'handicap'] } = opts;

  const results = await Promise.allSettled(
    sources.map((source) =>
      adapters[source].listMatches(supabase, includeJugades).then((matches) => ({ source, matches }))
    )
  );

  const matches: UnifiedMatch[] = [];
  const errors: AdapterError[] = [];

  for (const result of results) {
    if (result.status === 'fulfilled') {
      matches.push(...result.value.matches);
    } else {
      // Detectar quin source ha fallat (l'ordre és el mateix que sources[])
      const idx = results.indexOf(result);
      const source = sources[idx] ?? 'social';
      errors.push({
        source,
        message: result.reason instanceof Error ? result.reason.message : String(result.reason)
      });
    }
  }

  return { matches, errors };
}
