# Fix: Entrades no es calculaven correctament en classificacions

## Problema

A la pàgina de campionats socials (`/campionats-socials?view=active`), les **entrades_totals** de cada jugador no es calculaven correctament.

La funció `get_social_league_classifications` utilitzava el camp `cp.entrades` (compartit per ambdós jugadors) en lloc dels camps individuals `entrades_jugador1` i `entrades_jugador2`.

## Impacte

- Les **mitjanes** es calculaven incorrectament
- Les **classificacions** podien estar ordenades malament
- Les **entrades totals** no reflectien els valors reals de cada jugador
- Especialment important en casos d'**incompareixences** on cada jugador té entrades diferents

## Exemple del Problema

### Abans (INCORRECTE)
```sql
SELECT cp.entrades  -- Sempre el mateix valor per ambdós jugadors
```

**Partida amb incompareixença:**
- Jugador 1 (absent): 50 entrades
- Jugador 2 (present): 0 entrades
- **Valor de `cp.entrades`**: 50

La funció assignava 50 entrades a AMBDÓS jugadors ❌

### Després (CORRECTE)
```sql
CASE
  WHEN cp.jugador1_id = p.id THEN COALESCE(cp.entrades_jugador1, cp.entrades, 0)
  WHEN cp.jugador2_id = p.id THEN COALESCE(cp.entrades_jugador2, cp.entrades, 0)
  ELSE 0
END as entrades
```

Ara cada jugador obté les seves pròpies entrades ✅

## Solució Implementada

### Migració: `20250130000008_fix_entrades_classifications.sql`

Actualitza la funció `get_social_league_classifications` per:

1. **Utilitzar camps individuals**: `entrades_jugador1` i `entrades_jugador2`
2. **Fallback a camp compartit**: Si els camps individuals estan buits, usar `entrades`
3. **Compatibilitat**: Funciona amb dades antigues i noves

### Codi Clau

```sql
-- Abans
cp.entrades  -- ❌ Mateix valor per ambdós

-- Després  
CASE
  WHEN cp.jugador1_id = p.id THEN COALESCE(cp.entrades_jugador1, cp.entrades, 0)
  WHEN cp.jugador2_id = p.id THEN COALESCE(cp.entrades_jugador2, cp.entrades, 0)
  ELSE 0
END as entrades  -- ✅ Valor individual per cada jugador
```

## Exemple Pràctic

### Partida Normal
- **Jugador A**: 100 caramboles, 20 entrades
- **Jugador B**: 80 caramboles, 20 entrades

**Abans**: Ambdós sumaven 20 entrades ✅ (correcte)  
**Després**: Ambdós sumen 20 entrades ✅ (correcte)

### Partida amb Incompareixença
- **Jugador A** (present): 0 caramboles, 0 entrades
- **Jugador B** (absent): 0 caramboles, 50 entrades

**Abans**: Ambdós sumaven 50 entrades ❌ (incorrecte)  
**Després**: A suma 0, B suma 50 ✅ (correcte)

### Impacte en Mitjana

**Jugador A** amb 2 partides:
1. Partida normal: 100 car / 20 ent
2. Incompareixença (present): 0 car / 0 ent

**Abans**:
- Total: 100 car / 70 ent = **1.429** ❌ (incorrecte)

**Després**:
- Total: 100 car / 20 ent = **5.000** ✅ (correcte)

## Com Aplicar la Migració

### Opció A: Via Supabase Dashboard (Recomanat)

1. Obre el teu projecte a [Supabase Dashboard](https://supabase.com/dashboard)
2. Ves a **SQL Editor**
3. Copia el contingut de `supabase/migrations/20250130000008_fix_entrades_classifications.sql`
4. Enganxa'l i executa'l (Run)

### Opció B: Via CLI de Supabase

```bash
supabase db push
```

### Opció C: Via PowerShell

```powershell
.\Apply-FixEntrades.ps1
```

## Verificació

Després d'aplicar la migració:

1. Recarrega la pàgina `/campionats-socials?view=active`
2. Comprova les classificacions a la pestanya "📊 Classificació"
3. Verifica que:
   - Les **entrades totals** són correctes
   - Les **mitjanes** són coherents
   - Els jugadors amb incompareixences (presentscompten) tenen entrades = 0

## Test de Verificació

Pots executar aquesta query per verificar:

```sql
-- Veure entrades per cada jugador en una partida
SELECT 
  cp.id,
  s1.nom as jugador1,
  cp.entrades_jugador1,
  s2.nom as jugador2,
  cp.entrades_jugador2,
  cp.entrades as entrades_compartida,
  cp.incompareixenca_jugador1,
  cp.incompareixenca_jugador2
FROM calendari_partides cp
LEFT JOIN players p1 ON cp.jugador1_id = p1.id
LEFT JOIN socis s1 ON p1.numero_soci = s1.numero_soci
LEFT JOIN players p2 ON cp.jugador2_id = p2.id
LEFT JOIN socis s2 ON p2.numero_soci = s2.numero_soci
WHERE cp.estat = 'validat'
  AND cp.event_id = 'YOUR_EVENT_ID'
ORDER BY cp.data_joc DESC
LIMIT 10;
```

## Compatibilitat

- ✅ Compatible amb partides antigues (usa fallback a `entrades`)
- ✅ Compatible amb partides noves (usa `entrades_jugador1/2`)
- ✅ Compatible amb incompareixences
- ✅ No modifica dades existents
- ✅ Només actualitza la funció de càlcul

## Relació amb Altres Fixes

Aquest fix està relacionat amb:
- [FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md](FIX_INCOMPAREIXENCES_CLASSIFICACIONS.md) - Correcció de regles d'incompareixences
- [FIX_GRAELLA_BLANK_ENTRIES.md](FIX_GRAELLA_BLANK_ENTRIES.md) - Correcció de graella amb entrades individuals

## Notes Importants

1. **Dades migrades**: Les partides antigues amb només `entrades` compartida continuen funcionant gràcies al `COALESCE`
2. **Noves partides**: Haurien de guardar sempre `entrades_jugador1` i `entrades_jugador2`
3. **Formularis**: Assegura't que els formularis d'entrada de resultats envien els camps individuals

---

**Data**: 27 Gener 2026  
**Migració**: 20250130000008_fix_entrades_classifications.sql  
**Relacionat amb**: Migracions 001-007 d'incompareixences
