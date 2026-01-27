# Fix: Classificacions amb Incompareixences Correctes

## Problema Identificat

Les incompareixences no es gestionaven correctament segons les regles dels campionats socials. El jugador que es presentava sumava caramboles de la distància de categoria, quan hauria de sumar 0 caramboles per no afectar la seva mitjana.

## Regles Correctes per Incompareixences

Segons les regles dels campionats socials:

### Jugador que NO es presenta
- **Punts**: 0
- **Caramboles**: 0
- **Entrades**: Màxim d'entrades permès per la categoria
  - **50 entrades** per defecte (categories generals)
  - **40 entrades** per campionats de lliure 1a categoria

### Jugador que SÍ es presenta
- **Punts**: 2 (victòria per incompareixença)
- **Caramboles**: 0
- **Entrades**: 0

## Impacte en les Classificacions

Amb aquestes regles:

1. **Jugador present (0 caramboles / 0 entrades)**:
   - No suma entrades a la seva mitjana general
   - La partida no afecta la seva mitjana
   - Rep 2 punts de victòria

2. **Jugador absent (0 caramboles / 50 entrades)**:
   - Suma 50 entrades sense caramboles
   - Baixa considerablement la seva mitjana general (penalització forta)
   - Rep 0 punts

## Exemple Numèric

### Abans de la incompareixença
Jugador A: 100 caramboles en 20 entrades = mitjana 5.000

### Després d'incompareixença (Jugador B no es presenta)
- **Jugador A** (present): 100 caramboles en 20 entrades = mitjana 5.000 (no canvia)
- **Jugador B** (absent): 50 caramboles en 60 entrades = mitjana 0.833 (baixa molt)

Abans: 50 caramboles / 10 entrades = 5.000
Després: 50 caramboles / (10 + 50) entrades = 0.833

## Solució Implementada

### Migració: `20250130000007_fix_incompareixences_classificacions.sql`

Actualitza la funció `registrar_incompareixenca` per:

1. **Obtenir `max_entrades` de la categoria**: En lloc d'usar un valor fix de 50
2. **Assignar 0 caramboles al jugador present**: En lloc de la distància de categoria
3. **Assignar 0 entrades al jugador present**: Per no afectar la seva mitjana
4. **Assignar `max_entrades` al jugador absent**: Segons la categoria (50 o 40)

### Codi Clau

```sql
-- Obtenir el max_entrades de la categoria
SELECT max_entrades INTO v_max_entrades
FROM categories
WHERE id = v_categoria_id;

-- Jugador PRESENT: 2 punts, 0 caramboles, 0 entrades
caramboles_jugador_present = 0,
entrades_jugador_present = 0,
punts_jugador_present = 2,

-- Jugador ABSENT: 0 punts, 0 caramboles, max_entrades
caramboles_jugador_absent = 0,
entrades_jugador_absent = v_max_entrades,
punts_jugador_absent = 0,
```

## Funció de Classificacions

La funció `get_social_league_classifications` ja gestiona correctament aquests casos:

```sql
-- Mitjana general: només si té entrades
CASE
  WHEN SUM(pm.player_entrades) > 0 THEN
    ROUND((SUM(pm.player_caramboles)::NUMERIC / SUM(pm.player_entrades)::NUMERIC), 3)
  ELSE NULL  -- NULL si no té entrades (no afecta ordenació)
END as mitjana_general,
```

Això significa que:
- Si un jugador només té partides guanyades per incompareixença (0 entrades), la seva mitjana és NULL (no afecta)
- Si un jugador té incompareixences on NO es presenta (50 entrades, 0 caramboles), la seva mitjana baixa molt

## Com Aplicar la Migració

### Opció A: Via Supabase Dashboard (Recomanat)

1. Obre el teu projecte a [Supabase Dashboard](https://supabase.com/dashboard)
2. Ves a **SQL Editor**
3. Copia el contingut de `supabase/migrations/20250130000007_fix_incompareixences_classificacions.sql`
4. Enganxa'l i executa'l

### Opció B: Via CLI de Supabase

```bash
supabase db push
```

### Opció C: Via PostgreSQL directament

```bash
psql "$SUPABASE_DB_URL" -f supabase/migrations/20250130000007_fix_incompareixences_classificacions.sql
```

## Verificació

Després d'aplicar la migració:

1. Registra una incompareixença des de l'aplicació
2. Comprova que:
   - El jugador present rep 2 punts amb 0 caramboles i 0 entrades
   - El jugador absent rep 0 punts amb 0 caramboles i `max_entrades` entrades
   - Les classificacions es calculen correctament
   - La mitjana del jugador present no es veu afectada
   - La mitjana del jugador absent baixa considerablement

## Casos de Prova

### Test 1: Incompareixença en categoria general (50 entrades)

**Abans**:
- Jugador A: 100 caramboles / 20 entrades = 5.000
- Jugador B: 50 caramboles / 10 entrades = 5.000

**Jugador B no es presenta**:
- Jugador A: 100 caramboles / 20 entrades = 5.000 (no canvia) ✓
- Jugador B: 50 caramboles / 60 entrades = 0.833 (baixa molt) ✓

### Test 2: Incompareixença en lliure 1a categoria (40 entrades)

**Abans**:
- Jugador A: 80 caramboles / 16 entrades = 5.000
- Jugador B: 40 caramboles / 8 entrades = 5.000

**Jugador B no es presenta**:
- Jugador A: 80 caramboles / 16 entrades = 5.000 (no canvia) ✓
- Jugador B: 40 caramboles / 48 entrades = 0.833 (baixa molt) ✓

## Compatibilitat

- ✅ Compatible amb dades existents
- ✅ La funció usa `COALESCE` per compatibilitat amb partides antigues
- ✅ No afecta partides ja validades
- ✅ Només afecta noves incompareixences registrades després de la migració

## Notes Importants

1. **Partides ja registrades**: Les incompareixences ja registrades amb els valors antics NO es modifiquen automàticament. Si es vol corregir històric, cal fer-ho manualment.

2. **Max_entrades per categoria**: Cada categoria té el seu propi `max_entrades`:
   - Lliure 1a categoria: normalment 40
   - Resta de categories: normalment 50
   - Es pot configurar per categoria a la taula `categories`

3. **Funció de classificacions**: Ja gestiona correctament els casos amb 0 entrades (no afecta la mitjana).

4. **Ordenació de classificacions**: Usa:
   1. Punts (DESC)
   2. Mitjana general (DESC) - NULL es tracta com 0
   3. Caramboles totals (DESC)
   4. Cognoms i nom (ASC)
