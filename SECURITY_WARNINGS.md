# Supabase Security Warnings - Solucions

Aquest document explica els warnings de seguretat detectats pel Database Linter de Supabase i com solucionar-los.

## ⚠️ Warnings Detectats

### 1. Function Search Path Mutable (7 funcions) - ✅ SOLUCIONAT

**Problema:** Les funcions no tenen `SET search_path` definit, cosa que les fa vulnerables a atacs d'injecció de schema.

**Funcions afectades:**
- `get_social_league_classifications`
- `get_head_to_head_results`
- `get_retired_players`
- `reactivate_player_in_league`
- `retire_player_from_league`
- `update_page_content_updated_at`
- `registrar_incompareixenca`

**Solució:** ✅ **APLICADA**

Executa el script PowerShell:
```powershell
.\Apply-SecurityFixes.ps1
```

O aplica manualment l'SQL:
```bash
psql $SUPABASE_DB_URL < supabase/sql/fix_security_warnings.sql
```

**Què fa:**
- Afegeix `SET search_path = public` a cada funció
- Això força les funcions a només utilitzar l'schema `public`
- Prevé que un atacant pugui crear un schema maliciós i fer que la funció l'utilitzi

**Documentació:** https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable

---

### 2. Leaked Password Protection Disabled - ⚠️ ACCIÓ MANUAL REQUERIDA

**Problema:** La protecció contra contrasenyes compromeses està desactivada.

**Risc:** Els usuaris poden utilitzar contrasenyes que han estat filtrades en violacions de dades conegudes.

**Solució:** 🔧 **ACCIÓ MANUAL REQUERIDA**

1. Ves al Dashboard de Supabase: https://supabase.com/dashboard
2. Selecciona el teu projecte
3. Navega a: **Authentication** > **Policies** > **Password**
4. Activa **"Leaked Password Protection"**
5. Això verificarà les contrasenyes contra la base de dades HaveIBeenPwned

**Documentació:** https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

---

### 3. Vulnerable Postgres Version - ⚠️ ACCIÓ MANUAL REQUERIDA

**Problema:** La versió actual de PostgreSQL (supabase-postgres-17.4.1.075) té pegats de seguretat disponibles.

**Risc:** Vulnerabilitats de seguretat conegudes no pegades.

**Solució:** 🔧 **ACCIÓ MANUAL REQUERIDA**

1. Ves al Dashboard de Supabase: https://supabase.com/dashboard
2. Selecciona el teu projecte
3. Navega a: **Settings** > **Infrastructure** > **Database**
4. Busca la secció **"Postgres version"**
5. Clica **"Upgrade"** si està disponible
6. Segueix les instruccions per actualitzar

⚠️ **IMPORTANT:** 
- Fes un backup abans d'actualitzar
- L'actualització pot requerir downtime
- Prova en un entorn de desenvolupament primer si és possible

**Documentació:** https://supabase.com/docs/guides/platform/upgrading

---

## 📊 Resum de l'Estat

| Warning | Estat | Acció |
|---------|-------|-------|
| Function Search Path Mutable (7) | ✅ Solucionat | Script aplicat |
| Leaked Password Protection | ⚠️ Pendent | Activar al Dashboard |
| Vulnerable Postgres Version | ⚠️ Pendent | Actualitzar al Dashboard |

---

## 🔍 Verificació

Després d'aplicar les correccions, pots verificar l'estat amb aquesta query SQL:

```sql
-- Verificar que les funcions tenen search_path
SELECT 
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  CASE 
    WHEN pg_get_functiondef(p.oid) LIKE '%SET search_path%' THEN '✅ Protected'
    ELSE '⚠️ Vulnerable'
  END as security_status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname IN (
    'get_social_league_classifications',
    'get_head_to_head_results',
    'get_retired_players',
    'reactivate_player_in_league',
    'retire_player_from_league',
    'update_page_content_updated_at',
    'registrar_incompareixenca'
  )
ORDER BY p.proname;
```

---

## 📚 Referències

- **Database Linter:** https://supabase.com/docs/guides/database/database-linter
- **Security Best Practices:** https://supabase.com/docs/guides/database/postgres/configuration
- **Function Security:** https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY

---

## 📝 Notes Addicionals

### Per què és important SET search_path?

Quan una funció s'executa amb `SECURITY DEFINER`, s'executa amb els permisos del creador de la funció (usualment un superusuari). Si un atacant pot crear un schema amb el mateix nom que un dels schemas al `search_path`, podria interceptar les crides de la funció.

**Exemple d'atac:**
```sql
-- Atacant crea un schema maliciós
CREATE SCHEMA malicious;
CREATE TABLE malicious.socis (
  -- Taula falsa que retorna dades malicioses
);

-- Si la funció no té SET search_path, podria utilitzar aquest schema
```

**Amb SET search_path = public:**
```sql
CREATE FUNCTION my_function()
SECURITY DEFINER
SET search_path = public  -- ✅ Només utilitza 'public'
AS $$
  -- Ara només pot accedir a public.socis
$$;
```

---

**Data de creació:** 30 d'octubre de 2025  
**Última actualització:** 30 d'octubre de 2025
