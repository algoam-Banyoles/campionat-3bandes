-- ============================================================================
-- Auto-migració de mitjanes de campionats socials a `mitjanes_historiques`
-- ============================================================================
-- Quan un campionat social (events.tipus_competicio='lliga_social') passa
-- a estat 'finalitzat', cal volcar les mitjanes finals dels seus jugadors a
-- la taula `mitjanes_historiques` per a referència futura (comparativa entre
-- temporades, mostres en perfils de jugador, etc.).
--
-- Aquesta migració:
--   1) Defineix una funció `public.migrate_social_event_to_historiques(event_id)`
--      que, donat un event social finalitzat, omple les seves mitjanes a
--      `mitjanes_historiques` amb la convenció:
--          - year = end-year de la temporada (ex: '2024-2025' → 2025)
--          - modalitat (uppercase) = mapa des de events.modalitat (lowercase)
--                tres_bandes → '3 BANDES'
--                lliure       → 'LLIURE'
--                banda        → 'BANDA'
--          - soci_id = numero_soci
--          - mitjana = mitjana_general computada per la RPC
--                       `get_social_league_classifications`.
--
--   2) Defineix un trigger AFTER UPDATE OF estat_competicio sobre `events`
--      que invoca aquesta funció quan l'event passa a 'finalitzat'.
--
--   3) Backfill: per a tots els events lliga_social ja finalitzats que NO
--      tenen entrades a mitjanes_historiques per (year, modalitat, soci_id)
--      executa la migració. És idempotent (ON CONFLICT DO NOTHING).
-- ============================================================================

-- 1) Funció de migració
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

  -- Convertir temporada a year (end-year)
  -- Suporta formats "2024-2025" i "2024/2025"
  v_year := NULLIF(SPLIT_PART(REPLACE(v_event.temporada, '/', '-'), '-', 2), '')::INTEGER;

  IF v_year IS NULL THEN
    RAISE NOTICE 'No s''ha pogut extreure year de temporada % (event %)', v_event.temporada, p_event_id;
    RETURN 0;
  END IF;

  -- Mapatge modalitat (events.modalitat lowercase → mitjanes_historiques.modalitat uppercase)
  v_modalitat := CASE LOWER(COALESCE(v_event.modalitat, ''))
                   WHEN 'tres_bandes' THEN '3 BANDES'
                   WHEN 'lliure'      THEN 'LLIURE'
                   WHEN 'banda'       THEN 'BANDA'
                   ELSE UPPER(v_event.modalitat)
                 END;

  -- Insereix mitjana per a cada jugador classificat (una entrada per soci_numero)
  -- Si un soci té múltiples categories en el mateix event (cas excepcional), agafem la mitjana_general
  -- més alta de les seves entrades.
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
  SELECT
    c.soci_numero,
    v_year,
    v_modalitat,
    c.mitjana
  FROM classifs c
  ON CONFLICT (soci_id, year, modalitat) DO UPDATE
    SET mitjana = EXCLUDED.mitjana
    WHERE mitjanes_historiques.mitjana IS DISTINCT FROM EXCLUDED.mitjana;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RAISE NOTICE 'migrate_social_event_to_historiques: event=%, year=%, modalitat=%, files migrades=%',
    p_event_id, v_year, v_modalitat, v_inserted;

  RETURN v_inserted;
END;
$$;

COMMENT ON FUNCTION public.migrate_social_event_to_historiques(UUID) IS
  'Migra les mitjanes d''un event lliga_social finalitzat a la taula mitjanes_historiques. Idempotent.';

-- 2) Garantia d'unicitat per ON CONFLICT
-- (Si encara no existeix; idempotent.)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'mitjanes_historiques'
      AND indexname = 'mitjanes_historiques_soci_year_modalitat_key'
  ) THEN
    BEGIN
      ALTER TABLE mitjanes_historiques
        ADD CONSTRAINT mitjanes_historiques_soci_year_modalitat_key
        UNIQUE (soci_id, year, modalitat);
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN
      -- Ja existeix com a constraint; ok
      NULL;
    END;
  END IF;
END $$;

-- 3) Trigger sobre events: quan estat_competicio passa a 'finalitzat' i és lliga_social,
--    invoca la migració.
CREATE OR REPLACE FUNCTION public.trg_event_finalitzat_migrate_mitjanes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.tipus_competicio = 'lliga_social'
     AND NEW.estat_competicio = 'finalitzat'
     AND (TG_OP = 'INSERT' OR OLD.estat_competicio IS DISTINCT FROM 'finalitzat')
  THEN
    PERFORM public.migrate_social_event_to_historiques(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS event_finalitzat_migrate_mitjanes ON events;

CREATE TRIGGER event_finalitzat_migrate_mitjanes
AFTER INSERT OR UPDATE OF estat_competicio ON events
FOR EACH ROW
EXECUTE FUNCTION public.trg_event_finalitzat_migrate_mitjanes();

COMMENT ON TRIGGER event_finalitzat_migrate_mitjanes ON events IS
  'Quan un event lliga_social passa a finalitzat, vol·ca les mitjanes a mitjanes_historiques.';

-- 4) Backfill: per a events lliga_social ja finalitzats sense mitjanes a la taula històrica.
DO $$
DECLARE
  ev RECORD;
  inserted_count INTEGER;
BEGIN
  FOR ev IN
    SELECT id, temporada, modalitat
    FROM events
    WHERE tipus_competicio = 'lliga_social'
      AND estat_competicio = 'finalitzat'
    ORDER BY temporada
  LOOP
    SELECT public.migrate_social_event_to_historiques(ev.id) INTO inserted_count;
    RAISE NOTICE 'Backfill event % (temporada %, modalitat %): % files migrades',
      ev.id, ev.temporada, ev.modalitat, inserted_count;
  END LOOP;
END $$;
