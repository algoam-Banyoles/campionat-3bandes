-- Bloqueig PII + reducció d'exposició a l'esquema GraphQL per a `anon`.
--
-- Canvis:
--   1) `is_admin_by_email()` passa a SECURITY DEFINER perquè continuï
--      retornant el resultat correcte un cop es restringeix el SELECT a
--      `admins` per a anon i (per RLS) per a non-admins authenticated.
--   2) Drop de la policy permissiva `sel_admins_public` a `admins` que
--      permetia a qualsevol llegir tots els correus admins. La policy
--      `un usuari pot veure si és admin` ja limita correctament al propi.
--   3) REVOKE SELECT de columnes PII (`email`, `data_naixement`) sobre
--      `socis` per a `anon`. Els authenticated mantenen accés per
--      compatibilitat amb el patró estés a la app de "find me by email".
--   4) REVOKE SELECT de taules administratives a `anon`:
--      `audit_log_socials`, `maintenance_runs`, `maintenance_run_items`,
--      `v_maintenance_runs`, `v_maintenance_run_details`,
--      `notification_history`, `notification_preferences`,
--      `push_subscriptions`, `scheduled_notifications`, `admins`.

----------------------------------------------------------------------
-- 1) is_admin_by_email() → SECURITY DEFINER
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin_by_email()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.admins a
    WHERE a.email = (auth.jwt() ->> 'email')
  );
$function$;

-- Es manté disponible per a anon i authenticated com fins ara.
GRANT EXECUTE ON FUNCTION public.is_admin_by_email() TO anon, authenticated;

----------------------------------------------------------------------
-- 2) Drop de la policy permissiva a admins
----------------------------------------------------------------------
DROP POLICY IF EXISTS "sel_admins_public" ON public.admins;

----------------------------------------------------------------------
-- 3) Restringir SELECT a anon a només columnes no-PII de socis
--    (El REVOKE columnar no funciona si anon té SELECT a nivell taula.
--     Cal revocar nivell taula i regrantar columnes específiques.)
----------------------------------------------------------------------
REVOKE SELECT ON public.socis FROM anon;
GRANT SELECT (numero_soci, cognoms, nom, de_baixa, data_baixa, foto_path)
  ON public.socis TO anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.socis FROM anon;

----------------------------------------------------------------------
-- 4) REVOKE SELECT de taules administratives/private a anon
----------------------------------------------------------------------
REVOKE SELECT ON public.admins FROM anon;
REVOKE SELECT ON public.audit_log_socials FROM anon;
REVOKE SELECT ON public.maintenance_runs FROM anon;
REVOKE SELECT ON public.maintenance_run_items FROM anon;
REVOKE SELECT ON public.notification_history FROM anon;
REVOKE SELECT ON public.notification_preferences FROM anon;
REVOKE SELECT ON public.push_subscriptions FROM anon;
REVOKE SELECT ON public.scheduled_notifications FROM anon;

-- Vistes — pot ser que no existeixin a tots els entorns.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'v_maintenance_runs' AND relnamespace = 'public'::regnamespace) THEN
    EXECUTE 'REVOKE SELECT ON public.v_maintenance_runs FROM anon';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'v_maintenance_run_details' AND relnamespace = 'public'::regnamespace) THEN
    EXECUTE 'REVOKE SELECT ON public.v_maintenance_run_details FROM anon';
  END IF;
END $$;
