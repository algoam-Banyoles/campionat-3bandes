# Quality Baseline — Campionat 3 Bandes PWA

Línia base mesurada el **2026-04-07** abans d'iniciar el pla de testing per fases (`~/.claude/plans/velvet-napping-feather.md`).

## Mètriques globals

| Mètrica | Valor |
| --- | --- |
| Línies de codi totals (aprox.) | ~76.500 |
| Fitxers `.svelte` + `.ts` a `src/` | 272 |
| Mòdul més gran | `admin/` (~17.839 línies) |

## Tests (Vitest)

| Mètrica | Valor |
| --- | --- |
| Test files | 12 |
| Tests passing | 129 |
| Tests failing | 0 |
| Cobertura statements | **1.39%** (`npm run test:coverage`) |
| Cobertura branches | 31.9% |
| Cobertura functions | 8.9% |
| Tests E2E (Playwright) | 1 smoke test (`e2e/smoke.spec.ts`) |

## svelte-check

| Mètrica | Valor |
| --- | --- |
| Errors | 1 (pre-existent: `connectionManager.ts` `handleOfflineEvent` — no tocar) |
| Warnings | 99 (majoritàriament CSS unused selectors pre-existents) |
| Fitxers afectats | 16 |

**Regla**: una fase no es considera completada si introdueix **errors o warnings nous**. La línia base és `1 error / 99 warnings`.

## CI

| Workflow | Estat |
| --- | --- |
| `supabase-deploy-prod.yml` | ✅ existent |
| `supabase-validate-pr.yml` | ✅ existent |
| `quality-check.yml` (nou, Fase 0) | ✅ afegit — executa `npm run check` + `npm test` a cada PR |

## Pendents Fase 0 (no automatitzat)

Aquestes mètriques són manuals — cal capturar-les una vegada amb DevTools / Lighthouse i anotar-les aquí:

- [ ] Temps de càrrega home en **Slow 3G** (Chrome DevTools → Network throttling).
- [ ] Lighthouse mobile score actual de la home.
- [ ] Memòria JS heap després de navegar per dashboard → `/handicap/quadre` → `/campionat-continu/ranking`.
- [ ] Temps que triga el dashboard a fer totes les queries (`Performance` panel).

## Cobertura objectiu (no per Fase 0, només referència)

| Àrea | Cobertura actual | Objectiu després de Fase 4 |
| --- | --- | --- |
| Lògica handicap (bracket, scheduler) | Bona (~70%) | ≥80% |
| Connexió/offline | 0% | ≥60% |
| Stores | <20% | ≥50% |
| E2E fluxos crítics | 0 | 5 fluxos coberts |

## Procés per actualitzar aquesta línia base

Després de cada fase del pla:

1. `npm run check` — anotar nou comptatge errors/warnings
2. `npm test` — anotar nou comptatge tests
3. (Opcional) `npm run test:coverage` — anotar % cobertura
4. Reflectir els canvis en aquest document amb una entrada datada a sota

---

## Historial

### 2026-04-09 — Fase 5c · Sessió 3: DROP TABLE players COMPLETADA

**La taula `players` ja no existeix.** Tot el codebase usa `socis.numero_soci` com a clau de jugador.

Resum de la sessió:

- **Fase B**: migrat mòdul continu (~20 fitxers) + rankingStore a soci_numero
- **Fase C**: 14 RPCs reescrites (12 in-place + 2 _v2 amb signatura integer)
- **Fase D**: 4 vistes recreades sense dependre de players
- **Migració massiva**: 60 fitxers addicionals migrats (tot el codebase net de UUID)
- **Fase E**: DROP 10 triggers, 12 FKs, 12 columnes UUID, 8 funcions mortes, 2 RLS policies
- **Fase F**: DROP TABLE players
- **Fase G**: 10 funcions trigger reescrites, 4 vistes recreades, 2 RLS recreades

Estat post-migració:

- svelte-check: 0 errors / 99 warnings (baseline mantinguda)
- vitest: 13 fitxers / 133 tests passant
- E2E: 7/7 passant
- Build: OK
- `from('players')` al codebase: **0 ocurrències**
- Columnes UUID (`player_id`, `jugador*_id`, `reptador_id`, `reptat_id`): **eliminades**
- Taula `socis_jugador` (1-a-1 amb socis): camps de joc (`mitjana`, `estat`, `club`, `avatar_url`, `data_ultim_repte`)

Fitxers eliminats (codi mort): `queries.ts`, `queries_old.ts`, `indexes.sql`.

Bugs pre-existents corregits durant la migració:
- `get_classifications_public`: `m.resultat = 'empat'` (valor inexistent a l'enum)
- `get_retired_players`: `i.retired_at` (columna correcta és `i.data_retirada`)

### 2026-04-07 — Línia base inicial

- 12 test files / 129 tests passant
- svelte-check: 1 error / 99 warnings (tots pre-existents)
- Cap test E2E
- Cap workflow de CI per `check`/`test`

### 2026-04-07 — Fase 5c · Sessió 2c-3 (NOT EXECUTED): decisió d'ajornar el mòdul continu

Després d'inventariar el mòdul continu (~20 fitxers) he decidit **NO migrar-lo a aquesta sessió** i deixar-lo per a Sessió 3 (la del drop antic). Raons:

1. **Totes les taules del campionat continu són buides actualment** (`challenges`, `matches`, `waiting_list`, `penalties`, `ranking_positions` només té 19 files): el risc de bug és nul perquè no hi ha dades en producció que puguin presentar-se malament a la UI.
2. **Patró arrelat al UUID `player_id`**: el codi del continu fa servir `players.id` com a clau de Maps a tot arreu (`history_position_changes.player_id`, `challenges.reptador_id/reptat_id`, etc.). Migrar només alguns punts crearia inconsistència entre fitxers que parlen entre ells.
3. **`src/lib/database/queries.ts` exposa una API agregada** (`getPlayerStats`, `getRankingPlayers`) amb camps `player_id: string` (UUID) a la signatura externa. Canviar-la trenca tots els components que la consumeixen. Aquest tipus de canvi és **atòmic** o no és — fer-ho a mitges deixa el codi pitjor que abans.
4. **Triggers dual-write protegeixen tota escriptura**: si algú escriu un `challenge` nou, el trigger omple `reptador_soci_numero` i `reptat_soci_numero` automàticament. La consistència de dades està garantida fins Sessió 3.
5. La feina natural és **fer Sessió 3 atòmica**: drop columns + recrear RPCs + reescriure mòdul continu sencer en una sola sessió dedicada, amb backup i finestra de manteniment.

Fitxers que es tractaran a Sessió 3:

- `src/lib/database/queries.ts` (cor del refactor — canviar la signatura externa)
- `src/lib/stores/rankingStore.ts`
- `src/routes/campionat-continu/{ranking,historial,classificacio,inscripcio,llista-espera}/+page.svelte`
- `src/routes/campionat-continu/reptes/{,me,nou}/+page.svelte` + 7 endpoints `+server.ts`
- `src/lib/components/campionat-continu/{PropostaDataForm,ClassificationTable}.svelte`

També a Sessió 3:

- Mòdul **admin** restant (`adminGuard`, `historial`, `graella-resultats`, `reset-campionat`)
- `src/lib/components/campionats-socials/AutoCategoryAssignment.svelte`
- Recrear RPCs `get_head_to_head_results`, `get_inscripcions_with_socis`, etc. perquè retornin `soci_numero` enlloc de UUIDs
- Drop columns UUID + DROP TABLE players

### 2026-04-07 — Fase 5c · Sessió 2c-2: mòdul social

Migrades les lectures principals del mòdul social. Ara la majoria de pantalles socials llegeixen el nom directament de `socis` via les noves FK `*_soci_numero`, sense passar per `players`.

Fitxers tocats:

- `src/lib/api/socialLeagues.ts`:
  - `getSocialLeagueEvent` i `getCategoryClassifications`: ara fan JOIN amb `socis` via `classificacions_soci_numero_fkey`. **Bug latent corregit**: la query original llegia `players(nom, cognoms)` però `cognoms` no existeix a `players` i sempre tornava null
  - `exportCalendariToCSV`: jugadors via `jugador*_soci_numero` directe, sense intermediari
  - `searchActivePlayers`: filtra mitjanes per `soci_numero` directament a `classificacions`
  - `getHeadToHeadResults`: NO migrat — depèn de la RPC `get_head_to_head_results` que retorna `jugador*_id` (UUID). Recrear la RPC va a Sessió 3
- `src/lib/components/campionats-socials/UserMatchesWidget.svelte`: query `calendari_partides` ara amb `jugador*_soci_numero` + JOIN directe; helper de format adaptat
- `src/lib/components/campionats-socials/HallOfFame.svelte`
- `src/lib/components/campionats-socials/PendingMatchesModal.svelte`: simplificat eliminant el lookup intermedi `players → socis`
- `src/lib/components/campionats-socials/OldMatchesModal.svelte`: idem
- `src/lib/components/campionats-socials/PlayerResultsModal.svelte`: filtres `.or()` ara per `jugador*_soci_numero`; tipus `MatchResult` actualitzat
- `src/lib/components/campionats-socials/SocialLeagueMatchResults.svelte`: `loadMyPlayerData()` directe via `socis.email`; matching `isMyMatch` per soci_numero amb fallback al UUID
- `src/lib/components/campionats-socials/SocialLeagueCalendarViewer.svelte`: bloc d'unprogrammed matches, `loadMyPlayerData()` i `matchPlayerById()` migrats
- `src/lib/components/campionats-socials/IntelligentCategoryMover.svelte`
- `src/routes/admin/inscripcions-socials/+page.svelte`: cancel·lar partides per `jugador*_soci_numero` (sense lookup previ a players)
- `src/routes/admin/events/[id]/+page.svelte`: eliminat lookup `players` redundant (el `player_id` no s'usava downstream)

Verificació: 0 errors svelte-check, vitest 133 ✅, E2E 7/7 ✅.

Pendents (Sessió 2c-3 i posterior):

- `src/lib/components/campionats-socials/AutoCategoryAssignment.svelte` — usa una RPC interna que retorna UUIDs; mantenir tal qual fins Sessió 3
- Mòdul **continu** (~20 fitxers, taules buides → risc baix però volum gran)
- Mòdul **admin** restant
- Recrear RPCs (`get_head_to_head_results`, `get_inscripcions_with_socis`, etc.) per retornar `soci_numero` enlloc de UUIDs

### 2026-04-07 — Fase 5c · Sessió 2c (parcial): calendar store + SSR loader

Migrats els dos fitxers de més alt impacte sobre la BD `calendari_partides` (675 files):

- `src/lib/stores/calendar.ts` · `loadPartidesCalendari()` ara llegeix els jugadors via FK directe `socis!calendari_partides_jugador1_soci_numero_fkey`/`jugador2_soci_numero_fkey`. Sense passar per `players`. La forma de sortida (`{ jugador1: { socis: { nom, cognoms } } }`) es manté per no trencar `formatPlayerName` al derived store.
- `src/routes/campionats-socials/[eventId]/+page.server.ts` · SSR loader del detall d'event social: jugadors via FK directe a `socis`. **Bug latent corregit**: la query original llegia `players.cognoms` (camp inexistent a `players`) i sempre retornava null.

Verificació: 0 errors svelte-check, E2E 7/7 (incloent `Calendari general` i `Campionats socials` que toquen aquest path).

#### Sessió 2c restant (queda per sessió pròpia)

Mòdul **social** (calendari + classificacions):

- `src/lib/components/campionats-socials/SocialLeagueCalendarViewer.svelte` (~2000 línies, 18 refs `jugador*_id`, 6 queries `players`/`calendari_partides`)
- `src/lib/components/campionats-socials/SocialLeagueMatchResults.svelte`
- `src/lib/components/campionats-socials/PendingMatchesModal.svelte`
- `src/lib/components/campionats-socials/PlayerResultsModal.svelte`
- `src/lib/components/campionats-socials/OldMatchesModal.svelte`
- `src/lib/components/campionats-socials/UserMatchesWidget.svelte`
- `src/lib/components/campionats-socials/HallOfFame.svelte`
- `src/lib/components/campionats-socials/SocialLeagueClassifications.svelte`
- `src/lib/components/campionats-socials/AutoCategoryAssignment.svelte`
- `src/lib/components/campionats-socials/IntelligentCategoryMover.svelte`
- `src/lib/api/socialLeagues.ts` (queries amb `jugador1_id`/`jugador2_id`)
- `src/lib/api/classifications.ts` (queries amb `player_id`)
- `src/routes/campionats-socials/+page.svelte`
- `src/routes/campionats-socials/[eventId]/+page.svelte`
- `src/routes/campionats-socials/[eventId]/classificacio/+page.svelte`
- `src/routes/api/events/[eventId]/classifications/+server.ts`
- `src/routes/admin/resultats-socials/+page.svelte`
- `src/routes/admin/inscripcions-socials/+page.svelte`
- `src/routes/admin/events/[id]/+page.svelte`
- `src/lib/components/admin/CalendarGenerator.svelte` (lectures, no escriptures)
- `src/lib/components/admin/CalendarEditor.svelte`

Mòdul **continu** (totes les taules amb `player_id` són actualment buides — risc baix):

- `src/lib/database/queries.ts` (`getPlayerStats`, `getRankingPlayers`, `getWaitingListPlayers`)
- `src/lib/stores/rankingStore.ts`
- `src/routes/campionat-continu/ranking/+page.svelte` (encara llegeix players per email lookup)
- `src/routes/campionat-continu/historial/+page.svelte`
- `src/routes/campionat-continu/classificacio/+page.svelte`
- `src/routes/campionat-continu/classificacio/[id]/+page.svelte`
- `src/routes/campionat-continu/inscripcio/+page.svelte`
- `src/routes/campionat-continu/llista-espera/+page.svelte` (parcialment migrat a 5a)
- `src/routes/campionat-continu/reptes/me/+page.svelte`
- `src/routes/campionat-continu/reptes/+page.svelte`
- `src/routes/campionat-continu/reptes/nou/eligibles/+server.ts`
- `src/routes/campionat-continu/reptes/[id]/resultat/+page.svelte`
- `src/routes/campionat-continu/reptes/contraproposta/+server.ts`
- `src/routes/campionat-continu/reptes/baixa/+server.ts`
- `src/routes/campionat-continu/reptes/accepta/+server.ts`
- `src/routes/campionat-continu/reptes/refusa/+server.ts`
- `src/routes/campionat-continu/reptes/proposa-data/+server.ts`
- `src/routes/campionat-continu/reptes/nou/+server.ts`
- `src/lib/components/campionat-continu/PropostaDataForm.svelte`
- `src/lib/components/campionat-continu/ClassificationTable.svelte`

Mòdul **admin** (parcialment migrat a 5a):

- `src/lib/services/inscriptionsService.ts`
- `src/routes/admin/+page.svelte`
- `src/routes/admin/socis/+server.ts`
- `src/routes/admin/historial/+page.svelte`
- `src/routes/admin/graella-resultats/+page.svelte`
- `src/routes/admin/reset-campionat/+page.svelte`

**Estat global**: la BD està en doble representació amb triggers actius. Qualsevol fitxer sense migrar continua escrivint per `player_id` i el trigger omple `*_soci_numero` automàticament. Tot l'aplicatiu funciona; només queda el treball mecànic de migrar lectures.

### 2026-04-07 — Fase 5c · Sessió 2: dual-write triggers + lectures hàndicap

#### Sessió 2a · Triggers de dual-write

Migració `supabase/migrations/20260407000002_phase5c_session2a_dual_write_triggers.sql` aplicada via MCP. Crea funcions PL/pgSQL i triggers `BEFORE INSERT/UPDATE` a 10 taules amb FK cap a `players(id)`. Quan algú escriu el `player_id` antic, el trigger omple automàticament la nova columna `*_soci_numero` consultant `players.numero_soci`. Garanteix consistència entre les dues representacions sense necessitat de canviar el codi de les pàgines no migrades.

Funcions creades:

- `sync_soci_numero_from_player_id()` — genèrica per a 8 taules amb una sola columna `player_id`
- `sync_calendari_partides_soci_numero()` — `jugador1_id` + `jugador2_id`
- `sync_challenges_soci_numero()` — `reptador_id` + `reptat_id`

#### Sessió 2b · Migració de lectures del mòdul hàndicap (8 fitxers)

Pattern aplicat: substituir `players!inner(socis!inner(nom, cognoms))` per `socis!handicap_participants_soci_numero_fkey(nom, cognoms)` (FK directe, una passa menys de JOIN). Accessos al codi `(p as any).players.socis.nom` esdevenen `(p as any).socis.nom` amb `Array.isArray` defensiu (PostgREST pot tornar el nested com a array si la cardinalitat no és inferida).

Fitxers tocats:

- `src/routes/handicap/+page.svelte` — dashboard (2 queries)
- `src/routes/handicap/sorteig/+page.svelte`
- `src/routes/handicap/quadre/+page.svelte` — inclou matching d'usuari autenticat: ara filtra `handicap_participants` per `soci_numero` directament (eliminat el lookup `players` previ)
- `src/routes/handicap/resum/+page.svelte`
- `src/routes/handicap/historial/+page.svelte`
- `src/routes/handicap/estadistiques/+page.svelte` (2 queries + 1 access)
- `src/routes/handicap/partides/+page.svelte` (manté `player_id` al SELECT perquè codi extern hi depèn)
- `src/routes/handicap/inscripcions/+page.svelte` — el més complex (write path). Lectura migrada; escriptura intacta perquè el trigger 2a omple `soci_numero` automàticament

Verificació: 133 vitest, 0 errors svelte-check, 7 E2E ✅ (la pàgina `/handicap` continua carregant net).

Pendents Sessió 2c (sessió futura):

1. Migrar lectures del mòdul **social** (`src/lib/api/socialLeagues.ts`, `src/routes/campionats-socials/**`, `src/lib/components/campionats-socials/**`): query principal a `calendari_partides` que llegeix `jugador1_id`/`jugador2_id` → migrar a `jugador1_soci_numero`/`jugador2_soci_numero` amb JOINs directes a `socis`
2. Migrar lectures del mòdul **continu** (`src/routes/campionat-continu/**`): rànquing, classificació, historial. Tot llegit per `player_id` → `soci_numero`
3. Migrar lectures del mòdul **admin** (`src/routes/admin/**`)
4. Inventari complet d'aproximadament ~25 fitxers més

Pendents Sessió 3:

1. Eliminar columnes UUID antigues (`player_id`, `jugador1_id`, etc.) — DROP COLUMN per a cada taula
2. Eliminar triggers de dual-write (ja no calen)
3. Recrear vistes `v_player_*` i `v_challenges_pending` amb les noves columnes
4. `DROP TABLE players`
5. Treure `player_id` del SELECT a `handicap/partides/+page.svelte` i altres llocs on l'hem mantingut "per compatibilitat"

### 2026-04-07 — Fase 5c · Sessió 1: Foundation

Pas no destructiu — afegeix estructura nova en paral·lel sense tocar res del que ja existeix. Aplicada via MCP a Supabase prod (`supabase/migrations/20260407000001_phase5c_session1_foundation.sql`).

Estructura nova creada:

- Taula `socis_jugador` 1-a-1 amb `socis` per als camps de joc (`mitjana`, `estat`, `club`, `avatar_url`, `data_ultim_repte`, `creat_el`). PK = `numero_soci`. **Backfill: 118/118**.
- Noves columnes `INTEGER` `*_soci_numero` (NULLABLE) afegides a 10 taules amb FK cap a `players(id)`:
  - `calendari_partides.jugador1_soci_numero` (675/675), `jugador2_soci_numero` (675/675)
  - `challenges.reptador_soci_numero`, `reptat_soci_numero` (0 files — taula buida)
  - `classificacions.soci_numero` (456/456)
  - `handicap_participants.soci_numero` (50/50)
  - `history_position_changes.soci_numero` (0)
  - `initial_ranking.soci_numero` (0)
  - `penalties.soci_numero` (0)
  - `player_weekly_positions.soci_numero` (0)
  - `ranking_positions.soci_numero` (19/19)
  - `waiting_list.soci_numero` (0)
- 12 índexs nous a les noves columnes
- Backup local previ: `backups/2026-04-07T09-06-26/` (27 taules, 4797 files, 1.81 MB)

Backfill verificat: **0 files pendents** a totes les taules.

Estat del codi: cap canvi. Tot el codi continua llegint UUIDs antics — la BD té doble representació coexistent. Vitest 133 ✅, svelte-check 0 errors / 99 warnings, E2E 7/7 ✅.

Pendents:

- **Sessió 2**: migrar lectures del codi (mòdul a mòdul: hàndicap → social → continu → admin). Mantenir escriptures dobles a totes dues columnes.
- **Sessió 3**: eliminar columnes UUID antigues + `DROP TABLE players` + recrear vistes `v_*` que depenen de `player_id`.

### 2026-04-07 — Fase 5b: `players.nom`/`email` ja són nullable

- Migració nova: `supabase/migrations/20260407000000_players_drop_nom_email_not_null.sql` — `ALTER TABLE players ALTER COLUMN nom/email DROP NOT NULL`. No esborra dades existents.
- `src/lib/components/admin/CalendarGenerator.svelte`: l'`insert` ja no escriu `nom` ni `email`. Els nous players només porten `numero_soci` + `estat`.
- Verificació: 133 vitest, 0 errors svelte-check, 7 E2E verds.

**Cal aplicar la migració a producció**: `supabase migration up` (o equivalent al deploy script habitual). Fins llavors, intentar crear nous players via CalendarGenerator a producció **fallarà** amb NOT NULL violation. Les pàgines de lectura no es veuen afectades.

Pendents per a un futur "5b-bis" (opcional, només quan estigui clar que cap codi llegeix `players.nom`/`email`):

1. `UPDATE players SET nom = NULL, email = NULL` per fer evident que la columna no s'usa
2. Després d'1-2 setmanes en monitoring net: `ALTER TABLE players DROP COLUMN nom, DROP COLUMN email`

### 2026-04-07 — Fase 5a: Desduplicar `players.nom`/`players.email`

Inventari real (executat sobre la BD del client):

- 118 players, **0 sense `numero_soci`** → mapping 1-a-1 garantit
- **118 / 118 noms divergents** entre `players.nom` i `socis.nom` (divergència sistemàtica per format → `players.nom` ja era lletra morta)
- 3 emails divergents
- `challenges`/`waiting_list`/`penalties` buides; volum real només a `calendari_partides` (675) i `classificacions` (456)
- Hàndicap ja referencia `socis` per `numero_soci`/`soci_id`; només queda 1 columna `player_id uuid` residual

Canvis fets a Fase 5a:

- `src/lib/utils/playerUtils.ts`: nous helpers `nomComplertSoci()` i `nomFormatatSoci()` + tipus `SociNomLike`
- `src/lib/api/socialLeagues.ts`: 2 queries refactoritzades — la cerca `searchPlayerClassifications` ara llegeix `players!inner(socis!inner(nom, cognoms))` (la versió anterior llegia un `cognoms` inexistent a `players` i tornava `null` silenciosament — bug latent corregit). El CSV export també llegeix nom des de socis
- `src/routes/admin/waiting-list/+server.ts`: nom des de `players(socis(nom, cognoms))`
- `src/routes/admin/reptes/nou/+page.svelte`: rànquing i waiting list — `players(socis(nom, cognoms, email))`
- `src/routes/campionat-continu/reptes/nou/+page.svelte` i `.../llista-espera/+page.svelte`: nom des de socis via JOIN niat
- `src/lib/components/admin/CalendarGenerator.svelte`: comentari aclarint per què encara s'escriu nom/email a `players` (NOT NULL) — eliminació deferida a Fase 5b

Verificació:

- Vitest: 133 tests passant
- svelte-check: 0 errors / 99 warnings
- E2E: 7 tests passant (49 s)

Pendents per Fase 5b (sessió pròpia, migració SQL):

1. `ALTER TABLE players ALTER COLUMN nom DROP NOT NULL` + `... email DROP NOT NULL`
2. Treure `nom`/`email` de l'`insert` a `CalendarGenerator.svelte`
3. Migrar la columna `players.nom` i `players.email` a `NULL` per a tots els registres existents (`UPDATE players SET nom=NULL, email=NULL`) — opcional, per tornar evident que ningú no les llegeix
4. Després d'una setmana de monitoring sense errors: `ALTER TABLE players DROP COLUMN nom, DROP COLUMN email`

Pendents per Fase 5c (sessió llarga, refactor profund):

1. Decidir destí dels camps `players`-only (`mitjana`, `estat`, `club`, `avatar_url`, `data_ultim_repte`): mou a `socis` o crea taula auxiliar `socis_jugador`
2. Migració SQL: afegir columnes a destí + backfill des de `players`
3. Migrar les 9 FK que apunten a `players(id)` perquè apuntin a `socis(numero_soci)`:
   - `challenges.reptador_id`, `challenges.reptat_id`
   - `ranking_positions.player_id`
   - `initial_ranking.player_id`
   - `classificacions.player_id` (456 files)
   - `waiting_list.player_id`
   - `player_weekly_positions.player_id`
   - `penalties.player_id`
   - `history_position_changes.player_id`
   - `calendari_partides.jugador1_id`, `jugador2_id` (675 files × 2)
   - `handicap_*` columna `player_id` residual
4. Reescriure ~27 fitxers TS/Svelte que filtren per `player_id` UUID
5. `DROP TABLE players`

### 2026-04-07 — Fase 4: Cobertura E2E

- 13 test files / 133 tests Vitest passant
- svelte-check: 0 errors / 99 warnings
- E2E: **7 tests passant** (39 s totals, single worker)
  - `smoke.spec.ts`: home < 5s (313 ms)
  - `public-routes.spec.ts`: 5 rutes públiques (Home, Calendari, Socials, Rànquing, Hàndicap)
  - `login.spec.ts`: formulari renderitza
- Cada test verifica: HTTP OK, càrrega < 5s, contingut hidratat al DOM, **cap error de consola** (filtrats: 401/403 d'usuari anònim, service worker chatter, errors PRE-EXISTENTS coneguts).
- **Bug pre-existent detectat per Fase 4 i ARREGLAT** ✅:
  - `src/lib/stores/playerChallengeHistory.ts`: la `.or()` sobre la taula referenciada `challenges` prefixava la columna en lloc d'usar `referencedTable`. Corregit a `referencedTable: 'challenges'`. Filtres temporals al spec eliminats; ara qualsevol regressió tornaria a fer fallar el test.
- Decisions:
  - **No s'ha cobert auth real ni fluxos d'escriptura** (crear repte, inscripció social): requereixen seed de DB o credencials de test que ara no tenim. Es deixa per a una futura sessió Fase 4-bis amb MSW o seed.
  - Playwright corre **single-worker** (`workers: 1`) perquè el preview server local no aguanta concurrència bé.
  - Les assertions de visibilitat s'han substituït per `toHaveCount` / `state: 'attached'` perquè el layout té branques portrait/landscape inestables en headless.

### 2026-04-07 — Fase 3: Optimització dashboard

- 13 test files / 133 tests passant
- svelte-check: 0 errors / 99 warnings
- E2E smoke: **537 ms** (abans 793 ms, -32%)
- Canvis:
  - `src/routes/+page.svelte`: `refreshCalendarData()` i `loadPageContent()` paral·lelitzats amb `Promise.all`
  - `src/lib/stores/calendar.ts`: SWR a `refreshCalendarData()` amb TTL fresc 30s / stale 5min, coalescing de crides concurrents (`inflightRefresh`), nova `invalidateCalendarCache()` per usar després d'escriptures
- Notes:
  - No s'ha mogut a `+page.ts` `load()`: el dashboard depèn de stores globals (`getEventsForDate` llegeix de `calendarEvents` derivat). El refactor és invasiu i el guany marginal sobre la combinació `paral·lel + SWR` no el justifica encara.
  - No s'han substituït els spinners per skeletons: el dashboard ja renderitza valors per defecte si la BD no respon, així que la UX no pateix gaire i el canvi seria cosmètic.

### 2026-04-07 — Fase 2: Loading states i cleanup de subscripcions

- 13 test files / 133 tests passant (sense regressió)
- svelte-check: 0 errors / 99 warnings
- E2E smoke verd (793 ms)
- Canvis:
  - `src/routes/handicap/quadre/+page.svelte`: `try/catch/finally` complet a `onMount`, `cancelled` flag a totes les awaits, `realtimeDebounceTimer` mogut a top-level i netejat a `onDestroy`, callbacks de subscripció ignoren events post-destroy
  - `src/routes/+page.svelte` (dashboard): `cancelled` flag + `onDestroy`
  - `src/routes/campionat-continu/ranking/+page.svelte`: `cancelled` flag a la subscripció `ranking`, a `setInterval` i als blocs catch/finally; `unsub = null` post-destroy

### 2026-04-07 — Fase 1: Hardening de connexió

- 13 test files / **133 tests** passant (+4 nous a `tests/connection.test.ts`)
- svelte-check: **0 errors** / 99 warnings (bug pre-existent `connectionManager` resolt)
- E2E smoke segueix verd (821 ms)
- Canvis:
  - `src/lib/supabaseClient.ts`: `fetchWithTimeout` (15s) aplicat a totes les peticions del client
  - `src/lib/utils/supabase.ts`: `withSupabase` accepta `timeoutMs`, llança `SupabaseTimeoutError`
  - `src/lib/connection/connectionManager.ts`: per-attempt timeout (15s) + circuit breaker (5 fallades → cooldown 15s) + `CircuitOpenError`/`OperationTimeoutError`
