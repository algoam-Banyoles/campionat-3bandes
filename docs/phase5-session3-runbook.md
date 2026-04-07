# Fase 5c · Sessió 3 — Runbook

> Drop antic + recreació de RPCs/vistes + DROP TABLE players + migració del codi del campionat continu i admin restant.

**Estat del repositori a l'inici de la sessió** (validat 2026-04-07):

- Vitest 133 ✅, svelte-check 0 errors / 99 warnings, E2E 7/7 ✅
- BD: doble representació activa amb triggers dual-write
- 100% del backfill verificat (cap NULL pendent)
- Backup local: `backups/2026-04-07T09-06-26/` (1.81 MB)

> **Aquesta és la sessió "point of no return"**. Cal finestra de manteniment, backup recent, i revisió manual posterior. NO arrencar sense haver llegit tot aquest runbook.

---

## 0. Prerequisits abans d'arrencar

- [ ] Backup remot de Supabase < 24h (Dashboard → Database → Backups)
- [ ] Backup local nou (`node scripts/backup-db.mjs`) per si el remot falla
- [ ] Branca git nova `phase5c-session3-drop-players` per aïllar
- [ ] Cap usuari actiu a producció (consultar amb la junta)
- [ ] Notificar inici i fi de la finestra al canal de comunicació habitual

---

## 1. Inventari complet del que cal tocar

### 1.1 Vistes que depenen de columnes UUID antigues (4)

| Vista | Columnes UUID que llegeix | Acció |
| --- | --- | --- |
| `v_challenges_pending` | `challenges.reptador_id`, `challenges.reptat_id`, `players.nom` | Recrear amb `reptador_soci_numero`/`reptat_soci_numero` + JOIN a `socis` |
| `v_player_badges` | `ranking_positions.player_id`, `challenges.reptador_id/reptat_id` | Recrear amb `soci_numero` |
| `v_player_timeline` | `players.id`, `players.nom`, `challenges.reptador_id/reptat_id` | Recrear amb `socis.numero_soci/nom` |
| `v_promocions_candidates` | `ranking_positions.player_id`, `players.nom`, `socis.cognoms` | Recrear amb `soci_numero` directe a `socis` |

Definicions actuals capturades a `phase5-session3-views-backup.sql` (a crear durant la sessió).

### 1.2 Funcions/RPCs que mencionen `players` (27)

Agrupades per categoria d'esforç:

**Triggers/utils auto-migrables (només DROP, vam crear-les nosaltres)**

- `sync_soci_numero_from_player_id`
- `sync_calendari_partides_soci_numero`
- `sync_challenges_soci_numero`

A Sessió 3 aquestes ja no caldran un cop dropades les columnes UUID.

**Funcions CRUD amb signatura `uuid` que cal mantenir o migrar**

| Funció | Args | Estratègia |
| --- | --- | --- |
| `can_create_challenge(p_event uuid, p_reptador uuid, p_reptat uuid)` | uuid | Reescriure interna per usar `socis_jugador` + `socis`. Mantenir signatura externa? **Decisió: canviar a `integer numero_soci`** i actualitzar consumidors |
| `can_create_challenge_detail(...)` | uuid | Idem |
| `list_eligible_opponents(p_player uuid)` | uuid | Idem → `p_soci_numero integer` |
| `register_player(p_event uuid, p_player uuid)` | uuid | Idem |
| `record_match_and_resolve(p_challenge uuid, ...)` | uuid challenge | Mantenir uuid del challenge (cal generar uuid nou per a cada repte) |
| `retire_player_from_league` (×2 sobrecàrregues) | uuid + integer | Eliminar la versió uuid, mantenir només la integer |
| `reactivate_player_in_league` (×2) | uuid + integer | Idem |
| `get_eligible_promotions(event_id uuid)` | uuid event | Reescriure body |
| `get_head_to_head_results(p_event uuid, p_categoria uuid)` | uuid event/cat | Reescriure perquè retorni `jugador1_soci_numero`/`jugador2_soci_numero` enlloc de UUIDs |
| `get_calendar_matches_public(p_event uuid)` | uuid event | Reescriure body |
| `get_match_results_public(p_event uuid)` | uuid event | Reescriure body |
| `get_classifications_public(...)` | uuid | Reescriure body |
| `get_social_league_classifications(p_event uuid)` | uuid | Reescriure body |
| `get_ranking()` | — | Reescriure body |
| `get_waiting_list()` | — | Reescriure body |
| `get_retired_players(p_event uuid)` | uuid event | Reescriure body |
| `current_player_id()` | — | **Eliminar** o reescriure per retornar `numero_soci` |
| `get_players_by_soci_numbers(p_soci_numbers integer[])` | integer[] | **Eliminar** — la seva existència mateix és símptoma del refactor pendent |
| `admin_reset_championship` | — | Reescriure body |
| `reset_event_to_initial(...)` | uuid | Reescriure body |
| `reset_full_competition` | — | Reescriure body |
| `sweep_inactivity_from_settings` | — | Reescriure body |
| `registrar_incompareixenca(p_partida uuid, ...)` | uuid partida | Mantenir uuid (és el de calendari_partides) |
| `fn_matches_finalize` | trigger | Reescriure body |
| `trg_challenges_validate` | trigger | Reescriure body |
| `trg_matches_apply_result` | trigger | Reescriure body |
| `create_initial_ranking_from_ordered_socis(...)` | integer[] | Ja accepta integer — només cal reescriure body |

**Esforç estimat**: 27 funcions × ~15 min cadascuna = **6-8 hores només a les RPCs**.

### 1.3 12 FKs cap a `players(id)` que el `DROP TABLE` cascadejarà

`calendari_partides_jugador1_id_fkey`, `calendari_partides_jugador2_id_fkey`, `challenges_reptador_id_fkey`, `challenges_reptat_id_fkey`, `classificacions_player_id_fkey`, `handicap_participants_player_id_fkey`, `history_position_changes_player_id_fkey`, `initial_ranking_player_id_fkey`, `penalties_player_id_fkey`, `player_weekly_positions_player_id_fkey`, `ranking_positions_player_id_fkey`, `waiting_list_player_id_fkey`.

### 1.4 Codi client consumidor de RPCs amb args UUID (17 fitxers)

```
src/lib/canCreateChallenge.ts
src/lib/canCreateChallengeDetail.ts
src/lib/api/socialLeagues.ts
src/lib/components/campionats-socials/SocialLeagueCalendarViewer.svelte
src/lib/components/campionats-socials/SocialLeagueMatchResults.svelte
src/lib/components/campionats-socials/PendingMatchesModal.svelte
src/lib/components/campionats-socials/SocialLeaguePlayersGrid.svelte
src/lib/components/campionats-socials/SocialLeagueClassifications.svelte
src/lib/components/campionats-socials/AutoCategoryAssignment.svelte
src/routes/campionat-continu/llista-espera/+page.svelte
src/routes/campionat-continu/reptes/nou/eligibles/+server.ts
src/routes/campionats-socials/[eventId]/+page.svelte
src/routes/admin/+page.svelte
src/routes/admin/categories/+page.svelte
src/routes/admin/resultats-socials/+page.svelte
src/routes/admin/reset/+server.ts
src/routes/admin/reset-campionat/+page.server.ts
```

### 1.5 Codi del campionat continu pendent de migrar (mòdul sencer)

Vegeu la llista detallada a `docs/quality-baseline.md` (apartat Sessió 5c-S2c-3 ajornada). ~20 fitxers, tots fan servir Maps amb clau `players.id` UUID.

### 1.6 Codi admin restant

- `src/lib/services/inscriptionsService.ts`
- `src/routes/admin/historial/+page.svelte`
- `src/routes/admin/graella-resultats/+page.svelte`
- `src/lib/database/queries.ts` (cor del refactor — 27 places)

---

## 2. Resultat dels dry-runs

Verificat amb `BEGIN; ...; ROLLBACK;` via MCP:

### 2.1 ✅ DROP COLUMN `calendari_partides.jugador1_id` amb trigger present

Resultat: **falla** amb `cannot drop column ... because other objects depend on it ... DETAIL: trigger trg_sync_soci_numero on table calendari_partides depends on column jugador1_id`.

**Solució**: cal `DROP TRIGGER trg_sync_soci_numero ON calendari_partides;` abans del `DROP COLUMN`. Validat: amb el trigger eliminat el `DROP COLUMN` funciona net.

### 2.2 ✅ DROP TABLE players CASCADE

Resultat: **funciona** dins la transacció. Però CASCADE cascadeja **silenciosament** els 12 FKs i les vistes/funcions que depenen de la taula. Risc: perdre integritat referencial sense advertència.

**Solució recomanada**: NO usar CASCADE. Drop explícit i ordenat:

1. `DROP TRIGGER` × 10 (els nostres dual-write)
2. `DROP VIEW` × 4 (recrearem desprès)
3. `DROP FUNCTION` × N (totes les RPCs que mencionen `players`)
4. `DROP COLUMN` × 12 (UUID antics)
5. `DROP TABLE players` (ja no té dependents)
6. `CREATE OR REPLACE FUNCTION` × N (versions noves amb `socis_jugador`/`socis`)
7. `CREATE VIEW` × 4 (versions noves)

---

## 3. Pla d'execució (ordre estricte)

### Fase A — Preparació (sense canvis a producció)

1. Crear branca git `phase5c-session3-drop-players`
2. Capturar definicions actuals de totes les vistes i funcions: `pg_get_viewdef`, `pg_get_functiondef`. Desar a `phase5-session3-backup-defs.sql`. **Critical** — és el rollback si la sessió es trenca a mig camí
3. Backup local: `node scripts/backup-db.mjs`
4. Verificar tests + E2E verds

### Fase B — Migrar codi del continu (sense tocar BD)

> Aquest pas es fa primer perquè un cop drop columns, qualsevol consum residual del UUID falla. Migrar codi abans = errors compile-time enlloc de runtime.

Per cada fitxer del continu:

1. Substituir Maps key=`uuid` per Maps key=`numero_soci`
2. Substituir queries `from('players').select('id, socis(...)')` per `from('socis').select('numero_soci, nom, cognoms')`
3. Canviar accessos `players[challenge.reptador_id]` per `players[challenge.reptador_soci_numero]`
4. Verificar svelte-check + tests + E2E després de cada **mòdul** (no fitxer per fitxer — agruparen per mòdul: ranking, historial, reptes, classificacio)

Resultat esperat: codi compila, però algunes coses es poden trencar a runtime perquè algunes RPCs encara retornen UUIDs. Validar amb manual smoke d'una pàgina per mòdul.

### Fase C — Recrear RPCs i funcions

Per cada funció de la llista 1.2:

1. Llegir definició actual
2. Reescriure amb `socis_jugador` i `socis` directament (sense `players`)
3. `CREATE OR REPLACE FUNCTION ...`
4. Validar amb una crida de prova via MCP (`SELECT * FROM ...`)

**Funcions amb canvi de signatura** requereixen actualitzar tots els consumidors abans del DROP de la versió antiga. Estratègia: crear versions noves amb sufix `_v2`, migrar consumidors, després `DROP FUNCTION ... CASCADE` les antigues.

### Fase D — Recrear vistes

`DROP VIEW IF EXISTS v_challenges_pending; CREATE VIEW v_challenges_pending AS ...` per cadascuna. Usar les noves columnes `*_soci_numero` i JOIN amb `socis`.

### Fase E — Drop columns UUID antigues

```sql
-- Triggers dual-write (ja no calen)
DROP TRIGGER trg_sync_soci_numero ON calendari_partides;
DROP TRIGGER trg_sync_soci_numero ON challenges;
-- ... (10 en total)

-- FKs antigues
ALTER TABLE calendari_partides DROP CONSTRAINT calendari_partides_jugador1_id_fkey;
-- ... (12 en total)

-- Columnes antigues
ALTER TABLE calendari_partides DROP COLUMN jugador1_id;
ALTER TABLE calendari_partides DROP COLUMN jugador2_id;
ALTER TABLE challenges DROP COLUMN reptador_id;
-- ... etc
```

### Fase F — Drop funcions sync triggers + DROP TABLE players

```sql
DROP FUNCTION sync_soci_numero_from_player_id();
DROP FUNCTION sync_calendari_partides_soci_numero();
DROP FUNCTION sync_challenges_soci_numero();
DROP TABLE players;
```

### Fase G — Validació

1. Tots els tests verds (vitest + E2E)
2. Smoke manual de **cada mòdul**: home, calendari general, hàndicap (dashboard, quadre, partides, inscripcions, sorteig, historial, estadístiques, resum), social (calendari, classificació, resultats, hall of fame), continu (rànquing, reptes, llista espera, històric, classificació), admin
3. `npm run build`
4. Lighthouse mobile sobre la home (no hauria de regressar)

### Fase H — Cleanup post-deploy

1. Treure els fitxers `.json` del backup local que són grans
2. Actualitzar `quality-baseline.md` amb l'entrada Sessió 3
3. Eliminar referències a "Fase 5" del runbook (ja completada)

---

## 4. Rollback plan

### Si fallem a Fase B (codi)

`git checkout main` — la BD encara no s'ha tocat.

### Si fallem a Fase C/D (RPCs/vistes)

Aplicar `phase5-session3-backup-defs.sql` capturat a Fase A. Recrea les versions originals.

### Si fallem a Fase E/F (drop columns/table)

**No hi ha rollback dins la BD un cop dropades les columnes**. Cal restaurar des del backup remot de Supabase (24h enrere). Per això la Fase A diu "backup recent obligatori".

Recomanació: **executar Fases E i F en una sola transacció** (`BEGIN; ... COMMIT;`) perquè un error a meitat camí es pugui revertir amb un únic `ROLLBACK`. Postgres permet DDL transaccional, així que això és viable.

---

## 5. Estimació total

| Fase | Estimació |
| --- | --- |
| A. Preparació | 30 min |
| B. Migració codi continu | 2-3 h |
| C. Recrear 27 RPCs | 4-6 h |
| D. Recrear 4 vistes | 30 min |
| E. Drop columns | 30 min |
| F. DROP TABLE players | 5 min |
| G. Validació | 1-2 h |
| H. Cleanup | 30 min |
| **TOTAL** | **9-13 hores** |

**No és una sessió de tarda** — caldrà partir-ho en 2 dies, deixant la BD en estat coherent entre dies (Fase B és segura entre dies, Fase C requereix una sola sessió perquè trenca consumidors fins a actualitzar-los tots).

---

## 6. Decisions pendents abans d'arrencar Sessió 3

1. **Signatures de RPCs**: mantenim sufix `_v2` durant la transició o substituïm in-place? Recomanat: `_v2` perquè permet rollback granular.
2. **Finestra de manteniment**: quan? Caldria mínim 4h consecutives sense ús de l'app.
3. **Comunicació als socis**: avís previ amb 48h?
4. **Versionat**: fer-ho a `main` directament o crear branch + merge? Recomanat: branch.
5. **Monitoring post-deploy**: Sentry capturarà errors automàticament si en surt algun. Cal mirar-lo els dies següents.

---

## 7. Estat actual de la sessió 2c (per context al qui llegeixi)

Migrades a `*_soci_numero` les lectures crítiques de:

- ✅ Hàndicap (8 fitxers) — mòdul complet
- ✅ Social (12 fitxers) — la majoria
- ✅ Calendar store + SSR loader del detall d'event social

Ajornat a Sessió 3:

- Mòdul continu (~20 fitxers) — Maps amb clau UUID, atòmic
- `src/lib/database/queries.ts` — API agregada amb signatura UUID externa
- `src/lib/services/inscriptionsService.ts`
- Components admin restants
- `getHeadToHeadResults` (depèn de RPC `get_head_to_head_results`)
- `AutoCategoryAssignment.svelte` (depèn de RPC interna)

Triggers dual-write actius a 10 taules → la BD garanteix consistència mentre la migració de codi sigui parcial.
