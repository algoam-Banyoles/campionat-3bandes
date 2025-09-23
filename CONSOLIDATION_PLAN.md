# Pla de Consolidació: Eliminació de Redundància Players/Socis

## Resum de la consolidació

La consolidació elimina la redundància entre `players` i `socis` unificant-ho en una arquitectura multi-event més neta:

### Canvis d'esquema realitzats:

1. **Taula `socis` expandida:**
   - Afegit `id` (UUID) com a clau primària
   - Afegit `club`, `avatar_url`, `creat_el`, `actualitzat_el`
   - Mantingut `telefon`, `de_baixa`

2. **Taules per event:**
   - `ranking_positions`: Afegit `mitjana`, `estat`, `data_ultim_repte`
   - `waiting_list`: Afegit `estat`, `data_ultim_repte`

3. **Eliminació de `players`:**
   - Migració de dades a `socis`
   - Actualització de claus foranes a totes les taules relacionades

### Fitxers creats/actualitzats:

#### ✅ Completats:
1. **Migration script**: `supabase/migrations/005_consolidate_players_socis.sql`
2. **Updated queries**: `src/lib/database/queries_updated.ts`
3. **Inscription page**: Parcialmente actualitzat `src/routes/inscripcio/+page.svelte`

#### ✅ Completats:
1. **Reemplaçat** `src/lib/database/queries.ts` amb versió actualitzada
2. **Actualitzats components clau:**
   - ✅ `src/routes/ranking/+page.svelte`
   - ✅ `src/routes/classificacio/+page.svelte`
   - ✅ `src/lib/rankingStore.ts`
   - ✅ `src/lib/challengeStore.ts`
   - ✅ `src/routes/reptes/+page.svelte`
   - ✅ `src/routes/llista-espera/+page.svelte`
   - ✅ `src/routes/inscripcio/+page.svelte`

3. **Actualitzats endpoints API massivament:**
   - ✅ Reemplaçat `.from('players')` per `.from('socis')` en tots els fitxers
   - ✅ Actualitzada lògica de queries per usar estructura consolidada

#### 📋 Pendent (Testing):
4. **Actualitzar funcions SQL** que referencien `players`:
   - Cerca al migration script per funcions que usen `players`
   - Actualitzar triggers i stored procedures manualment

5. **Testing complet:**
   - Ranking display
   - Challenge creation/completion
   - User registration
   - Admin functions

## Beneficis de la consolidació:

✅ **Eliminació de redundància**: No més duplicació nom/email
✅ **Arquitectura multi-event**: Permet múltiples campionats
✅ **Millor rendiment**: Menys JOINs complexos
✅ **Manteniment simplificat**: Una sola font de veritat per soci
✅ **Escalabilitat**: Preparada per nous tipus d'events

## Passos següents:

1. **Executar la migració** en entorn de desenvolupament
2. **Reemplaçar** `queries.ts` amb la versió actualitzada
3. **Actualitzar** components un per un
4. **Testing** exhaustiu abans de production
5. **Backup** complet abans del deploy

## Notes importants:

⚠️ **Backup obligatori** abans d'executar la migració
⚠️ **Testing exhaustiu** en desenvolupament primer
⚠️ **Revisar funcions SQL** manualment
⚠️ **Actualitzar RLS policies** si n'hi ha