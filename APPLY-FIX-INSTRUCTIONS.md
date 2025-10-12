# Instruccions per aplicar el fix de la funció SQL

## Problema
La funció `get_social_league_classifications` té un error: **"column reference \"soci_numero\" is ambiguous"**

## Solució
Aplicar la versió v2 que no té aquest error.

## Com aplicar-ho:

### Opció 1: Dashboard de Supabase (Recomanat)
1. Ves a https://supabase.com/dashboard/project/qbldqtaqawnahuzlzsjs
2. SQL Editor → New query
3. Copia el contingut del fitxer: `supabase/sql/rpc_get_social_league_classifications_v2.sql`
4. Enganxa'l i executa (**Run**)
5. Hauries de veure: "Success. No rows returned"

### Opció 2: psql (si tens psql instal·lat)
```bash
psql "postgresql://postgres.qbldqtaqawnahuzlzsjs:Banyoles2026!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres" \
  -f supabase/sql/rpc_get_social_league_classifications_v2.sql
```

## Verificar que funciona:
Recarrega la pàgina de campionats socials i hauria de carregar les classificacions sense errors.

## Diferències entre v1 i v2:
- **v1**: Té un CTE `head_to_head` amb un problema de referència ambigua a `soci_numero`
- **v2**: NO té el CTE `head_to_head` problemàtic, funciona correctament
- **v2**: Afegeix la columna `categoria_distancia_caramboles` al resultat
