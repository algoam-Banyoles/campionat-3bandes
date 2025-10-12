# Checklist: Funcionalitat de Retirada de Jugadors

## ✅ Completat al Codi

### 1. Types TypeScript
- [x] Afegits camps `estat_jugador`, `data_retirada`, `motiu_retirada` a `Inscripcio`
- [x] Afegit estat `'cancel·lada_per_retirada'` a `EstatPartida`
- **Fitxer**: `src/lib/types/index.ts`

### 2. Pàgina Admin d'Inscripcions
- [x] Diàleg modal per retirar jugadors amb camp de motiu
- [x] Funció `withdrawPlayer()` que marca jugador com retirat i cancel·la partides
- [x] Botó taronja de retirada a la taula d'inscripcions
- [x] Badge "Retirat" vermell al nom del jugador
- [x] Motiu visible sota el nom
- [x] Data de retirada mostrada
- [x] Botons desactivats per jugadors retirats
- **Fitxer**: `src/routes/admin/inscripcions-socials/+page.svelte`

### 3. Grid de Jugadors per Categoria
- [x] Badge "R" vermell per jugadors retirats
- [x] Nom tatxat i en gris
- [x] Avatar gris en lloc de blau
- [x] Opacitat reduïda
- **Fitxer**: `src/lib/components/campionats-socials/SocialLeaguePlayersGrid.svelte`

### 4. Taula de Classificacions
- [x] Badge "Retirat" vermell (vista desktop)
- [x] Badge "R" petit (vista mòbil)
- [x] Nom tatxat i en gris
- [x] Tooltip amb motiu de retirada
- **Fitxer**: `src/lib/components/campionats-socials/SocialLeagueClassifications.svelte`

### 5. Calendari de Partides
- [x] Partides amb estat `'cancel·lada_per_retirada'` ja es filtren automàticament
- [x] La funció RPC `get_calendar_matches_public` només mostra estats: 'generat', 'validat', 'publicat'
- **Fitxer**: `supabase/sql/rpc_get_calendar_matches_public.sql` (NO CAL MODIFICAR)

## ⚠️ PENDENT: Aplicar SQL al Cloud

Has d'executar **2 scripts SQL** manualment al Supabase SQL Editor:

### Script 1: RPC per Inscripcions amb camps de retirada
**Fitxer**: `supabase/sql/rpc_get_inscripcions_with_socis.sql`

```sql
-- Drop existing function first to allow changing return type
DROP FUNCTION IF EXISTS get_inscripcions_with_socis(UUID);

CREATE OR REPLACE FUNCTION get_inscripcions_with_socis(p_event_id UUID)
RETURNS TABLE (
  id UUID,
  event_id UUID,
  soci_numero INTEGER,
  categoria_assignada_id UUID,
  data_inscripcio TIMESTAMPTZ,
  preferencies_dies TEXT[],
  preferencies_hores TEXT[],
  restriccions_especials TEXT,
  observacions TEXT,
  pagat BOOLEAN,
  confirmat BOOLEAN,
  created_at TIMESTAMPTZ,
  -- Withdrawal fields
  estat_jugador TEXT,
  data_retirada TIMESTAMPTZ,
  motiu_retirada TEXT,
  -- Socis information
  nom TEXT,
  cognoms TEXT,
  email TEXT,
  de_baixa BOOLEAN
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    i.id,
    i.event_id,
    i.soci_numero,
    i.categoria_assignada_id,
    i.data_inscripcio,
    i.preferencies_dies,
    i.preferencies_hores,
    i.restriccions_especials,
    i.observacions,
    i.pagat,
    i.confirmat,
    i.created_at,
    i.estat_jugador,
    i.data_retirada,
    i.motiu_retirada,
    s.nom,
    s.cognoms,
    s.email,
    s.de_baixa
  FROM inscripcions i
  INNER JOIN socis s ON i.soci_numero = s.numero_soci
  WHERE i.event_id = p_event_id
    AND s.de_baixa = false
    AND i.confirmat = true
  ORDER BY s.cognoms ASC, s.nom ASC;
$$;

GRANT EXECUTE ON FUNCTION get_inscripcions_with_socis(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_inscripcions_with_socis(UUID) TO authenticated;

COMMENT ON FUNCTION get_inscripcions_with_socis(UUID) IS
'Returns inscriptions with member data for public access in social championships. Filters only confirmed registrations from active members.';
```

**Status**: ✅ JA APLICAT (segons els teus missatges anteriors)

---

### Script 2: RPC per Classificacions amb jugadors retirats
**Fitxer**: `supabase/sql/rpc_get_social_league_classifications.sql`

**Status**: ⚠️ **PENDENT D'APLICAR**

Aquest és el que has de copiar i executar ara. Inclou 199 línies que:
- Retornen els camps `estat_jugador`, `data_retirada`, `motiu_retirada`
- Mostren TOTS els jugadors inscrits (inclosos els retirats amb 0 partides)

---

## 🧪 Com Verificar que Funciona

### 1. Després d'aplicar els SQL:

**A la pàgina d'Admin** (`/admin/inscripcions-socials`):
- [ ] Veus el botó taronja de retirada per cada jugador actiu
- [ ] En fer click s'obre un diàleg per introduir el motiu
- [ ] Després de confirmar, el jugador apareix amb badge "Retirat"

**A la pàgina de Classificacions**:
- [ ] El jugador Manuel Sánchez Molera (Soci #7967) apareix a la 2a Categoria
- [ ] Té un badge "Retirat" vermell
- [ ] El seu nom està tatxat i en gris
- [ ] En passar el cursor sobre el badge, es veu el motiu: "Problemes de salut"
- [ ] Mostra 0 partides jugades, 0 punts

**Al Grid de Jugadors** (`/campionats-socials`):
- [ ] Manuel Sánchez Molera apareix a la 2a Categoria
- [ ] Té un badge "R" vermell petit
- [ ] El nom està tatxat i en gris
- [ ] L'avatar és gris en lloc de blau

**Al Calendari**:
- [ ] Les 9 partides cancel·lades de Manuel NO apareixen
- [ ] Els slots d'aquestes partides queden disponibles

### 2. Prova de retirada d'un nou jugador:

- [ ] Tria un jugador actiu amb partides programades
- [ ] Fes click al botó taronja de retirada
- [ ] Introdueix un motiu (ex: "Proves")
- [ ] Confirma
- [ ] Verifica que:
  - Apareix amb badge "Retirat"
  - Les seves partides no jugades desapareixen del calendari
  - Apareix a les classificacions amb el badge

## 📋 Què falta?

### NOMÉS això:

1. **Aplicar el SQL de classificacions** (Script 2 de dalt)
   - Copia tot el contingut de `supabase/sql/rpc_get_social_league_classifications.sql`
   - Ves a: https://supabase.com/dashboard/project/qbldqtaqawnahuzlzsjs/sql/new
   - Enganxa i executa

2. **Refresca les pàgines** després d'aplicar l'SQL

## 🎯 Resum

**Codi PWA**: ✅ 100% Completat
**Base de dades**: ✅ Ja té els camps necessaris
**SQL a aplicar**: ⚠️ 1 script pendent (classificacions)

Després d'aplicar aquest últim SQL, la funcionalitat estarà **completament operativa**! 🚀
