# Prompt mestre — Sessions de testing per fases

Aquest document conté el prompt reutilitzable per iniciar qualsevol fase del pla de testing i millora de qualitat (`~/.claude/plans/velvet-napping-feather.md`).

## Com usar-lo

1. Obre una sessió nova de Claude Code dins el projecte.
2. Copia el prompt de baix.
3. Substitueix `{N}` pel número de fase i enganxa l'objectiu corresponent de la secció "Fases" més avall.
4. Envia.

---

## Prompt mestre

```
Ets un tester expert del projecte Campionat 3 Bandes (SvelteKit + Supabase PWA).
Llegeix CLAUDE.md i docs/quality-baseline.md per entendre l'estat actual.
Estem a la FASE {N} del pla descrit a ~/.claude/plans/velvet-napping-feather.md.

OBJECTIU D'AQUESTA FASE:
{ENGANXAR L'OBJECTIU DE LA FASE CORRESPONENT}

FITXERS CRÍTICS:
{ENGANXAR ELS FITXERS DE LA FASE CORRESPONENT}

RESTRICCIONS DURES:
- No tocar la taula `players` directament fins a Fase 5.
- Cap migració SQL sense passar per supabase/migrations/.
- Tota query nova ha de filtrar per event_id.
- Mantenir la terminologia del domini: billar, caramboles, entrades, distància (no
  "taula", "punts", "torns", "handicap" en context de puntuació).
- No introduir errors nous a `npm run check`. Línia base: 1 error / 99 warnings.
- Tot canvi de lògica nova necessita test Vitest. Tot canvi de flux d'usuari
  necessita test Playwright (a partir de Fase 4).
- No fer commits ni push sense permís explícit de l'usuari.

PROTOCOL D'INICI:
1. Executa `npm run check` i `npm test` i reporta l'estat actual.
2. Compara amb la línia base de docs/quality-baseline.md.
3. Si hi ha desviacions, atura't i pregunta abans de continuar.
4. Després planifica els canvis concrets en una llista de tasques visible amb
   TodoWrite.
5. Implementa pas a pas, marcant cada tasca com a completada immediatament.
6. Al final, torna a executar `npm run check` + `npm test` i actualitza
   docs/quality-baseline.md amb les noves mètriques.
```

---

## Fases (per copiar al placeholder)

### Fase 0 — Baseline mesurable
**Objectiu**: tenir mètriques abans de tocar res. Configurar `test:coverage`, afegir CI per `check`+`test`, crear `docs/quality-baseline.md` i aquest mateix prompt.
**Fitxers**: `package.json`, `.github/workflows/quality-check.yml`, `docs/quality-baseline.md`, `docs/testing-master-prompt.md`.

### Fase 1 — Hardening de connexió
**Objectiu**: eliminar penjades silencioses afegint timeouts amb `AbortController`, circuit breaker al `connectionManager` i errors tipats a `withSupabase`.
**Fitxers**:
- `src/lib/supabaseClient.ts`
- `src/lib/connection/connectionManager.ts`
- `src/lib/connection/syncManager.ts`
- `src/lib/utils/supabase.ts`

Tests nous: mock fetch que mai resol → ha d'avortar en 10s; reconnect offline→online dispara reintents.

### Fase 2 — Loading states i cleanup de subscripcions
**Objectiu**: cap pantalla atrapada en "Carregant...". Patró `AbortController` + `try/finally` a totes les pàgines amb `onMount` (per mòdul, no tot d'un cop).
**Fitxers prioritaris**:
- `src/routes/+page.svelte`
- `src/routes/handicap/quadre/+page.svelte`
- `src/routes/campionat-continu/ranking/+page.svelte`
- `src/lib/stores/notifications.ts`

### Fase 3 — Optimització dashboard
**Objectiu**: home < 1.5s a 4G mòbil. Paral·lelitzar queries, moure-les a `+page.ts` `load()`, SWR al calendar store, skeleton loaders.
**Fitxers**:
- `src/routes/+page.svelte`
- `src/routes/+page.ts` (a crear)
- `src/lib/stores/calendar.ts`

### Fase 4 — Cobertura E2E
**Objectiu**: Playwright + 5 fluxos crítics (login, crear repte, inscripció social, bracket hàndicap, dashboard).
**Fitxers**: `playwright.config.ts` (a crear), `e2e/*.spec.ts` (a crear).

### Fase 5 — Refactor `players` → `socis`
**Objectiu**: eliminar la taula `players` per fases via vista de compatibilitat. Sessió pròpia amb pla detallat propi.
**Fitxers crítics**:
- `src/lib/database/queries.ts`
- `src/lib/stores/rankingStore.ts`
- `src/lib/api/classifications.ts`
- `src/lib/services/inscriptionsService.ts`
- `supabase/migrations/*` (vista de compatibilitat + migració progressiva de FKs)
