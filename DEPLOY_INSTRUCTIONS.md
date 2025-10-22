# Instruccions de Desplegament: Graella de Resultats Creuats

## ⚠️ IMPORTANT: Aplicar la Funció SQL

La funcionalitat de la graella de resultats creuats requereix una funció SQL a la base de dades de Supabase que **encara no està desplegada**.

## 📋 Passos per Desplegar

### Opció 1: Des del Dashboard de Supabase (RECOMANAT)

1. **Accedeix al Dashboard de Supabase**
   - Ves a: https://supabase.com/dashboard
   - Selecciona el teu projecte

2. **Obre l'Editor SQL**
   - Al menú lateral, clica a **"SQL Editor"**
   - Clica el botó **"New query"**

3. **Executa el Script**
   - Obre el fitxer `DEPLOY_HEAD_TO_HEAD.sql` d'aquest projecte
   - Copia **tot el contingut** del fitxer
   - Enganxa'l a l'editor SQL de Supabase
   - Clica el botó **"Run"** (o prem `Ctrl+Enter`)

4. **Verifica que s'ha Creat**
   - Hauries de veure un missatge: `SUCCESS: Function get_head_to_head_results created!`
   - Si hi ha errors, revisa els logs a la part inferior

### Opció 2: Amb Supabase CLI (Si el tens instal·lat)

```bash
# Des del directori del projecte
npx supabase db push

# O si tens supabase CLI instal·lat globalment
supabase db push
```

## 🔍 Verificar que Funciona

Després d'aplicar la migració:

1. Refresca la pàgina web (F5)
2. Navega a: `/admin/graella-resultats`
3. Selecciona una categoria
4. La graella hauria de carregar correctament

## ❌ Solució de Problemes

### Error: "Could not find the function public.get_head_to_head_results"

**Causa**: La funció no està desplegada a la base de dades.

**Solució**: Segueix els passos anteriors per executar el script SQL.

### Error: "permission denied for function get_head_to_head_results"

**Causa**: Els permisos no estan configurats correctament.

**Solució**:
1. Obre l'editor SQL de Supabase
2. Executa:
```sql
GRANT EXECUTE ON FUNCTION get_head_to_head_results(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_head_to_head_results(UUID, UUID) TO anon;
```

### No hi ha dades a la graella

**Causes possibles**:
1. No hi ha partides validades a la categoria seleccionada
2. Les partides no tenen resultats complets (caramboles i entrades)
3. El campionat no està en estat "en_curs"

**Solució**:
- Verifica que hi hagi partides amb estat `validat`
- Comprova que les partides tinguin `caramboles_jugador1`, `caramboles_jugador2` i `entrades`omplerts
- Assegura't que el campionat té `estat_competicio = 'en_curs'`

## 📁 Fitxers Relacionats

- `DEPLOY_HEAD_TO_HEAD.sql` - Script SQL per executar
- `supabase/migrations/20251022_add_head_to_head_function.sql` - Migració (mateixa funció)
- `supabase/sql/rpc_get_head_to_head_results.sql` - Còpia de referència
- `docs/GRAELLA_RESULTATS.md` - Documentació completa

## 🎯 Després del Desplegament

Un cop aplicada la migració, la funcionalitat estarà completament operativa:

- Ruta: `/admin/graella-resultats`
- Accés: Només administradors
- Visualització: Matriu de resultats entre jugadors d'una categoria

## 📞 Suport

Si tens problemes amb el desplegament:

1. Comprova els logs de Supabase a la consola SQL
2. Revisa que la taula `calendari_partides` existeix i té les columnes necessàries
3. Verifica que tens permisos d'administrador a Supabase

---

**Data de creació**: 2025-10-22
**Versió**: 1.0
**Autor**: Sistema de gestió de campionats de billar
