# Funcionalitat de Retirada de Jugadors Restaurada

## Resum

S'ha restaurat la funcionalitat completa per retirar jugadors d'un campionat social, incloent:

- ✅ Marcar jugadors com a retirats amb motiu
- ✅ Cancel·lar automàticament les seves partides programades
- ✅ Mostrar badge "Retirat" a les classificacions i llistes de jugadors
- ✅ Filtrar partides cancel·lades del calendari públic

## Camps a la Base de Dades

La taula `inscripcions` ja té els següents camps al cloud:

```sql
estat_jugador TEXT          -- 'actiu' | 'retirat'
data_retirada TIMESTAMPTZ   -- Data de retirada
motiu_retirada TEXT         -- Motiu de la retirada
```

La taula `calendari_partides` ja suporta l'estat:

```sql
estat TEXT  -- Inclou 'cancel·lada_per_retirada'
```

## Fitxers Modificats

### 1. Types TypeScript
**Fitxer**: `src/lib/types/index.ts`

- Afegits camps de retirada a la interface `Inscripcio` (línies 137-140)
- Afegit `'cancel·lada_per_retirada'` al tipus `EstatPartida` (línia 14)

### 2. Pàgina Admin d'Inscripcions
**Fitxer**: `src/routes/admin/inscripcions-socials/+page.svelte`

**Noves variables** (línies 37-41):
```javascript
let withdrawalDialogOpen = false;
let selectedInscriptionForWithdrawal = null;
let withdrawalReason = '';
let processingWithdrawal = false;
```

**Noves funcions** (línies 623-684):
- `openWithdrawalDialog(inscription)` - Obre el diàleg de retirada
- `withdrawPlayer()` - Processa la retirada del jugador

**UI modificada**:
- Badge "Retirat" al nom del jugador (línies 1437-1443)
- Motiu de retirada sota el nom (línies 1448-1452)
- Botó de retirada a la columna d'accions (línies 1513-1522)
- Diàleg modal per introduir motiu (línies 1557-1609)

### 3. Grid de Jugadors per Categoria
**Fitxer**: `src/lib/components/campionats-socials/SocialLeaguePlayersGrid.svelte`

**Modificacions**:
- Afegits camps de retirada al mapatge de dades (línies 84-86)
- Badge "R" vermell per jugadors retirats (línia 219)
- Estil tatxat i gris per noms de retirats (línia 215)
- Avatar gris per jugadors retirats (línia 212)

### 4. Funció RPC per Inscripcions
**Fitxer**: `supabase/sql/rpc_get_inscripcions_with_socis.sql`

**Actualitzada** per retornar els camps de retirada (línies 19-22, 46-48)

⚠️ **IMPORTANT**: Aquest fitxer SQL s'ha de aplicar manualment a Supabase:

1. Ves a: https://supabase.com/dashboard/project/qbldqtaqawnahuzlzsjs/sql/new
2. Copia i enganxa el contingut de `supabase/sql/rpc_get_inscripcions_with_socis.sql`
3. Executa l'SQL

## Com Funciona

### Procés de Retirada

1. **Admin obre diàleg**: Click al botó taronja de retirada
2. **Introdueix motiu**: Text obligatori explicant la retirada
3. **Confirmació**: Es marca el jugador com a retirat
4. **Cancel·lació automàtica**: Totes les partides programades (no jugades) es cancel·len
5. **Actualització**: El jugador apareix amb badge "Retirat"

### Visualització

#### Taula d'Inscripcions (Admin)
- Badge vermell "Retirat" al costat del nom
- Motiu de retirada visible sota el nom
- Data de retirada a la columna d'accions
- Botons d'edició desactivats per jugadors retirats

#### Grid de Jugadors per Categoria (Públic)
- Nom tatxat i en gris
- Avatar gris en lloc de blau
- Badge "R" vermell petit al costat del nom
- Opacitat reduïda del 60%

#### Calendari de Partides
- Les partides cancel·lades per retirada NO es mostren al calendari públic
- El filtre existent ja exclou estat `'cancel·lada_per_retirada'`

## Estat Actual a la Base de Dades

Hi ha **1 jugador retirat** al cloud:

```
Nom: Manuel Sánchez Molera
Soci #: 7967
Event: Campionat Social 3 Bandes (2025-2026)
Categoria: 2a Categoria
Estat: retirat
Data retirada: 2025-10-08
Motiu: Problemes de salut
Partides cancel·lades: 9
```

## Tasques Pendents

### Aplicar SQL Manualment
Cal executar l'SQL actualitzat per la funció RPC:
- **Fitxer**: `supabase/sql/rpc_get_inscripcions_with_socis.sql`
- **Dashboard**: https://supabase.com/dashboard/project/qbldqtaqawnahuzlzsjs/sql/new

### Proves Recomanades

1. **Retirar un jugador de prova**:
   - Verificar que el diàleg funciona
   - Comprovar que les partides es cancel·len
   - Confirmar que apareix el badge

2. **Visualització pública**:
   - Veure que el jugador apareix tatxat
   - Confirmar que les partides no surten al calendari

3. **Classificacions**:
   - Verificar que el jugador retirat apareix amb el badge

## Notes Importants

- ❌ **NO es pot reactivar** un jugador retirat (decisió de disseny)
- ✅ Les partides ja jugades NO es cancel·len
- ✅ Només es cancel·len partides amb estat diferent de 'jugada'
- ✅ El calendari públic ja filtra automàticament les partides cancel·lades

## Scripts d'Ajuda

S'han creat scripts temporals per verificar l'estat:

- `check-inscripcions-schema.js` - Verifica l'esquema de la taula
- `check-withdrawn-player.js` - Mostra detalls del jugador retirat
- `apply-rpc-update.js` - Intent d'aplicar SQL (cal fer-ho manualment)

Aquests scripts es poden eliminar després de verificar que tot funciona.

## Contacte

Per qualsevol dubte o problema, revisa aquest document o consulta els logs del navegador.
