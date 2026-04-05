# CLAUDE_SUPABASE.md — Patrons de Base de Dades

Referència de patrons de Supabase per al projecte Campionat 3 Bandes.

## Client de Supabase

```typescript
import { supabase } from '$lib/supabaseClient';
// El client inclou wrapRpc() que mapeja errors al català via errors.ts
// Credencials: PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY
```

## Patrons de migracions

### Nom de fitxer
Format: `YYYYMMDDHHMMSS_descripcio_curta.sql`
- Exemples reals: `20260317000000_create_handicap_tables.sql`, `20250212000000_add_calendari_publicat_field.sql`
- Timestamp seguit d'un número seqüencial si cal: `20250130000000`, `20250130000001`, ...

### Estructura tipus d'una migració
```sql
-- ============================================================================
-- Migració: Descripció de la migració
-- Data: YYYY-MM-DD
-- Descripció: Explica el propòsit detallat
-- ============================================================================

CREATE TABLE public.nom_taula (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  camp_text TEXT NOT NULL,
  camp_opcions TEXT NOT NULL,
  camp_nullable TEXT,
  camp_bool BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT nom_taula_camp_check
    CHECK (camp_opcions IN ('opcio1', 'opcio2')),

  CONSTRAINT nom_taula_unicitat
    UNIQUE (event_id, altre_camp)
);

COMMENT ON TABLE public.nom_taula IS
  'Descripció en català de la taula.';
COMMENT ON COLUMN public.nom_taula.camp_text IS
  'Descripció del camp en català.';

CREATE INDEX idx_nom_taula_event ON public.nom_taula (event_id);
CREATE INDEX idx_nom_taula_camp ON public.nom_taula (camp_text);

-- RLS
ALTER TABLE public.nom_taula ENABLE ROW LEVEL SECURITY;

CREATE POLICY "nom_taula_select_all" ON public.nom_taula
  FOR SELECT USING (true);

CREATE POLICY "nom_taula_insert_auth" ON public.nom_taula
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "nom_taula_update_auth" ON public.nom_taula
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "nom_taula_delete_auth" ON public.nom_taula
  FOR DELETE USING (auth.uid() IS NOT NULL);
```

### RLS — patró estàndard del projecte
```sql
-- SELECT: accessible per tothom (anon + authenticated)
FOR SELECT USING (true);

-- INSERT/UPDATE/DELETE: requereix usuari autenticat
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
FOR UPDATE USING (auth.uid() IS NOT NULL);
FOR DELETE USING (auth.uid() IS NOT NULL);
```
**Nota**: L'app controla l'autorització a nivell d'aplicació (stores `isAdmin`, `adminChecked`). La BD confia en l'autenticació, no en rols específics.

### Nom de constraints i índexos
```sql
-- Constraints: {taula}_{camp}_{tipus}
CONSTRAINT handicap_config_event_unique UNIQUE (event_id)
CONSTRAINT handicap_config_sistema_check CHECK (...)
CONSTRAINT handicap_participants_event_player_unique UNIQUE (...)

-- Índexos: idx_{taula}_{camp(s)}
CREATE INDEX idx_handicap_participants_event ON public.handicap_participants (event_id);
CREATE INDEX idx_handicap_bracket_slots_event_type_ronda ON public.handicap_bracket_slots (event_id, bracket_type, ronda);
```

### FK ON DELETE
```sql
-- Regla general:
ON DELETE CASCADE   -- quan el pare desapareix, els fills també (ex: event → matches)
ON DELETE SET NULL  -- quan el pare desapareix, el camp es posa NULL (ex: calendari_partida_id)
ON DELETE RESTRICT  -- (no s'usa; Supabase el fa per defecte si no s'especifica)
```

### Comentaris
Sempre en **català**. `COMMENT ON TABLE` i `COMMENT ON COLUMN` obligatoris per taules noves.

## Queries habituals

### Filtrar sempre per `event_id`
```typescript
// CORRECTE
supabase.from('calendari_partides').select('*').eq('event_id', eventId)

// INCORRECTE — retorna totes les partides de tots els campionats
supabase.from('calendari_partides').select('*')
```

### JOIN players → socis (noms de jugadors)
```typescript
// Via players a calendari_partides
supabase.from('calendari_partides')
  .select('id, jugador1_id(id, socis(nom, cognoms)), jugador2_id(id, socis(nom, cognoms))')
  .eq('event_id', eventId)

// Via handicap_participants
supabase.from('handicap_participants')
  .select('id, players!inner(id, socis!inner(nom, cognoms))')
  .in('id', participantIds)
// Accés: (p as any).players.socis.nom + ' ' + (p as any).players.socis.cognoms
```

### JOIN inscripcions → socis (via soci_numero, NO player_id)
```typescript
// inscripcions.soci_numero → socis.numero_soci (NO player_id!)
supabase.from('inscripcions')
  .select('id, soci_numero, socis(nom, cognoms)')
  .eq('event_id', eventId)
```

### Buscar events per temporada (no per actiu)
```typescript
// Per l'event actiu actual:
supabase.from('events').select('id').eq('actiu', true).eq('tipus_competicio', 'handicap').single()

// Per historial o events finalitzats: usar temporada
supabase.from('events').select('id, nom').eq('temporada', '2025-2026').eq('tipus_competicio', 'social')
// actiu=true pot ser false si el campionat ja ha acabat
```

### `maybeSingle()` vs `single()`
```typescript
.maybeSingle()  // retorna null si no hi ha resultats (NO error)
.single()       // error si no hi ha exactament 1 resultat
// Usar maybeSingle() quan el resultat pot no existir
```

### Upsert
```typescript
supabase.from('handicap_config').upsert({ event_id: id, ... }, { onConflict: 'event_id' })
```

### Count
```typescript
supabase.from('handicap_participants')
  .select('*', { count: 'exact', head: true })
  .eq('event_id', eventId)
// Retorna { count: number | null }
```

### IN amb llista buida
```typescript
// Supabase retorna error si la llista és buida
if (ids.length === 0) return [];
supabase.from('taula').select('*').in('id', ids)
```

## Funcions SQL (RPCs)

### `get_head_to_head_results(p_event_id, p_categoria_id)`
Retorna resultats cap a cap entre jugadors d'una categoria social. Creada a `20251022000000`.

### Funcions de classificació
- `get_social_league_classifications` (inferida de l'ús a `classifications.ts`)
- `get_real_classifications` (inferida)
- `generate_final_classifications` (inferida de `generateFinalClassifications()`)

Per cridar una RPC:
```typescript
const { data, error } = await supabase.rpc('get_head_to_head_results', {
  p_event_id: eventId,
  p_categoria_id: categoriaId
});
```

## Taules principals del projecte

### `socis`
```
numero_soci INTEGER PK
nom TEXT
cognoms TEXT
email TEXT
data_naixement DATE (afegit 20251023)
...
```

### `players`
```
id UUID PK
numero_soci INTEGER FK→socis
...
```
**Relació**: `socis.numero_soci = players.numero_soci`

### `admins`
```
email TEXT PK
```
Un registre per cada admin de l'app.

### `events`
```
id UUID PK
nom TEXT
tipus_competicio TEXT  -- 'social' | 'continu' | 'handicap'
temporada TEXT         -- 'YYYY-YYYY'
estat_competicio TEXT  -- 'planificacio' | 'inscripcions' | 'en_curs' | 'finalitzat'
actiu BOOLEAN
data_inici DATE
data_fi DATE
...
```

### `categories`
```
id UUID PK
event_id UUID FK→events
nom TEXT
ordre_categoria SMALLINT  -- 1, 2, 3... ordre dins l'event
distancia_caramboles SMALLINT
```
**Nota**: `ordre_categoria >= 3` → últim grup de distàncies al hàndicap (no out-of-bounds: usar `Math.min(ordre - 1, arr.length - 1)`).

### `inscripcions`
```
id UUID PK
event_id UUID FK→events
soci_numero INTEGER FK→socis  -- NO player_id!
categoria_assignada_id UUID FK→categories (NULLABLE)
preferencies_dies TEXT[]
preferencies_hores TEXT[]
pagament_rebut BOOLEAN
estat_jugador TEXT  -- 'actiu' | 'retirat' | 'descalificat'
...
```
**Crítica**: la FK a socis usa `soci_numero`, no `player_id`. Errors comuns en JOINs si es confon.

### `calendari_partides`
```
id UUID PK
event_id UUID FK→events   -- SEMPRE filtrar per event_id
categoria_id UUID FK→categories (NULLABLE — NULL per hàndicap)
jugador1_id UUID FK→players
jugador2_id UUID FK→players
data_programada TIMESTAMPTZ
hora_inici TEXT       -- 'HH:MM'
taula_assignada SMALLINT  -- 1, 2 o 3 (billar B1/B2/B3)
estat TEXT            -- 'generat' | 'publicat' | 'jugada' | ...
caramboles_jugador1 SMALLINT NULL
caramboles_jugador2 SMALLINT NULL
entrades SMALLINT NULL
calendari_publicat BOOLEAN (afegit 20250212)
challenge_id UUID NULL (nullable, afegit 20251001)
...
```
**Compartida**: usada per campionats socials, reptes continus I hàndicap.

### `classificacions`
```
event_id, categoria_id, player_id, punts, ...
```

### `mitjanes_historiques`
```
player_id, temporada, distancia_objectiu, ...
```

### Taules del rànquing continu
```
challenges (id, reptador_id, reptat_id, estat, created_at, ...)
  → partides via calendari_partides.challenge_id
llista_espera (player_id, posicio, ...)
```

### Taules del hàndicap
Veure CLAUDE_HANDICAP.md per al detall complet de:
- `handicap_config`
- `handicap_participants`
- `handicap_bracket_slots`
- `handicap_matches`

## Errors freqüents a evitar

| Error | Causa | Solució |
|-------|-------|---------|
| Query sense `event_id` | Retorna dades de tots els campionats | Afegir sempre `.eq('event_id', eventId)` |
| `actiu=true` per historial | L'event pot estar finalitzat | Usar `.eq('temporada', '...')` |
| `inscripcions.player_id` | El camp no existeix | Usar `soci_numero` |
| `SELECT *` assumint estructura | L'esquema pot canviar | Queries explícites amb camps concrets |
| `bracket_type` a `handicap_matches` | El camp no existeix aquí | JOIN via `slot1_id` a `handicap_bracket_slots` |
| FK circular (slots↔matches) | Error d'inserció per referència inexistent | Inserir amb NULL, crear l'altre, fer UPDATE |
| Llista buida a `.in()` | Error de Supabase | Verificar `arr.length > 0` abans |
| `ordre_categoria - 1` out of bounds | `ordre_categoria` pot ser >= longitud de l'array | `Math.min(ordre - 1, arr.length - 1)` |

## Patrons d'accés amb loading/error state

```typescript
// Patró estàndard per onMount
onMount(async () => {
  const { data, error } = await supabase
    .from('taula')
    .select('camps')
    .eq('event_id', eventId)
    .order('created_at', { ascending: false });

  if (error) {
    errorMsg = error.message;
    loading = false;
    return;
  }

  items = data ?? [];
  loading = false;
});
```

## Convencions de noms de camps

| Patró | Exemples |
|-------|---------|
| PK | `id UUID DEFAULT gen_random_uuid()` |
| FK a events | `event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE` |
| FK opcional | `camp_id UUID REFERENCES altra_taula(id) ON DELETE SET NULL` |
| Timestamp | `created_at TIMESTAMPTZ NOT NULL DEFAULT now()` |
| Flag booleà | `actiu BOOLEAN NOT NULL DEFAULT true`, `eliminat BOOLEAN NOT NULL DEFAULT false` |
| Estat enum | `estat TEXT NOT NULL DEFAULT 'pendent'` + `CONSTRAINT ... CHECK (estat IN (...))` |
| Array de text | `preferencies_dies TEXT[]` |
| JSON flexible | `config JSONB`, `distancies_per_categoria JSONB NOT NULL` |
| Distàncies/caramboles | `SMALLINT` (no INT) |
