# Base de Dades - Funcions i Schema Actualitzat

**Generat**: ${new Date().toLocaleString('ca-ES')}

## 📊 Resum

Aquest document conté l'schema actualitzat de la base de dades amb totes les taules, vistes i funcions RPC.

### Taules Principals

1. **socis** - Informació dels socis del club
2. **calendari_partides** - Partides programades i jugades
3. **mitjanes_historiques** - Mitjanes històriques per any
4. **esdeveniments_club** - Esdeveniments del calendari
5. **page_content** - Contingut editable de les pàgines web

### Funcions RPC Principals

- `get_real_classifications()` - Classificació del campionat continu
- `get_social_league_classifications(league_id)` - Classificació d'una lliga social
- `get_match_results(player_id)` - Resultats d'un jugador específic

## 📁 Arxius SQL Actualitzats

### Schema Principal
- **schema-cloud.sql** - Schema complet amb taules, vistes, funcions i RLS

### Funcions RPC (carpeta supabase/sql/)
- `rpc_get_classifications_public.sql` - Classificacions públiques
- `rpc_get_social_league_classifications.sql` - Classificacions lligues socials
- `rpc_get_match_results_public.sql` - Resultats de partides
- `rpc_get_calendar_matches_public.sql` - Partides del calendari
- `rpc_get_inscripcions_with_socis.sql` - Inscripcions amb dades dels socis

### Vistes
- `v_player_badges.sql` - Vista amb estadístiques i badges dels jugadors

### RLS (Row Level Security)
- `rls_challenges.sql` - Polítiques per reptes
- `fix_socis_public_access.sql` - Accés públic a socis

## 🔄 Estat de Sincronització

✅ **schema-cloud.sql** - Actualitzat amb l'estructura real de la base de dades
✅ **Taules** - 5 taules principals documentades
✅ **Funcions** - 3 funcions principals documentades
✅ **Polítiques RLS** - Incloses per cada taula

## 📝 Notes Importants

1. L'schema ha estat generat automàticament consultant les taules accessibles
2. Els tipus de dades i constraints són aproximacions basades en les dades reals
3. Per un schema 100% precís, utilitza: `supabase db dump -f schema.sql`

## 🚀 Com utilitzar

### Aplicar l'schema a una nova base de dades:
```bash
psql -h HOST -U USER -d DATABASE -f schema-cloud.sql
```

### Actualitzar funcions individuals:
```bash
psql -h HOST -U USER -d DATABASE -f supabase/sql/rpc_get_classifications_public.sql
```

### Verificar funcions existents:
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_type = 'FUNCTION';
```

## 📦 Properes accions recomanades

1. ✅ Revisar i aplicar `create-page-content-table.sql` per la nova funcionalitat CMS
2. ⏳ Fer backup regular de l'schema: `supabase db dump`
3. ⏳ Documentar nous canvis al schema quan es facin migracions
