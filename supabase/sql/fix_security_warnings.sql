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
  estat_jugador TEXT,
  data_retirada TIMESTAMPTZ,
  motiu_retirada TEXT,
  eliminat_per_incompareixences BOOLEAN
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
      cp.caramboles_jugador1,
      cp.caramboles_jugador2,
      CASE
        WHEN cp.jugador1_id = p.id THEN COALESCE(cp.entrades_jugador1, cp.entrades, 0)
        WHEN cp.jugador2_id = p.id THEN COALESCE(cp.entrades_jugador2, cp.entrades, 0)
        ELSE 0
      END as entrades,
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
      END as result
    FROM inscripcions i
    INNER JOIN players p ON i.soci_numero = p.numero_soci
    LEFT JOIN socis s ON p.numero_soci = s.numero_soci
    LEFT JOIN calendari_partides cp ON (cp.jugador1_id = p.id OR cp.jugador2_id = p.id)
      AND cp.event_id = i.event_id
      AND cp.estat = 'validat'
      AND cp.caramboles_jugador1 IS NOT NULL
      AND cp.caramboles_jugador2 IS NOT NULL
      AND COALESCE(cp.partida_anullada, false) = false
    WHERE i.event_id = p_event_id
      AND i.categoria_assignada_id IS NOT NULL
  ),
  all_players AS (
    SELECT DISTINCT
      i.categoria_assignada_id as categoria_id,
      p.id as player_id,
      p.numero_soci as soci_numero,
      s.nom as soci_nom,
      s.cognoms as soci_cognoms,
      CASE
        WHEN COALESCE(i.eliminat_per_incompareixences, false) = true THEN 'retirat'
        WHEN i.estat_jugador = 'retirat' THEN 'retirat'
        ELSE 'actiu'
      END as estat_jugador,
      COALESCE(i.data_retirada, i.data_eliminacio) as data_retirada,
      CASE
        WHEN COALESCE(i.eliminat_per_incompareixences, false) = true THEN 'Desqualificat per 2 incompareixences'
        ELSE i.motiu_retirada
      END as motiu_retirada,
      COALESCE(i.eliminat_per_incompareixences, false) as eliminat_per_incompareixences
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
      ap.estat_jugador,
      ap.data_retirada,
      ap.motiu_retirada,
      ap.eliminat_per_incompareixences,
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
    GROUP BY ap.categoria_id, ap.player_id, ap.soci_numero, ap.soci_nom, ap.soci_cognoms, ap.estat_jugador, ap.data_retirada, ap.motiu_retirada, ap.eliminat_per_incompareixences
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
    rp.estat_jugador,
    rp.data_retirada,
    rp.motiu_retirada,
    rp.eliminat_per_incompareixences
  FROM ranked_players rp
  LEFT JOIN categories cat ON rp.categoria_id = cat.id
  ORDER BY cat.ordre_categoria ASC, rp.posicio ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO authenticated;

COMMENT ON FUNCTION get_social_league_classifications(UUID) IS
'Returns real-time classifications for social leagues with disqualifications handled. SECURITY: Uses SET search_path = public.';


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
  p_partida_id uuid,
  p_jugador_que_falta smallint  -- 1 o 2
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partida RECORD;
  v_jugador_id uuid;
  v_altre_jugador_id uuid;
  v_soci_numero integer;
  v_event_id uuid;
  v_categoria_id uuid;
  v_max_entrades integer;
  v_incompareixences_count smallint;
  v_result json;
BEGIN
  -- Obtenir informació de la partida
  SELECT * INTO v_partida
  FROM calendari_partides
  WHERE id = p_partida_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partida no trobada';
  END IF;

  -- Determinar quin jugador falta i quin ha vingut
  IF p_jugador_que_falta = 1 THEN
    v_jugador_id := v_partida.jugador1_id;
    v_altre_jugador_id := v_partida.jugador2_id;
  ELSIF p_jugador_que_falta = 2 THEN
    v_jugador_id := v_partida.jugador2_id;
    v_altre_jugador_id := v_partida.jugador1_id;
  ELSE
    RAISE EXCEPTION 'Jugador invàlid: ha de ser 1 o 2';
  END IF;

  v_event_id := v_partida.event_id;
  v_categoria_id := v_partida.categoria_id;

  -- Obtenir el numero_soci del jugador que falta
  SELECT numero_soci INTO v_soci_numero
  FROM players
  WHERE id = v_jugador_id;

  IF v_soci_numero IS NULL THEN
    RAISE EXCEPTION 'No s''ha trobat el numero de soci del jugador';
  END IF;

  -- Obtenir el max_entrades de la categoria
  SELECT max_entrades INTO v_max_entrades
  FROM categories
  WHERE id = v_categoria_id;

  IF v_max_entrades IS NULL THEN
    v_max_entrades := 50; -- Valor per defecte si no es troba
  END IF;

  -- Actualitzar la partida amb el resultat d'incompareixença
  -- Jugador PRESENT: 2 punts, 0 caramboles, 0 entrades
  -- Jugador ABSENT: 0 punts, 0 caramboles, max_entrades
  IF p_jugador_que_falta = 1 THEN
    UPDATE calendari_partides
    SET
      incompareixenca_jugador1 = true,
      data_incompareixenca = NOW(),
      estat = 'validat',
      caramboles_jugador1 = 0,
      caramboles_jugador2 = 0,
      entrades_jugador1 = v_max_entrades,
      entrades_jugador2 = 0,
      entrades = v_max_entrades,
      punts_jugador1 = 0,
      punts_jugador2 = 2,
      data_joc = NOW(),
      validat_per = NULL,
      data_validacio = NOW(),
      observacions_junta = COALESCE(observacions_junta || E'\n', '') ||
        '[' || TO_CHAR(NOW(), 'DD/MM/YYYY') || '] Incompareixença jugador 1. Jugador 2: 2 punts, 0 caramboles, 0 entrades. Jugador 1: 0 punts, 0 caramboles, ' || v_max_entrades || ' entrades penalització.'
    WHERE id = p_partida_id;
  ELSE
    UPDATE calendari_partides
    SET
      incompareixenca_jugador2 = true,
      data_incompareixenca = NOW(),
      estat = 'validat',
      caramboles_jugador1 = 0,
      caramboles_jugador2 = 0,
      entrades_jugador1 = 0,
      entrades_jugador2 = v_max_entrades,
      entrades = v_max_entrades,
      punts_jugador1 = 2,
      punts_jugador2 = 0,
      data_joc = NOW(),
      validat_per = NULL,
      data_validacio = NOW(),
      observacions_junta = COALESCE(observacions_junta || E'\n', '') ||
        '[' || TO_CHAR(NOW(), 'DD/MM/YYYY') || '] Incompareixença jugador 2. Jugador 1: 2 punts, 0 caramboles, 0 entrades. Jugador 2: 0 punts, 0 caramboles, ' || v_max_entrades || ' entrades penalització.'
    WHERE id = p_partida_id;
  END IF;

  -- Actualitzar comptador d'incompareixences del jugador
  UPDATE inscripcions
  SET incompareixences_count = incompareixences_count + 1
  WHERE soci_numero = v_soci_numero
    AND event_id = v_event_id
  RETURNING incompareixences_count INTO v_incompareixences_count;

  -- Si té 2 incompareixences, eliminar el jugador i anul·lar les seves partides
  IF v_incompareixences_count >= 2 THEN
    UPDATE inscripcions
    SET
      eliminat_per_incompareixences = true,
      data_eliminacio = NOW(),
      estat_jugador = 'retirat',
      data_retirada = NOW(),
      motiu_retirada = 'Desqualificat per 2 incompareixences'
    WHERE soci_numero = v_soci_numero
      AND event_id = v_event_id;

    UPDATE calendari_partides
    SET
      partida_anullada = true,
      motiu_anul·lacio = 'Jugador eliminat per 2 incompareixences'
    WHERE event_id = v_event_id
      AND (jugador1_id = v_jugador_id OR jugador2_id = v_jugador_id)
      AND COALESCE(partida_anullada, false) = false;

    v_result := json_build_object(
      'incompareixences', v_incompareixences_count,
      'jugador_eliminat', true,
      'partides_anullades', true,
      'max_entrades_utilitzat', v_max_entrades
    );
  ELSE
    v_result := json_build_object(
      'incompareixences', v_incompareixences_count,
      'jugador_eliminat', false,
      'partides_anullades', false,
      'max_entrades_utilitzat', v_max_entrades
    );
  END IF;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION registrar_incompareixenca(uuid, smallint) TO authenticated;

COMMENT ON FUNCTION registrar_incompareixenca(uuid, smallint) IS
'Registra una incompareixença segons les regles correctes i desqualifica amb 2 incompareixences. SECURITY: Uses SET search_path = public.';


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
