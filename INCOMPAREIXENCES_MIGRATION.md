# Migració d'Incompareixences

Aquest document explica com aplicar les migracions per gestionar incompareixences als campionats socials.

## ⚠️ IMPORTANT: Ordre d'aplicació

Les migracions s'han d'aplicar en aquest ordre específic (dividides per evitar timeouts):

1. **20250130000000a_add_incompareixences_fields.sql** - Afegeix camps incompareixences
2. **20250130000000b_add_incompareixences_comments.sql** - Afegeix comentaris
3. **20250130000002_add_entrades_per_jugador.sql** - Afegeix entrades_jugador1 i entrades_jugador2
4. **20250130000004_add_punts_per_jugador.sql** - ⭐ Afegeix punts_jugador1 i punts_jugador2
5. **20250130000003_update_classifications_entrades_per_jugador.sql** - Actualitza classificacions (antiga versió)
6. **20250130000006_add_estat_jugador_to_classifications.sql** - ⭐ Actualitza classificacions amb estat_jugador (retirats)
7. **20250130000005_update_match_results_incompareixenca.sql** - Actualitza resultats públics amb incompareixences
8. **20250130000001_fix_incompareixences_function.sql** - Crea funció registrar_incompareixenca
9. **20250130000007_fix_incompareixences_classificacions.sql** - ⭐ Corregeix regles d'incompareixences per classificacions
10. **20250130000008_fix_entrades_classifications.sql** - ⭐ **NOU**: Corregeix càlcul d'entrades individuals

## Opció 1: Aplicar manualment des del SQL Editor de Supabase (RECOMANAT)

### Pas 1: Afegir camps a les taules

1. Ves al [Supabase Dashboard](https://supabase.com/dashboard)
2. Selecciona el teu projecte
3. Ves a **SQL Editor** al menú lateral esquerre
4. Obre el fitxer `supabase/migrations/20250130000000a_add_incompareixences_fields.sql`
5. Copia tot el contingut del fitxer
6. Enganxa'l a l'editor SQL de Supabase
7. Clica **RUN** per executar la migració

### Pas 2: Afegir comentaris

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000000b_add_incompareixences_comments.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

### Pas 3: Afegir camps d'entrades per jugador

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000002_add_entrades_per_jugador.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

**Què fa**: Afegeix `entrades_jugador1` i `entrades_jugador2` i migra totes les dades existents.

### Pas 4: Afegir camps de punts per jugador

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000004_add_punts_per_jugador.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

**Què fa**: Afegeix `punts_jugador1` i `punts_jugador2` i calcula punts de totes les partides existents (guanyador=2, empat=1, perdedor=0).

### Pas 5: Actualitzar funció de classificacions

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000003_update_classifications_entrades_per_jugador.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

**Què fa**: Actualitza `get_social_league_classifications` per utilitzar `entrades_jugador1/2` i `punts_jugador1/2` directament (molt més eficient).

### Pas 6: Actualitzar classificacions amb estat de jugador

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000006_add_estat_jugador_to_classifications.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

**Què fa**: Actualitza `get_social_league_classifications` per incloure el camp `estat_jugador`. Això permet mostrar els jugadors retirats/eliminats per incompareixences amb el text ratllat a les classificacions.

### Pas 7: Actualitzar funció de resultats públics

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000005_update_match_results_incompareixenca.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

**Què fa**: Actualitza `get_match_results_public` per incloure camps d'incompareixença. Això permet mostrar el badge "No presentat" a la interfície.

### Pas 8: Crear funció d'incompareixences (FINAL)

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000001_fix_incompareixences_function.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

**Què fa**: Crea la versió final de `registrar_incompareixenca` amb:
- Utilitza `soci_numero` (correcció d'error 400)
- Assigna `entrades_jugador1` i `entrades_jugador2` correctament
- Jugador present: 0 entrades (no afecta mitjana)
- Jugador absent: 50 entrades (mitjana 0/50 = 0.000)

### Pas 9: Corregir regles d'incompareixences per classificacions (IMPORTANT) ⭐

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000007_fix_incompareixences_classificacions.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

**Què fa**: Actualitza `registrar_incompareixenca` amb les regles CORRECTES:
- Utilitza `max_entrades` de la categoria (50 general, 40 per lliure 1a)
- Jugador present: **0 caramboles**, 0 entrades (no afecta mitjana)
- Jugador absent: **0 caramboles**, max_entrades (penalització forta en mitjana)

Veure [FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md](FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md) per més detalls.

### Pas 10: Corregir càlcul d'entrades individuals (IMPORTANT) ⭐

1. A **SQL Editor** de Supabase
2. Obre el fitxer `supabase/migrations/20250130000008_fix_entrades_classifications.sql`
3. Copia tot el contingut
4. Enganxa'l a l'editor SQL de Supabase
5. Clica **RUN**

**Què fa**: Actualitza `get_social_league_classifications` per utilitzar entrades individuals:
- Usa `COALESCE(entrades_jugador1, entrades, 0)` per jugador 1
- Usa `COALESCE(entrades_jugador2, entrades, 0)` per jugador 2
- Això corregeix el càlcul de mitjanes en classificacions

Veure [FIX_ENTRADES_CLASSIFICATIONS.md](FIX_ENTRADES_CLASSIFICATIONS.md) per més detalls.

## Opció 2: Executar l'script de migració

Si prefereixes executar l'script automàtic:

```bash
npx tsx scripts/apply_incompareixences_migration.ts
```

**Nota**: Aquest mètode pot no funcionar si no tens permisos suficients amb la clau ANON_KEY. En aquest cas, utilitza l'Opció 1.

## Què fa aquesta migració?

### Camps nous a `calendari_partides`:
- `incompareixenca_jugador1` (boolean): Si el jugador 1 no s'ha presentat
- `incompareixenca_jugador2` (boolean): Si el jugador 2 no s'ha presentat
- `data_incompareixenca` (timestamptz): Data de registre de la incompareixença
- `partida_anullada` (boolean): Si la partida ha estat anul·lada
- `motiu_anul·lacio` (text): Motiu de l'anul·lació

### Camps nous a `inscripcions`:
- `eliminat_per_incompareixences` (boolean): Si el jugador ha estat eliminat per 2 incompareixences
- `data_eliminacio` (timestamptz): Data d'eliminació
- `incompareixences_count` (smallint): Comptador d'incompareixences

### Funció nova:
- `registrar_incompareixenca(p_partida_id, p_jugador_que_falta)`: Gestiona automàticament:
  - Assigna punts (2 punts al jugador present, 0 al jugador absent)
  - Actualitza caramboles i entrades segons les regles
  - Comptabilitza incompareixences
  - Elimina jugadors amb 2 incompareixences
  - Anul·la totes les partides pendents del jugador eliminat

## Regles d'Incompareixences

### ⚠️ ACTUALITZACIÓ IMPORTANT (Migració 007)

Les regles correctes per incompareixences en campionats socials són:

**Jugador que NO es presenta:**
- **Punts**: 0
- **Caramboles**: 0
- **Entrades**: Màxim d'entrades permès per la categoria
  - **50 entrades** per defecte (categories generals)
  - **40 entrades** per campionats de lliure 1a categoria

**Jugador que SÍ es presenta:**
- **Punts**: 2 (victòria per incompareixença)
- **Caramboles**: 0 (no afecta la seva mitjana)
- **Entrades**: 0 (no afecta la seva mitjana)

### Impacte en Classificacions

- El **jugador present** rep 2 punts però la seva mitjana **NO canvia** (0 caramboles / 0 entrades)
- El **jugador absent** rep 0 punts i la seva mitjana **baixa molt** (0 caramboles / 50 entrades = 0.000)

### Eliminació per Incompareixences

Quan un jugador té 2 incompareixences:
- El jugador és **eliminat automàticament** del campionat
- Totes les seves **partides pendents** (no jugades/validats) són **anul·lades**

## Verificació

Després d'aplicar la migració, pots verificar que s'ha executat correctament:

```sql
-- Verifica que els camps s'han afegit correctament
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'calendari_partides'
  AND column_name IN ('incompareixenca_jugador1', 'incompareixenca_jugador2', 'data_incompareixenca', 'partida_anullada', 'motiu_anul·lacio');

-- Verifica la funció
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'registrar_incompareixenca';
```

## Ús a la UI

Després d'aplicar la migració, ja podràs:

1. Anar a **Campionats Socials** > **Calendari**
2. Veure el botó **⚠️ Incompareixença** a cada partida pendent
3. Clicar el botó per obrir el modal
4. Seleccionar quin jugador no s'ha presentat
5. El sistema automàticament:
   - Registra la incompareixença
   - Assigna els punts correctes
   - Elimina el jugador si té 2 incompareixences
   - Anul·la les partides pendents si correspon
