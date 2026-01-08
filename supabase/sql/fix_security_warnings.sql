-- ============================================
-- FIX SECURITY WARNINGS - Add search_path to functions
-- ============================================
-- This fixes the "Function Search Path Mutable" warnings
-- by adding SET search_path = public to all affected functions
-- ============================================

-- 1. Fix get_social_league_classifications
DROP FUNCTION IF EXISTS get_social_league_classifications(UUID);

CREATE OR REPLACE FUNCTION get_social_league_classifications(p_event_id UUID)
RETURNS TABLE (
  player_id UUID,
  categoria_id UUID,
  posicio INTEGER,
  soci_numero INTEGER,
  soci_nom TEXT,
  soci_cognoms TEXT,
  punts INTEGER,
  caramboles_totals INTEGER,
  entrades_totals INTEGER,
  mitjana_general NUMERIC,
  millor_mitjana NUMERIC,
  partides_jugades INTEGER,
  partides_guanyades INTEGER,
  partides_empat INTEGER,
  partides_perdudes INTEGER,
  categoria_nom TEXT,
  categoria_ordre SMALLINT,
  categoria_distancia_caramboles INTEGER
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_matches AS (
    SELECT
      i.categoria_assignada_id as categoria_id,
      p.id as player_id,
      p.numero_soci as soci_numero,
      s.nom as soci_nom,
      s.cognoms as soci_cognoms,
      cp.id as match_id,
      cp.jugador1_id,
      cp.jugador2_id,
      cp.caramboles_jugador1,
      cp.caramboles_jugador2,
      cp.entrades,
      CASE
        WHEN cp.jugador1_id = p.id THEN cp.caramboles_jugador1
        WHEN cp.jugador2_id = p.id THEN cp.caramboles_jugador2
        ELSE NULL
      END as player_caramboles,
      CASE
        WHEN cp.jugador1_id = p.id THEN cp.caramboles_jugador2
        WHEN cp.jugador2_id = p.id THEN cp.caramboles_jugador1
        ELSE NULL
      END as opponent_caramboles,
      CASE
        WHEN cp.jugador1_id = p.id AND cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 'win'
        WHEN cp.jugador2_id = p.id AND cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 'win'
        WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 'draw'
        ELSE 'loss'
      END as result,
      CASE
        WHEN cp.jugador1_id = p.id THEN cp.jugador2_id
        WHEN cp.jugador2_id = p.id THEN cp.jugador1_id
        ELSE NULL
      END as opponent_id
    FROM inscripcions i
    INNER JOIN players p ON i.soci_numero = p.numero_soci
    LEFT JOIN socis s ON p.numero_soci = s.numero_soci
    LEFT JOIN calendari_partides cp ON (cp.jugador1_id = p.id OR cp.jugador2_id = p.id)
      AND cp.event_id = i.event_id
      AND cp.estat = 'validat'
      AND cp.caramboles_jugador1 IS NOT NULL
      AND cp.caramboles_jugador2 IS NOT NULL
    WHERE i.event_id = p_event_id
      AND i.categoria_assignada_id IS NOT NULL
  ),
  all_players AS (
    SELECT DISTINCT
      i.categoria_assignada_id as categoria_id,
      p.id as player_id,
      p.numero_soci as soci_numero,
      s.nom as soci_nom,
      s.cognoms as soci_cognoms
    FROM inscripcions i
    INNER JOIN players p ON i.soci_numero = p.numero_soci
    LEFT JOIN socis s ON p.numero_soci = s.numero_soci
    WHERE i.event_id = p_event_id
      AND i.categoria_assignada_id IS NOT NULL
  ),
  player_stats AS (
    SELECT
      ap.categoria_id,
      ap.player_id,
      ap.soci_numero,
      ap.soci_nom,
      ap.soci_cognoms,
      COUNT(pm.match_id)::INTEGER as partides_jugades,
      COUNT(CASE WHEN pm.result = 'win' THEN 1 END)::INTEGER as partides_guanyades,
      COUNT(CASE WHEN pm.result = 'draw' THEN 1 END)::INTEGER as partides_empat,
      COUNT(CASE WHEN pm.result = 'loss' THEN 1 END)::INTEGER as partides_perdudes,
      (COUNT(CASE WHEN pm.result = 'win' THEN 1 END) * 2 +
       COUNT(CASE WHEN pm.result = 'draw' THEN 1 END))::INTEGER as punts,
      COALESCE(SUM(pm.player_caramboles), 0)::INTEGER as caramboles_totals,
      COALESCE(SUM(pm.entrades), 0)::INTEGER as entrades_totals,
      CASE
        WHEN SUM(pm.entrades) > 0 THEN
          ROUND((SUM(pm.player_caramboles)::NUMERIC / SUM(pm.entrades)::NUMERIC), 3)
        ELSE 0
      END as mitjana_general,
      COALESCE(MAX(
        CASE
          WHEN pm.entrades > 0 THEN
            ROUND((pm.player_caramboles::NUMERIC / pm.entrades::NUMERIC), 3)
          ELSE 0
        END
      ), 0) as millor_mitjana
    FROM all_players ap
    LEFT JOIN player_matches pm ON ap.player_id = pm.player_id AND ap.categoria_id = pm.categoria_id
    GROUP BY ap.categoria_id, ap.player_id, ap.soci_numero, ap.soci_nom, ap.soci_cognoms
  ),
  ranked_players AS (
    SELECT
      ps.*,
      ROW_NUMBER() OVER (
        PARTITION BY ps.categoria_id
        ORDER BY
          ps.punts DESC,
          ps.mitjana_general DESC,
          ps.caramboles_totals DESC,
          ps.soci_cognoms ASC,
          ps.soci_nom ASC
      )::INTEGER as posicio
    FROM player_stats ps
  )
  SELECT
    rp.player_id,
    rp.categoria_id,
    rp.posicio,
    rp.soci_numero,
    rp.soci_nom,
    rp.soci_cognoms,
    rp.punts,
    rp.caramboles_totals,
    rp.entrades_totals,
    rp.mitjana_general,
    rp.millor_mitjana,
    rp.partides_jugades,
    rp.partides_guanyades,
    rp.partides_empat,
    rp.partides_perdudes,
    cat.nom as categoria_nom,
    cat.ordre_categoria as categoria_ordre,
    cat.distancia_caramboles as categoria_distancia_caramboles
  FROM ranked_players rp
  LEFT JOIN categories cat ON rp.categoria_id = cat.id
  ORDER BY cat.ordre_categoria ASC, rp.posicio ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO authenticated;

COMMENT ON FUNCTION get_social_league_classifications(UUID) IS
'Returns real-time classifications for social leagues. SECURITY: Uses SET search_path = public to prevent schema injection attacks.';


-- 2. Fix get_head_to_head_results
DROP FUNCTION IF EXISTS get_head_to_head_results(UUID, UUID);

CREATE OR REPLACE FUNCTION get_head_to_head_results(
  p_player1_id UUID,
  p_player2_id UUID
)
RETURNS TABLE (
  match_id UUID,
  event_id UUID,
  event_name TEXT,
  data_joc DATE,
  hora_inici TIME,
  caramboles_player1 INTEGER,
  caramboles_player2 INTEGER,
  entrades INTEGER,
  guanyador_id UUID,
  estat TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cp.id as match_id,
    cp.event_id,
    e.nom as event_name,
    cp.data_programada as data_joc,
    cp.hora_inici,
    CASE
      WHEN cp.jugador1_id = p_player1_id THEN cp.caramboles_jugador1
      ELSE cp.caramboles_jugador2
    END as caramboles_player1,
    CASE
      WHEN cp.jugador1_id = p_player1_id THEN cp.caramboles_jugador2
      ELSE cp.caramboles_jugador1
    END as caramboles_player2,
    cp.entrades,
    CASE
      WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN cp.jugador1_id
      WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN cp.jugador2_id
      ELSE NULL
    END as guanyador_id,
    cp.estat
  FROM calendari_partides cp
  LEFT JOIN events e ON cp.event_id = e.id
  WHERE (
    (cp.jugador1_id = p_player1_id AND cp.jugador2_id = p_player2_id)
    OR
    (cp.jugador1_id = p_player2_id AND cp.jugador2_id = p_player1_id)
  )
  AND cp.estat = 'validat'
  AND cp.caramboles_jugador1 IS NOT NULL
  AND cp.caramboles_jugador2 IS NOT NULL
  ORDER BY cp.data_programada DESC, cp.hora_inici DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_head_to_head_results(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION get_head_to_head_results(UUID, UUID) IS
'Returns head-to-head match results between two players. SECURITY: Uses SET search_path = public.';


-- 3. Fix or create get_retired_players if exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'get_retired_players'
  ) THEN
    EXECUTE 'DROP FUNCTION IF EXISTS get_retired_players(UUID)';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION get_retired_players(p_event_id UUID)
RETURNS TABLE (
  player_id UUID,
  soci_numero INTEGER,
  nom TEXT,
  cognoms TEXT,
  email TEXT,
  retired_at TIMESTAMPTZ,
  categoria_id UUID,
  categoria_nom TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id as player_id,
    p.numero_soci as soci_numero,
    s.nom,
    s.cognoms,
    p.email,
    i.retired_at,
    i.categoria_assignada_id as categoria_id,
    c.nom as categoria_nom
  FROM inscripcions i
  INNER JOIN players p ON i.soci_numero = p.numero_soci
  LEFT JOIN socis s ON p.numero_soci = s.numero_soci
  LEFT JOIN categories c ON i.categoria_assignada_id = c.id
  WHERE i.event_id = p_event_id
    AND i.retired_at IS NOT NULL
  ORDER BY i.retired_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_retired_players(UUID) TO authenticated;

COMMENT ON FUNCTION get_retired_players(UUID) IS
'Returns list of retired players for an event. SECURITY: Uses SET search_path = public.';


-- 4. Fix or create reactivate_player_in_league if exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'reactivate_player_in_league'
  ) THEN
    EXECUTE 'DROP FUNCTION IF EXISTS reactivate_player_in_league(UUID, UUID)';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION reactivate_player_in_league(
  p_event_id UUID,
  p_player_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_soci_numero INTEGER;
  v_rows_updated INTEGER;
BEGIN
  -- Get player's numero_soci
  SELECT numero_soci INTO v_soci_numero
  FROM public.players
  WHERE id = p_player_id;

  IF v_soci_numero IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not found'
    );
  END IF;

  -- Reactivate by setting retired_at to NULL
  UPDATE public.inscripcions
  SET retired_at = NULL
  WHERE event_id = p_event_id
    AND soci_numero = v_soci_numero
    AND retired_at IS NOT NULL;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not found in event or already active'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Player reactivated successfully'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION reactivate_player_in_league(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION reactivate_player_in_league(UUID, UUID) IS
'Reactivates a retired player in a league. SECURITY: Uses empty search_path with fully qualified table names.';


-- 5. Fix or create retire_player_from_league if exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'retire_player_from_league'
  ) THEN
    EXECUTE 'DROP FUNCTION IF EXISTS retire_player_from_league(UUID, UUID)';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION retire_player_from_league(
  p_event_id UUID,
  p_player_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_soci_numero INTEGER;
  v_rows_updated INTEGER;
BEGIN
  -- Get player's numero_soci
  SELECT numero_soci INTO v_soci_numero
  FROM public.players
  WHERE id = p_player_id;

  IF v_soci_numero IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not found'
    );
  END IF;

  -- Retire player by setting retired_at
  UPDATE public.inscripcions
  SET retired_at = NOW()
  WHERE event_id = p_event_id
    AND soci_numero = v_soci_numero
    AND retired_at IS NULL;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not found in event or already retired'
    );
  END IF;

  RETURN jsonb_build_object(
      'success', true,
    'message', 'Player retired successfully'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION retire_player_from_league(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION retire_player_from_league(UUID, UUID) IS
'Retires a player from a league. SECURITY: Uses empty search_path with fully qualified table names.';


-- 6. Fix or create update_page_content_updated_at if exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'update_page_content_updated_at'
  ) THEN
    EXECUTE 'DROP FUNCTION IF EXISTS update_page_content_updated_at() CASCADE';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION update_page_content_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_page_content_updated_at() IS
'Trigger function to update updated_at timestamp. SECURITY: Uses SET search_path = public.';

-- Recreate the trigger if it was dropped
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trigger_update_page_content_updated_at'
    AND tgrelid = 'page_content'::regclass
  ) THEN
    CREATE TRIGGER trigger_update_page_content_updated_at
      BEFORE UPDATE ON page_content
      FOR EACH ROW
      EXECUTE FUNCTION update_page_content_updated_at();
  END IF;
END $$;


-- 7. Fix or create registrar_incompareixenca if exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'registrar_incompareixenca'
  ) THEN
    EXECUTE 'DROP FUNCTION IF EXISTS registrar_incompareixenca(UUID, UUID, TEXT)';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION registrar_incompareixenca(
  p_match_id UUID,
  p_player_absent_id UUID,
  p_observacions TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match RECORD;
  v_winner_id UUID;
  v_caramboles_winner INTEGER;
  v_caramboles_absent INTEGER := 0;
BEGIN
  -- Get match details
  SELECT * INTO v_match
  FROM calendari_partides
  WHERE id = p_match_id;

  IF v_match IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Match not found'
    );
  END IF;

  -- Determine winner (the player who showed up)
  IF v_match.jugador1_id = p_player_absent_id THEN
    v_winner_id := v_match.jugador2_id;
  ELSIF v_match.jugador2_id = p_player_absent_id THEN
    v_winner_id := v_match.jugador1_id;
  ELSE
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not in this match'
    );
  END IF;

  -- Get the category distance for the winner's score
  SELECT c.distancia_caramboles INTO v_caramboles_winner
  FROM categories c
  WHERE c.id = v_match.categoria_id;

  IF v_caramboles_winner IS NULL THEN
    v_caramboles_winner := 25; -- Default value
  END IF;

  -- Update match with walkover result
  UPDATE calendari_partides
  SET
    estat = 'validat',
    caramboles_jugador1 = CASE 
      WHEN jugador1_id = v_winner_id THEN v_caramboles_winner 
      ELSE v_caramboles_absent 
    END,
    caramboles_jugador2 = CASE 
      WHEN jugador2_id = v_winner_id THEN v_caramboles_winner 
      ELSE v_caramboles_absent 
    END,
    entrades = 1,
    observacions_junta = COALESCE(p_observacions, 'Incompareixença registrada automàticament')
  WHERE id = p_match_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Walkover registered successfully',
    'winner_id', v_winner_id,
    'absent_id', p_player_absent_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION registrar_incompareixenca(UUID, UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION registrar_incompareixenca(UUID, UUID, TEXT) IS
'Registers a walkover when a player does not show up. SECURITY: Uses SET search_path = public.';


-- ============================================
-- VERIFICATION
-- ============================================
-- Run this query to verify all functions have search_path set:
-- SELECT 
--   p.proname as function_name,
--   pg_get_function_identity_arguments(p.oid) as arguments,
--   CASE 
--     WHEN pg_get_functiondef(p.oid) LIKE '%SET search_path%' THEN '✅ Protected'
--     ELSE '⚠️ Vulnerable'
--   END as security_status
-- FROM pg_proc p
-- JOIN pg_namespace n ON p.pronamespace = n.oid
-- WHERE n.nspname = 'public'
--   AND p.proname IN (
--     'get_social_league_classifications',
--     'get_head_to_head_results',
--     'get_retired_players',
--     'reactivate_player_in_league',
--     'retire_player_from_league',
--     'update_page_content_updated_at',
--     'registrar_incompareixenca'
--   )
-- ORDER BY p.proname;
