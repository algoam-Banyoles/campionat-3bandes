# Fix: Graella amb entrades en blanc i us correcte d'entrades i punts individuals

## Problemes
1. A la pàgina `http://127.0.0.1:5173/campionats-socials?view=active`, la graella de resultats creuats (head-to-head) mostrava totes les entrades en blanc.
2. La funció `get_head_to_head_results` no utilitzava les columnes individuals `entrades_jugador1`, `entrades_jugador2`, `punts_jugador1` i `punts_jugador2` que ja existien a la base de dades.

## Causes
Els problemes tenien diverses causes relacionades:

1. **RLS (Row Level Security) en la funció `get_head_to_head_results`**: La funció estava marcada com `SECURITY DEFINER` però no tenia `SET search_path = public`, la qual cosa podia causar problemes amb les polítiques RLS de la taula `socis`.

2. **Gestió de valors NULL al codi JavaScript**: El codi feia servir `a.nom.localeCompare(b.nom, 'ca')` sense comprovar si `nom` era null o undefined. Si la base de dades retornava NULL per als noms (per problemes RLS), això causava un error que feia que la graella es mostrés buida.

3. **La funció no utilitzava les columnes individuals**: Tot i que la taula `calendari_partides` ja té les columnes `entrades_jugador1`, `entrades_jugador2`, `punts_jugador1` i `punts_jugador2`, la funció `get_head_to_head_results` no les utilitzava correctament.

## Solució implementada

### 1. Migració de base de dades
S'ha creat la migració [`supabase/migrations/20251103_fix_head_to_head_rls.sql`](supabase/migrations/20251103_fix_head_to_head_rls.sql) que:

#### Actualitzacions a la funció:
- **Migra dades existents**: Copia el valor de `entrades` compartida a les columnes individuals per partides que encara no tenen aquests valors
- **Calcula punts**: Popula automàticament `punts_jugador1` i `punts_jugador2` per partides validades que no tenen aquests valors
- **Actualitza la funció `get_head_to_head_results`**:
  - Afegeix `SET search_path = public` per solucionar problemes RLS
  - Retorna `entrades_jugador1`, `entrades_jugador2`, `punts_jugador1` i `punts_jugador2` de la base de dades
  - Utilitza `COALESCE` per compatibilitat amb dades antigues que només tenen la columna `entrades` compartida
  - Calcula la mitjana correctament per cada jugador amb les seves pròpies entrades
- **Atorga permisos**: `GRANT EXECUTE TO authenticated, anon`
- **Millora l'ordenació**: Per cognoms primer, després per nom

#### Compatibilitat enrere:
La funció utilitza `COALESCE(cp.entrades_jugador1, cp.entrades)` i `COALESCE(cp.punts_jugador1, CASE...)` per assegurar que funciona amb dades antigues.

#### Sistema de punts (ja implementat):
- **Partida normal**: Guanyador 2 punts, empat 1 punt, perdedor 0 punts
- **Incompareixença**: Presentat 2 punts amb 0 caramboles i 0 entrades, no presentat 0 punts amb 0 caramboles i 50 entrades

### 2. Millores al codi JavaScript
S'ha actualitzat [`src/lib/api/socialLeagues.ts`](src/lib/api/socialLeagues.ts):
- **Utilitza valors guardats**: Usa `entrades_jugador1`, `entrades_jugador2`, `punts_jugador1` i `punts_jugador2` de la base de dades
- **Calcula mitjana correcta**: Cada jugador amb les seves pròpies entrades
- **Gestió de punts**: Usa els punts guardats (que inclouen casos d'incompareixença) amb fallback a càlcul si no existeixen
- Filtra jugadors amb dades mancants (nom o cognoms null)
- Gestiona correctament valors null/undefined en l'ordenació
- Afegeix logging detallat per identificar problemes
- Ordena per cognoms primer, després per nom

### 3. Components frontend actualitzats
S'ha actualitzat [`src/lib/components/campionats-socials/SocialLeagueMatchResults.svelte`](src/lib/components/campionats-socials/SocialLeagueMatchResults.svelte):
- **Formulari d'edició**: Ara mostra dos camps separats per les entrades de cada jugador
- **Etiquetes clares**: Cada camp mostra el nom del jugador corresponent
- **Càlcul de mitjanes**: Les mitjanes es calculen individualment per cada jugador en temps real

## Com aplicar la migració

### Opció A: Via Supabase Dashboard (Recomanat)
1. Obre el teu projecte a [Supabase Dashboard](https://supabase.com/dashboard)
2. Ves a **SQL Editor**
3. Copia el contingut de [`supabase/migrations/20251103_fix_head_to_head_rls.sql`](supabase/migrations/20251103_fix_head_to_head_rls.sql)
4. Enganxa'l i executa'l

### Opció B: Via CLI de Supabase
```bash
supabase db push
```

### Opció C: Via PostgreSQL directament (si tens accés)
```bash
psql "$SUPABASE_DB_URL" -f supabase/migrations/20251103_fix_head_to_head_rls.sql
```

## Verificació

Després d'aplicar els canvis:

1. Recarrega l'aplicació
2. Ves a `http://localhost:5173/campionats-socials?view=active`
3. Selecciona la pestanya "🔲 Graelles"
4. Comprova que es mostren els noms dels jugadors a la graella amb les seves mitjanes i punts correctes
5. Verifica que els casos d'incompareixença es mostren correctament (2 punts vs 0 punts)

Si encara hi ha problemes, obre la consola del navegador i comprova els missatges de log per identificar si hi ha jugadors amb dades mancants.

## Logging afegit

El codi ara inclou logging que t'ajudarà a identificar problemes:
- `Fetching head-to-head results for:` - Mostra l'event i categoria
- `Received X match records from database` - Confirma que s'han rebut dades
- `Extracted X unique players` - Mostra quants jugadors únics s'han trobat
- `Warning: X players have missing nom or cognoms:` - Alerta si hi ha jugadors sense noms
- `Returning X valid players and Y match records` - Confirma les dades finals

## Impacte en dades existents

- **Dades migrades automàticament**: Les partides amb només `entrades` compartida es migraran automàticament a columnes individuals
- **Punts calculats**: Les partides validades sense punts els tindran calculats automàticament
- **Compatibilitat**: La funció usa `COALESCE` per funcionar amb ambdós formats
- **Casos especials preservats**: Les incompareixences (ja implementades) es mantenen correctament

## Arxius modificats

1. [`supabase/migrations/20251103_fix_head_to_head_rls.sql`](supabase/migrations/20251103_fix_head_to_head_rls.sql) - Migració que actualitza funció per usar columnes individuals
2. [`src/lib/api/socialLeagues.ts`](src/lib/api/socialLeagues.ts) - Utilitza entrades i punts individuals de la base de dades
3. [`src/lib/components/campionats-socials/SocialLeagueMatchResults.svelte`](src/lib/components/campionats-socials/SocialLeagueMatchResults.svelte) - Formulari amb camps separats per entrades de cada jugador

## Beneficis

✅ **Precisió**: Cada jugador té les seves pròpies entrades i punts, permetent càlculs exactes
✅ **Compatibilitat**: Funciona amb dades antigues gràcies a `COALESCE`
✅ **Seguretat**: Resolt problema RLS amb `SET search_path = public`
✅ **Usabilitat**: Interfície clara amb camps separats per cada jugador
✅ **Robustesa**: Gestió correcta de valors NULL, errors i casos especials (incompareixences)
✅ **Dades correctes**: Usa els punts guardats que inclouen tots els casos (partides normals i incompareixences)
