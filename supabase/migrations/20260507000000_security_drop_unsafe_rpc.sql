-- ============================================================================
-- SECURITY FIX (CRITICAL): elimina RPCs perilloses i tanca la migració de
-- mitjanes contra abús per anon/authenticated.
-- ============================================================================
-- Detectat per security review (2026-05-07).
--
-- 1) `public.update_match_status(UUID, TEXT)`:
--    Tenia `SECURITY DEFINER` + `GRANT EXECUTE TO anon, authenticated`
--    sense cap check d'autorització. Qualsevol usuari (fins i tot anònim)
--    podia canviar l'estat de qualsevol partida de `calendari_partides` a
--    qualsevol string arbitrari, fins i tot trencant l'enum/check constraint.
--    No s'usa enlloc al frontend; eliminada.
--
-- 2) `public.migrate_social_event_to_historiques(UUID)`:
--    Tenia `SECURITY DEFINER` però la migració original no incloïa el REVOKE
--    (per defecte EXECUTE va a PUBLIC). A més, no validava
--    `estat_competicio = 'finalitzat'`. Així, qualsevol caller podia
--    invocar-la amb un event en curs i sobreescriure mitjanes_historiques
--    via `ON CONFLICT ... DO UPDATE`. Reforcem ambdós aspectes.
-- ============================================================================

-- 1) Drop the unsafe update_match_status RPC
DROP FUNCTION IF EXISTS public.update_match_status(UUID, TEXT);

-- 2) Tanquem migrate_social_event_to_historiques
--    a) REVOKE EXECUTE de PUBLIC, anon, authenticated (només service_role
--       i el trigger podran cridar-la directament)
REVOKE EXECUTE ON FUNCTION public.migrate_social_event_to_historiques(UUID)
  FROM PUBLIC, anon, authenticated;

--    b) Reforcem la funció perquè només migri quan l'event és realment
--       finalitzat (defensa en profunditat per si algú la crida via service_role)
CREATE OR REPLACE FUNCTION public.migrate_social_event_to_historiques(p_event_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event RECORD;
  v_year INTEGER;
  v_modalitat TEXT;
  v_inserted INTEGER := 0;
BEGIN
  SELECT id, temporada, modalitat, tipus_competicio, estat_competicio
    INTO v_event
    FROM events
   WHERE id = p_event_id;

  IF NOT FOUND THEN
    RAISE NOTICE 'Event % no trobat; abortant migració', p_event_id;
    RETURN 0;
  END IF;

  IF v_event.tipus_competicio <> 'lliga_social' THEN
    RAISE NOTICE 'Event % no és lliga_social; abortant migració', p_event_id;
    RETURN 0;
  END IF;

  -- SECURITY: només migrem events realment finalitzats. Així, fins i tot si
  -- algú aconsegueix invocar la funció directament, no podrà corrompre
  -- mitjanes amb dades parcials d'un event en curs.
  IF v_event.estat_competicio <> 'finalitzat' THEN
    RAISE NOTICE 'Event % no està finalitzat (estat=%); abortant migració',
      p_event_id, v_event.estat_competicio;
    RETURN 0;
  END IF;

  v_year := NULLIF(SPLIT_PART(REPLACE(v_event.temporada, '/', '-'), '-', 2), '')::INTEGER;
  IF v_year IS NULL THEN
    RAISE NOTICE 'No s''ha pogut extreure year de temporada % (event %)', v_event.temporada, p_event_id;
    RETURN 0;
  END IF;

  v_modalitat := CASE LOWER(COALESCE(v_event.modalitat, ''))
                   WHEN 'tres_bandes' THEN '3 BANDES'
                   WHEN 'lliure'      THEN 'LLIURE'
                   WHEN 'banda'       THEN 'BANDA'
                   ELSE UPPER(v_event.modalitat)
                 END;

  WITH classifs AS (
    SELECT
      soci_numero,
      MAX(mitjana_general) AS mitjana
    FROM public.get_social_league_classifications(p_event_id)
    WHERE soci_numero IS NOT NULL
      AND mitjana_general IS NOT NULL
    GROUP BY soci_numero
  )
  INSERT INTO mitjanes_historiques (soci_id, year, modalitat, mitjana)
  SELECT c.soci_numero, v_year, v_modalitat, c.mitjana
  FROM classifs c
  ON CONFLICT (soci_id, year, modalitat) DO UPDATE
    SET mitjana = EXCLUDED.mitjana
    WHERE mitjanes_historiques.mitjana IS DISTINCT FROM EXCLUDED.mitjana;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted;
END;
$$;

-- Re-aplica el REVOKE després del CREATE OR REPLACE (CREATE redefineix permisos)
REVOKE EXECUTE ON FUNCTION public.migrate_social_event_to_historiques(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.migrate_social_event_to_historiques(UUID)
  TO service_role;
