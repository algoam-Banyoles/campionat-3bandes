# CLAUDE_HANDICAP.md — Mòdul Hàndicap

Torneig anual d'eliminació doble (winners + losers + grand final) amb distàncies individuals per nivell.

## Taules de base de dades

### `handicap_config` — 1 per event
```sql
id UUID PK
event_id UUID FK→events (UNIQUE)
sistema_puntuacio TEXT  -- 'distancia' | 'percentatge'
limit_entrades SMALLINT -- NULL si distancia, NOT NULL si percentatge
distancies_per_categoria JSONB
  -- [{"nom": "1a", "distancia": 20}, {"nom": "2a", "distancia": 15}, {"nom": "resta", "distancia": 10}]
horaris_extra JSONB
  -- {"franja": "17:00", "dies": ["dl", "dt"]}  o NULL
  -- Franges addicionals fora dels horaris estàndard (18:00/19:00 dl-dv)
created_at TIMESTAMPTZ
```

### `handicap_participants` — Jugadors inscrits
```sql
id UUID PK
event_id UUID FK→events
player_id UUID FK→players
distancia SMALLINT NOT NULL  -- caramboles objectiu (> 0)
seed SMALLINT NULL           -- introduït manualment durant sorteig presencial
preferencies_dies TEXT[]     -- ['dl','dt','dc','dj','dv'] (buit = tots els dies)
preferencies_hores TEXT[]    -- ['17:00','18:00','19:00'] (buit = totes)
restriccions_especials TEXT NULL
eliminat BOOLEAN DEFAULT false  -- true quan perd al bracket de perdedors

UNIQUE (event_id, player_id)
```

### `handicap_bracket_slots` — Estructura del quadre
```sql
id UUID PK
event_id UUID FK→events
bracket_type TEXT  -- 'winners' | 'losers' | 'grand_final'
ronda SMALLINT >= 1
posicio SMALLINT >= 1
participant_id UUID FK→handicap_participants (NULLABLE — s'omple progressivament)
is_bye BOOLEAN DEFAULT false
source_match_id UUID FK→handicap_matches ON DELETE SET NULL (NULLABLE)
  -- NULL per slots de R1 (provenen del sorteig)
  -- FK circular: definida amb ALTER TABLE després de crear handicap_matches

UNIQUE (event_id, bracket_type, ronda, posicio)
```

### `handicap_matches` — Partides del torneig
```sql
id UUID PK
event_id UUID FK→events
calendari_partida_id UUID FK→calendari_partides ON DELETE SET NULL (NULLABLE)
  -- NULL fins programació; conté data/hora/billar i resultats de caramboles
slot1_id UUID FK→handicap_bracket_slots
slot2_id UUID FK→handicap_bracket_slots
winner_slot_dest_id UUID FK→handicap_bracket_slots ON DELETE SET NULL (NULLABLE)
  -- NULL a la gran final definitiva
loser_slot_dest_id UUID FK→handicap_bracket_slots ON DELETE SET NULL (NULLABLE)
  -- NULL al bracket de perdedors (perdedor eliminat) i a la gran final
distancia_jugador1 SMALLINT NULL  -- snapshot; NULL en byes
distancia_jugador2 SMALLINT NULL  -- snapshot; NULL en byes
guanyador_participant_id UUID FK→handicap_participants ON DELETE SET NULL (NULLABLE)
estat TEXT DEFAULT 'pendent'
  -- 'pendent' | 'programada' | 'jugada' | 'bye' | 'walkover'
created_at TIMESTAMPTZ
```

**Convenció slot1/slot2**: `slot1_id` = jugador1 = `distancia_jugador1`. A R1 winners: slot1 = seed inferior (millor, ex: seed 1), slot2 = seed superior (ex: seed 16).

## Relacions crítiques

```
handicap_matches.slot1_id / slot2_id → handicap_bracket_slots
  ↑ bracket_type i ronda VIUEN aquí, NO a handicap_matches

handicap_bracket_slots.source_match_id → handicap_matches  (FK circular)
  → Solució: inserir bracket_slots amb source_match_id=NULL, crear matches, fer UPDATE

handicap_matches.calendari_partida_id → calendari_partides
  → NULL fins que es programa la partida

handicap_participants.player_id → players
  → Per obtenir el nom: JOIN players!inner(socis!inner(nom, cognoms))
```

### Query de noms de participants
```typescript
supabase
  .from('handicap_participants')
  .select('id, players!inner(socis!inner(nom, cognoms))')
  .in('id', participantIds)
// Accés: (p as any).players.socis.nom + ' ' + (p as any).players.socis.cognoms
```

## Lògica de negoci

### Brackets
- **winners**: bracket principal. k rondes on k = log2(nextPow2(N))
- **losers**: bracket de perdedors. 2*(k-1) rondes
- **grand_final**: R1 (final), R2 (reset match si el jugador del losers guanya R1)

### Seeding R1
`seed i` vs `seed (size+1-i)` — seed 1 vs seed N, seed 2 vs seed N-1...
Byes: posicions > N → byes als seeds alts → seeds 1..byes avancen automàticament a R2.

### Byes en cascada
Quan un slot s'omple, si l'altre slot del match és un bye → avançar automàticament sense jugar.
**Condició**: l'altre slot ha de tenir `is_bye=true`. Si `is_bye=false AND participant_id=NULL` → esperar (el jugador vindrà d'un match pendent).

### Gran Final (grand_final)
- **R1**: slot1 = jugador del winners, slot2 = jugador del losers
  - Si guanya slot1 (winners) → campió directe. Marcar GF-R2 com a `estat='bye'`.
  - Si guanya slot2 (losers) → cal reset match (GF-R2). `needsResetMatch=true`.
- **R2**: (reset) slot1 i slot2 fills de GF-R1. Qui guanya és el campió final.

### Sistemes de puntuació
- **`distancia`**: guanya qui primer assoleix la seva distància en caramboles. `limit_entrades=NULL`.
- **`percentatge`**: guanya qui fa major percentatge de (caramboles/distancia) dins el límit d'entrades. `limit_entrades NOT NULL`.

### Calendarització automàtica
Quan un match queda amb ambdós participants assignats (ambdós slots no-bye amb `participant_id` NOT NULL), es programa automàticament via `autoScheduleReadyMatches()`.

Restriccions del scheduler:
- Màxim 1 partida per jugador per dia
- Cap col·lisió de slot (data + hora + billar)
- Ambdós jugadors han d'estar disponibles (intersecció de preferències)
- Exclou slots ocupats d'altres campionats

Priorització: `ronda ASC → bracket_type (winners<losers<grand_final) → matchPos ASC`

### Categoria social → distància hàndicap
```typescript
// buscar per temporada, NO per actiu=true (pot estar finalitzat)
const { data: event } = await supabase
  .from('events').select('id').eq('tipus_competicio', 'social').eq('temporada', '2025-2026')
// ordre_categoria >= 3 → últim grup de distàncies (no out-of-bounds)
const grup = distancies[Math.min(ordre_categoria - 1, distancies.length - 1)];
```

## Fitxers clau

### `src/lib/utils/handicap-bracket-generator.ts`
**`generateDoublEliminationBracket(eventId, participants): BracketResult`**
- Input: `eventId: string`, `participants: ParticipantInput[]` (id, seed, distancia)
- Output: `{ slots: SlotInsert[], matches: MatchInsert[] }`
- Pura (sense efectes secundaris). IDs via `crypto.randomUUID()` (injectable per tests).
- Exporta: `calcByes()`, `getR1Pairings()`

### `src/lib/utils/handicap-bracket-db.ts`
**`insertBracketToDb(supabase, result: BracketResult): Promise<void>`**
Insereix en 3 passos per la FK circular:
1. INSERT slots amb `source_match_id=NULL`
2. INSERT matches
3. UPDATE slots SET `source_match_id=...`

### `src/lib/utils/handicap-bracket-validator.ts`
**`validateBracket(slots, matches, n): { valid: boolean, errors: string[], warnings: string[] }`**
Valida el bracket generat abans d'inserir.

### `src/lib/utils/handicap-types.ts`
Utilitats de numeració de partides:
- **`buildMatchCodeMap(matches)`** → `Map<matchId, code>` (W1..Wn, L1..Ln, F1, F2)
- **`buildLoserDestCodeMap(matches, codeMap)`** → destí del perdedor per cada match
- **`buildSlotSourceMap(matches, codeMap)`** → `Map<slotId, SlotSource>` per mostrar "Guanyador W3"

### `src/lib/utils/handicap-scheduler.ts`
**`scheduleMatches(input: ScheduleInput): ScheduleItemResult[]`**
- Pura (sense BD). Pren: `matches: MatchToSchedule[]`, `config: TournamentConfig`, `participants: ParticipantAvailability[]`, `occupiedSlots: OccupiedSlot[]`
- Retorna per cada match: `{ scheduled: true, match_id, data, hora, taula }` o `{ scheduled: false, match_id, motiu }`
- Horaris estàndard: 18:00 i 19:00, dilluns a divendres. `horaris_extra` permet afegir franges (p.ex. 17:00 els dl i dc).

```typescript
interface MatchToSchedule {
  id: string;
  bracket_type: 'winners' | 'losers' | 'grand_final';
  ronda: number;
  matchPos: number;    // Math.ceil(slot.posicio / 2)
  player1_participant_id: string;
  player2_participant_id: string;
  player1_player_id: string;   // per a calendari_partides.jugador1_id
  player2_player_id: string;
}
```

### `src/lib/utils/handicap-scheduler-db.ts`
**`executeScheduling(supabase, eventId, matchesInput, results): Promise<SchedulingExecutionResult>`**
Executa resultats del scheduler: INSERT a `calendari_partides` + UPDATE `handicap_matches`.
```typescript
interface SchedulingExecutionResult {
  scheduled: number;
  conflicts: number;
  conflictDetails: Array<{ match_id: string; motiu: string }>;
  errors: string[];
  scheduledDetails: Array<{ match_id: string; data: string; hora: string; taula: number }>;
}
```

### `src/lib/utils/handicap-auto-schedule.ts`
**`autoScheduleReadyMatches(supabase, eventId): Promise<SchedulingExecutionResult | null>`**
Cerca totes les partides pendents amb ambdós participants assignats i les programa automàticament.
Retorna `null` si no hi ha configuració de dates o no hi ha partides llestes.

### `src/lib/utils/handicap-propagation.ts`
**`saveMatchResult(supabase, opts): Promise<SaveResultResponse | SaveResultError>`**

Input (`SaveResultOpts`):
```typescript
{
  matchId: string;
  isWalkover: boolean;
  caramboles1: number | null;
  caramboles2: number | null;
  entrades: number | null;
  winnerParticipantId: string;
  loserParticipantId: string | null;  // null si el perdedor era un bye
  calendariPartidaId: string | null;   // null si walkover sense programació
}
```

Output (`SaveResultResponse`):
```typescript
{
  ok: true;
  newSchedulableCount: number;     // partides amb conflicte (no auto-programades)
  winnerDestDesc: string;          // text del destí del guanyador
  isChampion: boolean;
  championParticipantId: string | null;
  subchampionParticipantId: string | null;
  needsResetMatch: boolean;        // true si GF-R1 guanya el jugador del losers
  autoScheduled: SchedulingExecutionResult | null;
}
```

**Flux intern**:
1. Carregar match i slot1 (detectar si és GF-R1 o GF-R2)
2. Actualitzar `calendari_partides` (resultats)
3. Actualitzar `handicap_matches` (estat + guanyador)
4. Propagar winner → `winner_slot_dest_id`
5. Propagar loser → `loser_slot_dest_id` (o marcar `eliminat=true`)
6. Resoldre byes en cascada (`resolveCascadeByes`)
7. Si campió → `closeTournament()` (estat='finalitzat', actiu=false)
8. `autoScheduleReadyMatches()` → `autoScheduled`

**`closeTournament(supabase, eventId)`** — Marca l'event com finalitzat.
**`closeTournamentManual(supabase, eventId)`** — Com l'anterior però verifica que no quedin partides pendents.

## Rutes del mòdul

### `src/routes/handicap/+layout.svelte`
Guard de 3 nivells determinat automàticament per `events.estat_competicio`:
```
No event actiu        → 'dev'    → Admins only (banner taronja "MODE DESENVOLUPAMENT")
'planificacio' /
'inscripcions'        → 'admin'  → Admins only (banner groc "EN PREPARACIÓ")
'en_curs' /
'finalitzat'          → 'public' → Tots els socis autenticats (sense banner)
```
Canviar estat: botó "Obrir als socis" a `/handicap/configuracio` (fa `estat_competicio='en_curs'`).

### `/handicap/configuracio` (admin)
- Edita: `sistema_puntuacio`, `limit_entrades`, `distancies_per_categoria`, `horaris_extra`
- Gestiona: `data_inici`, `data_fi` (camps de la taula `events`)
- Control d'accés: botons "Obrir als socis" / "Tancar als socis"
- `playedMatchesCount`: si > 0, no es pot tancar als socis

### `/handicap/inscripcions` (admin)
- Inscriu jugadors via `player_id` + `distancia`
- Gestiona disponibilitat (dies/hores) de cada participant

### `/handicap/sorteig` (admin)
- Assignació manual de seeds (presencial)
- Genera el bracket amb `generateDoublEliminationBracket()`
- Valida amb `validateBracket()`
- Insereix a BD amb `insertBracketToDb()`
- Auto-programa R1 amb `autoScheduleReadyMatches()`
- Redirigeix a `/handicap/quadre`

### `/handicap/quadre`
- Visualitza el bracket complet amb `HandicapBracketView`
- Admin: pot introduir resultats via modal `HandicapMatchResult`
- Crida `saveMatchResult()` → mostra feedback al toast incloent auto-scheduling
- Notifica: "✅ Jugador guanya → Destí" + "📅 N partides programades" o "⚠️ N conflictes"

### `/handicap/partides`
- Llista totes les partides (filtrable per estat/bracket/ronda/cerca)
- Admin: programació manual via `HandicapSlotPicker` o auto-schedule
- `runAutoSchedule()`: preview sense confirmar → `confirmAutoSchedule()`: executa
- Vistes: setmanal (`HandicapWeeklyCalendar`) i llistat

### `/handicap/estadistiques`
- Classificació per distàncies
- Trajectòria de cada participant al bracket

### `/handicap/historial`
- Llistat de partides jugades del torneig actual

### `/handicap/resum?event={id}`
- Resum d'un torneig passat (accessible per `event_id` a la URL)

## Historial de torneigs

Cada torneig = un event nou amb temporada diferent. Les dades antigues es mantenen.
Secció "Torneigs anteriors" al dashboard: events amb `estat_competicio='finalitzat'`.
Accés al resum: `/handicap/resum?event={ht.id}`.

## Errors freqüents

| Error | Causa | Solució |
|-------|-------|---------|
| FK circular en inserció | `source_match_id → handicap_matches` no existeix encara | Inserir amb `NULL`, després `UPDATE` |
| `bracket_type` no disponible a `handicap_matches` | No existeix aquest camp al match | JOIN a `handicap_bracket_slots` via `slot1_id` |
| Bye propaga incorrectament | L'altre slot és pendent (espera un jugador) | Verificar `is_bye=true`, no `participant_id=NULL` |
| Distàncies NULL al match | Match és un bye | Snapshot `NULL` per a byes; gestionar-ho a la UI |
| `newSchedulableCount` incorrecte | Ara reflecteix conflictes (no total de pendents) | Consultar `autoScheduled.conflicts` |
