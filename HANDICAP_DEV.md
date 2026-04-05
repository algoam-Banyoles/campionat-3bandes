# Campionat Handicap 3 Bandes - Documentacio de Desenvolupament

## Estat Actual: COMPLETAT ✅

Totes les fases del modul handicap estan completades i desplegades.

---

## Fases Completades

### Fase 1: Esquema BD i Infraestructura - COMPLETADA ✅
- **Migracio**: `supabase/migrations/20260317000000_create_handicap_tables.sql`
- **Estructura de rutes**: `/handicap/` amb layout protegit
- **Navegacio**: Seccio Handicap al menu lateral (visible per tots els socis autenticats quan el torneig es public)
- **Documentacio**: Aquest document

### Fase 2: Configuracio del Torneig - COMPLETADA ✅
- **Formulari creacio event**: `/admin/events/nou` amb camps especifics handicap (sistema puntuacio, distancies, horaris extra)
- **Pagina configuracio**: `/handicap/configuracio` per editar handicap_config
- **Creacio automatica**: Al crear event handicap, es crea automaticament el handicap_config
- **Control d'acces**: Boto "Obrir als socis" / "Tancar als socis" a la pagina de configuracio

### Fase 3: Inscripcio de Participants - COMPLETADA ✅
- **Pagina inscripcions**: `/handicap/inscripcions` amb 4 pestanyes
  - **Llista**: taula de participants amb edicio/eliminacio individual i importacio massiva des de campionats socials
  - **Disponibilitat**: graella agregada (HandicapAvailabilityGrid mode resum) — color-coded per detectar slots amb poca disponibilitat
  - **Compatibilitat**: matriu N×N que detecta parells de jugadors sense cap slot horari en comu
  - **Sorteig**: checklist pre-sorteig amb validacions obligatories (>=4 jugadors, totes distancies, config OK) i warnings (conflictes horaris)
- **Components nous**:
  - `HandicapAvailabilityGrid.svelte`: graella dies×hores en mode resum (agregat) i individual (editable)
- **Suggeriment de distancia**: al afegir un jugador, consulta la seva categoria als campionats socials i proposa la distancia corresponent
- **Importacio massiva**: carrega tots els jugadors de campionats socials actius, permet seleccionar-los per lots
- **Validacions pre-sorteig**: calcula byes necessaris i partides estimades (2N-1 per doble eliminacio)

### Fase 4: Generacio del Bracket - COMPLETADA ✅
- **Algorisme**: `src/lib/utils/handicap-bracket-generator.ts` — doble eliminacio completa
  - `size = nextPow2(n)`, `k = log2(size)` rondes al bracket guanyadors
  - Seeds R1: seed `i` a posicio `2i-1`, seed `size+1-i` a posicio `2i`; byes als millors seeds (seed 1..byes)
  - Propagacio automatica de byes (en cascada si cal fins que no hi ha canvis)
  - Bracket perdedors: `lRounds = 2*(k-1)` rondes; rondes parells (influx) reben perdedors del bracket guanyadors, rondes senars (pure) no en reben
  - Destinacio losers de W-Rj match i: `L-R(2j-2) slot i` (rondes parells del losers)
  - Destinacio winners del losers: rondes senars `lr` → L-R(lr+1) pos `2i-1`; rondes parells `lr` → L-R(lr+1) pos `i`; ultim losers → GF-R1-slot2
  - Distancies snapshot per a les partides de W-R1
- **Pagina sorteig**: `/handicap/sorteig` — inputs numerics de seed, vista previa R1, boto generar
  - Valida el bracket generat amb `handicap-bracket-validator.ts` abans d'insertar
  - Mostra warnings de validacio (no bloqueja si no hi ha errors)
- **Tests**: `tests/handicapBracketGenerator.test.ts` — 40 tests (4/5/6/8/17/32 jugadors)

### Fase 4B: Visualitzacio del Bracket - COMPLETADA ✅
- **Component**: `src/lib/components/handicap/HandicapBracketView.svelte`
  - Bracket guanyadors amb connectors SVG (llinia verda si partida jugada)
  - Bracket perdedors (columnes sense connectors)
  - Gran Final integrada al costat del bracket guanyadors
  - Targetes clicables amb estat codificat per colors
  - Highlight per cerca de jugador
  - Posicionament: `matchTop(r, idx) = (idx-0.5) × 2^(r-1) × SLOT_H - MATCH_H/2` (winners); losers usa `ceil(lr/2)` com a exponent
- **Pagina**: `/handicap/quadre` amb stats, filtres (Tot/Guanyadors/Perdedors/GF), cerca i modal de detall
- **Puntuacions al bracket**: es mostren caramboles/distancia a les targetes de partides jugades
- **Scroll horitzontal**: el bracket es navegable en pantalles petites

### Fase 5: Programacio de Partides - COMPLETADA ✅
- **Algorisme**: `src/lib/utils/handicap-scheduler.ts` — funcional pur, sense efectes secundaris
  - Ordena les partides per prioritat: `ronda ASC → bracket_type (winners<losers<gf) → matchPos ASC`
  - Per a cada partida, cerca el primer slot compatible: ambdos jugadors disponibles + cap dels dos ja te partida aquell dia + taula lliure
  - Restriccions: max 1 partida/jugador/dia, cap col·lisio slot+taula, interseccio de preferencies
  - Franja extra (p.ex. 17:00) habilitada per dies configurats, s'intenta primer dins el dia
  - En cas de conflicte, `buildConflictReason()` diagnostica: sense solapament horari, jugador X ocupat, sense slots lliures
- **Execucio a BD**: `src/lib/utils/handicap-scheduler-db.ts` — `executeScheduling()` insereix a `calendari_partides` + actualitza `handicap_matches`
- **Interficie admin**: `/handicap/partides`
  - Llista de partides amb filtres (estat, bracket, ronda, cerca per nom)
  - Auto-programacio: previsualitzacio → confirmacio
  - Programacio manual: `HandicapSlotPicker` inline per partida (color-coded per disponibilitat)
  - Desassignacio de partides programades
  - Pestanya Calendari setmanal: `HandicapWeeklyCalendar`
  - Badge "Noves partides llestes per programar" quan hi ha matches programables
- **Indicador equilibri branques**: `HandicapBranchBalance` a `/handicap/quadre` i `/handicap/partides`

### Fase 6: Registre de Resultats, Gran Final i Tancament - COMPLETADA ✅
- **Utilitat**: `src/lib/utils/handicap-propagation.ts`
  - `saveMatchResult()`: retorna `{ ok, newSchedulableCount, winnerDestDesc, isChampion, championParticipantId, subchampionParticipantId, needsResetMatch }`
  - `closeTournament()`: `actiu=false, estat_competicio='finalitzat'`
  - `closeTournamentManual()`: verifica partides pendents abans de tancar
- **Component**: `src/lib/components/handicap/HandicapMatchResult.svelte`
  - Camps: caramboles1, caramboles2, entrades; opcio walkover
  - Guanyador derivat automaticament (% relatiu a distancia); seleccio manual si empat
  - Validacio: caramboles no pot superar la distancia
- **Gran Final**: detecta si cal reset match; marca campió automaticament
- **Pagina historial** (`/handicap/historial`): llista cronologica + estadistiques per jugador
- **Pagina resum** (`/handicap/resum`): camí del campió, estadistiques, totes les partides

### Fase 7: Visualitzacio Publica i Poliment - COMPLETADA ✅
- **Sistema d'acces per nivells** (`+layout.svelte`):
  - `dev`: cap event creat → nomes administradors (banner taronja)
  - `admin`: event en planificacio/inscripcions → nomes admins (banner groc)
  - `public`: event en_curs/finalitzat → tots els socis autenticats
- **Control d'acces des de configuracio**: boto "Obrir als socis" / "Tancar als socis" a `/handicap/configuracio`
- **Rutes admin-only**: `configuracio`, `inscripcions`, `sorteig` redirigeixen non-admins a `/handicap`
- **Vistes publiques** (read-only per socis no-admin):
  - `/handicap/quadre`: quadre complet, sense botons d'accio; modal informatiu
  - `/handicap/partides`: llista de partides + pestanya "Les meves" per al propi participant
  - `/handicap/historial`: resultats i estadistiques
  - `/handicap/estadistiques`: taula de classificacio i trajectoria de cada participant
- **Navigacio**: seccio Handicap visible per tots els socis autenticats; admins veuen tambe Configuracio/Inscripcions/Sorteig
- **Dashboard definitiu** (`/handicap`): estat del torneig, darrers resultats, proximes partides, campió, torneigs anteriors; panell d'accions rapides nomes per admins
- **Mobile**: bracket amb scroll horitzontal suau; filtres en scroll horitzontal; modals adaptats a pantalla petita; taules amb scroll

---

## Administrar el Torneig

### Flux complet (primer cop)
1. **Crear event**: Admin → Events → Nou → triar "Handicap" com a tipus
2. **Configurar**: `/handicap/configuracio` → sistema puntuacio, distancies, horaris, dates
3. **Inscriure jugadors**: `/handicap/inscripcions` → afegir manualment o importar de campionats socials
4. **Generar bracket**: `/handicap/sorteig` → assignar seeds → Generar bracket
5. **Programar partides**: `/handicap/partides` → auto-programar o manual
6. **Introduir resultats**: `/handicap/quadre` → clicar partida → Introduir resultat
7. **Tancament**: quan la gran final esta jugada, el torneig es tanca automaticament

### Com obrir el torneig als socis
1. Anar a `/handicap/configuracio`
2. A la seccio "Control d'Acces dels Socis" (part inferior de la pagina)
3. Clicar **"Obrir als socis"** — canvia l'estat del torneig a `en_curs`
4. A partir d'aquell moment, tots els socis autenticats poden veure el quadre, partides i estadistiques

### Com tancar l'acces als socis (si cal)
- Nomes possible si **no s'han jugat partides** encara
- A la mateixa seccio, clicar **"Tancar als socis"** → torna a estat `inscripcions`
- Si ja hi ha partides jugades, l'acces no es pot tancar (el torneig esta en curs)

### Acces per perfil
| Perfil | Acces |
|--------|-------|
| Admin | Tot: gestio completa + vistes publiques |
| Soci autenticat | Vistes publiques (quan torneig es en_curs o finalitzat) |
| Soci no autenticat | Missatge "Cal iniciar sessio" |
| Acces sense event | Missatge "No disponible" |

---

## Taules de Base de Dades

### handicap_config
| Camp | Tipus | Descripcio |
|------|-------|------------|
| id | UUID PK | |
| event_id | UUID FK UNIQUE | Un config per event |
| sistema_puntuacio | TEXT | 'distancia' o 'percentatge' |
| limit_entrades | SMALLINT NULL | Obligatori si percentatge |
| distancies_per_categoria | JSONB | `[{"nom":"1a","distancia":20}]` |
| horaris_extra | JSONB NULL | `{"franja":"17:00","dies":["dl"]}` |

### handicap_participants
| Camp | Tipus | Descripcio |
|------|-------|------------|
| id | UUID PK | |
| event_id | UUID FK | |
| player_id | UUID FK | |
| distancia | SMALLINT | Caramboles objectiu |
| seed | SMALLINT NULL | Posicio sorteig (manual admin) |
| preferencies_dies | TEXT[] | Format compatible amb inscripcions |
| preferencies_hores | TEXT[] | |
| restriccions_especials | TEXT | |
| eliminat | BOOLEAN | Perd al bracket losers |
| UNIQUE | (event_id, player_id) | |

### handicap_bracket_slots
| Camp | Tipus | Descripcio |
|------|-------|------------|
| id | UUID PK | |
| event_id | UUID FK | |
| bracket_type | TEXT | 'winners', 'losers', 'grand_final' |
| ronda | SMALLINT | >= 1. Grand final: 1=final, 2=reset |
| posicio | SMALLINT | Posicio dins la ronda |
| participant_id | UUID FK NULL | S'omple progressivament |
| is_bye | BOOLEAN | |
| source_match_id | UUID FK NULL | D'on prove el jugador |
| UNIQUE | (event_id, bracket_type, ronda, posicio) | |

### handicap_matches
| Camp | Tipus | Descripcio |
|------|-------|------------|
| id | UUID PK | |
| event_id | UUID FK | |
| calendari_partida_id | UUID FK NULL | NULL fins programacio |
| slot1_id | UUID FK | Correspon a jugador1 |
| slot2_id | UUID FK | Correspon a jugador2 |
| winner_slot_dest_id | UUID FK NULL | On avanca el guanyador |
| loser_slot_dest_id | UUID FK NULL | On cau el perdedor |
| distancia_jugador1 | SMALLINT NULL | Snapshot. NULL per byes |
| distancia_jugador2 | SMALLINT NULL | Snapshot. NULL per byes |
| guanyador_participant_id | UUID FK NULL | |
| estat | TEXT | pendent/programada/jugada/bye/walkover |

---

## Decisions de Disseny

### Sistema d'acces per nivells
L'acces al modul handicap es determina automaticament per l'estat del torneig (`estat_competicio`):
- Sense event actiu → nomes admins (per preparacio)
- `planificacio` o `inscripcions` → nomes admins (torneig en preparacio)
- `en_curs` o `finalitzat` → tots els socis autenticats

L'admin activa l'acces public clickant "Obrir als socis" a `/handicap/configuracio`, que canvia `estat_competicio` a `en_curs`. Aixo es semanticament coherent: el torneig s'obre quan esta en curs.

### Per que taules separades (no reutilitzar inscripcions)?
`inscripcions` esta dissenyada per lligues socials: `categoria_assignada_id`, `pagat`, `confirmat`, `incompareixences_count`. El handicap te un model diferent: distancia individual, seed de sorteig, sense categories formals.

### Per que JSONB per distancies_per_categoria?
Les "categories" del handicap son simplement grups de distancia (1a/2a/resta), no entitats amb FK a `categories`. Canvien entre torneigs.

### Per que snapshot de distancia als matches?
Si l'admin corregeix la distancia d'un participant despres d'una partida jugada, el resultat historic s'ha d'interpretar amb la distancia vigent en aquell moment.

### Grand final com a bracket separat
La gran final te regles uniques: el jugador del bracket losers necessita guanyar 2 partides consecutives (reset match). Ronda 1 = final, Ronda 2 = reset match (nomes si guanya el del losers).

---

## Aplicar la Migracio

### A Supabase Dashboard (SQL Editor)
```sql
-- Copia i executa el contingut de:
-- supabase/migrations/20260317000000_create_handicap_tables.sql
-- supabase/migrations/20260318000000_calendari_nullable_categoria.sql
```

### Verificacio
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name LIKE 'handicap_%';
```

## Estructura de Fitxers

```
supabase/migrations/
  20260317000000_create_handicap_tables.sql
  20260318000000_calendari_nullable_categoria.sql

src/routes/handicap/
  +layout.svelte                   # Acces per nivells (dev/admin/public)
  +layout.ts                       # Desactiva SSR
  +page.svelte                     # Dashboard
  configuracio/+page.svelte        # Config + boto "Obrir als socis"
  inscripcions/+page.svelte        # Gestio participants (admin)
  sorteig/+page.svelte             # Seeds i generacio bracket (admin)
  quadre/+page.svelte              # Bracket (lectura per socis, gestio per admins)
  partides/+page.svelte            # Llista partides (+ pestanya "Les meves")
  historial/+page.svelte           # Resultats i estadistiques
  estadistiques/+page.svelte       # Classificacio i trajectories
  resum/+page.svelte               # Resum del torneig (campio, camins)

src/lib/components/handicap/
  HandicapBracketView.svelte       # Component visual del bracket
  HandicapBranchBalance.svelte     # Equilibri de branques
  HandicapMatchResult.svelte       # Formulari de resultats
  HandicapAvailabilityGrid.svelte  # Graella disponibilitat
  HandicapScheduleConfig.svelte    # Configuracio horaris
  HandicapSlotPicker.svelte        # Selector de slots
  HandicapWeeklyCalendar.svelte    # Calendari setmanal

src/lib/utils/handicap-*.ts       # Logica de negoci i utilitats

HANDICAP_DEV.md                   # Aquest document
```

## Seguretat

- **Frontend**: Rutes admin-only (`configuracio`, `inscripcions`, `sorteig`) redirigeixen non-admins
- **Layout**: Guard que determina el nivell d'acces per l'estat del torneig
- **BD**: RLS policies - SELECT per a usuaris autenticats, INSERT/UPDATE/DELETE per a admins
