-- Funció atòmica per renumerar un soci i propagar totes les FK en una sola transacció.
--
-- Objectiu:
--   Substituir el bucle multi-step amb compensating rollback manual de
--   src/routes/admin/socis/+server.ts per una operació atòmica dins PostgreSQL.
--
-- Taules i columnes actualitzades (el mateix conjunt que tenia el codi JS):
--   socis                      numero_soci  (PK de la fila nova → canvi de valor)
--   players                    numero_soci
--   inscripcions               soci_numero
--   mitjanes_historiques       soci_id
--   calendari_partides         jugador1_soci_numero
--   calendari_partides         jugador2_soci_numero
--   calendari_partides         validat_per
--   calendari_partides         aprovat_canvi_per
--
-- Seguretat:
--   SECURITY DEFINER + comprovació is_admin_by_email() dins la funció.
--   REVOKE EXECUTE de anon i authenticated — només service_role pot executar-la
--   directament. L'endpoint utilitza supabaseAdmin (service_role key), de manera
--   que la REVOKE no afecta el cas d'ús real; la comprovació d'admin queda al
--   requireAdmin() de l'endpoint.

CREATE OR REPLACE FUNCTION public.renumber_soci(
  old_numero integer,
  new_numero integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Defensa en profunditat: si la funció s'invoca amb el token d'un usuari
  -- (no service_role), exigim que sigui admin.
  IF current_setting('role', true) NOT IN ('service_role', 'supabase_admin') THEN
    IF NOT public.is_admin_by_email() THEN
      RAISE EXCEPTION 'No autoritzat: només admins poden renumerar socis' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF old_numero = new_numero THEN
    -- Res a fer; la crida seria per actualitzar dades, no el número.
    RETURN;
  END IF;

  -- Verificar que el soci original existeix
  IF NOT EXISTS (SELECT 1 FROM public.socis WHERE numero_soci = old_numero) THEN
    RAISE EXCEPTION 'El soci original (%) no existeix', old_numero USING ERRCODE = 'P0002';
  END IF;

  -- Verificar que el nou número no estigui ja ocupat
  IF EXISTS (SELECT 1 FROM public.socis WHERE numero_soci = new_numero) THEN
    RAISE EXCEPTION 'Ja existeix un soci amb el número %', new_numero USING ERRCODE = '23505';
  END IF;

  -- Totes les operacions en una mateixa transacció implícita (plpgsql).
  -- Si qualsevol UPDATE/DELETE falla, PostgreSQL farà rollback automàtic.

  -- 1) Inserir la nova fila de soci copiant totes les dades del original
  --    (inclou data_baixa i foto_path, que el codi JS antic perdia)
  INSERT INTO public.socis (
    numero_soci,
    nom,
    cognoms,
    email,
    telefon,
    data_naixement,
    de_baixa,
    data_baixa,
    foto_path
  )
  SELECT
    new_numero,
    nom,
    cognoms,
    email,
    telefon,
    data_naixement,
    de_baixa,
    data_baixa,
    foto_path
  FROM public.socis
  WHERE numero_soci = old_numero;

  -- 2) Propagar FK a totes les taules dependents

  -- players.numero_soci
  UPDATE public.players
  SET numero_soci = new_numero
  WHERE numero_soci = old_numero;

  -- inscripcions.soci_numero
  UPDATE public.inscripcions
  SET soci_numero = new_numero
  WHERE soci_numero = old_numero;

  -- mitjanes_historiques.soci_id
  UPDATE public.mitjanes_historiques
  SET soci_id = new_numero
  WHERE soci_id = old_numero;

  -- calendari_partides: quatre columnes
  UPDATE public.calendari_partides
  SET jugador1_soci_numero = new_numero
  WHERE jugador1_soci_numero = old_numero;

  UPDATE public.calendari_partides
  SET jugador2_soci_numero = new_numero
  WHERE jugador2_soci_numero = old_numero;

  UPDATE public.calendari_partides
  SET validat_per = new_numero
  WHERE validat_per = old_numero;

  UPDATE public.calendari_partides
  SET aprovat_canvi_per = new_numero
  WHERE aprovat_canvi_per = old_numero;

  -- 3) Eliminar la fila original (les FK ja apunten al nou número)
  DELETE FROM public.socis
  WHERE numero_soci = old_numero;

END;
$function$;

-- Revocar execució a anon i authenticated: defense-in-depth.
-- L'endpoint utilitza service_role (supabaseAdmin), que manté accés implícit.
REVOKE EXECUTE ON FUNCTION public.renumber_soci(integer, integer) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.renumber_soci(integer, integer) IS
  'Renumera un soci i propaga totes les FK en una sola transacció atòmica. '
  'Cridat des de /admin/socis PUT (service_role). Audit: 2026-06-10.';
