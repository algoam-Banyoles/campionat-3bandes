-- Fix disqualifications by incompareixences and hide annulled matches

-- Ensure old signatures are removed
DROP FUNCTION IF EXISTS registrar_incompareixenca(uuid, smallint);
DROP FUNCTION IF EXISTS registrar_incompareixenca(uuid, uuid, text);

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

-- Update social league classifications to show disqualified players
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

-- Update match results to hide annulled or disqualified players
CREATE OR REPLACE FUNCTION get_match_results_public(p_event_id UUID)
RETURNS TABLE (
  id UUID,
  categoria_id UUID,
  data_programada TIMESTAMPTZ,
  hora_inici TIME,
  jugador1_id UUID,
  jugador2_id UUID,
  estat TEXT,
  taula_assignada INTEGER,
  observacions_junta TEXT,
  jugador1_nom TEXT,
  jugador1_cognoms TEXT,
  jugador1_numero_soci INTEGER,
  jugador2_nom TEXT,
  jugador2_cognoms TEXT,
  jugador2_numero_soci INTEGER,
  categoria_nom TEXT,
  categoria_distancia INTEGER,
  caramboles_reptador SMALLINT,
  caramboles_reptat SMALLINT,
  entrades SMALLINT,
  resultat TEXT,
  match_id UUID,
  incompareixenca_jugador1 BOOLEAN,
  incompareixenca_jugador2 BOOLEAN
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cp.id,
    cp.categoria_id,
    cp.data_programada,
    cp.hora_inici,
    cp.jugador1_id,
    cp.jugador2_id,
    cp.estat,
    cp.taula_assignada,
    cp.observacions_junta,
    s1.nom as jugador1_nom,
    s1.cognoms as jugador1_cognoms,
    p1.numero_soci as jugador1_numero_soci,
    s2.nom as jugador2_nom,
    s2.cognoms as jugador2_cognoms,
    p2.numero_soci as jugador2_numero_soci,
    cat.nom as categoria_nom,
    cat.distancia_caramboles as categoria_distancia,
    cp.caramboles_jugador1 as caramboles_reptador,
    cp.caramboles_jugador2 as caramboles_reptat,
    cp.entrades,
    CASE
      WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 'guanya_reptador'
      WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 'guanya_reptat'
      ELSE 'empat'
    END as resultat,
    cp.match_id,
    COALESCE(cp.incompareixenca_jugador1, false) as incompareixenca_jugador1,
    COALESCE(cp.incompareixenca_jugador2, false) as incompareixenca_jugador2
  FROM calendari_partides cp
  LEFT JOIN players p1 ON cp.jugador1_id = p1.id
  LEFT JOIN socis s1 ON p1.numero_soci = s1.numero_soci
  LEFT JOIN players p2 ON cp.jugador2_id = p2.id
  LEFT JOIN socis s2 ON p2.numero_soci = s2.numero_soci
  LEFT JOIN inscripcions i1 ON i1.event_id = cp.event_id AND i1.soci_numero = p1.numero_soci
  LEFT JOIN inscripcions i2 ON i2.event_id = cp.event_id AND i2.soci_numero = p2.numero_soci
  LEFT JOIN categories cat ON cp.categoria_id = cat.id
  WHERE cp.event_id = p_event_id
    AND cp.estat = 'validat'
    AND cp.caramboles_jugador1 IS NOT NULL
    AND cp.caramboles_jugador2 IS NOT NULL
    AND COALESCE(cp.partida_anullada, false) = false
    AND COALESCE(i1.eliminat_per_incompareixences, false) = false
    AND COALESCE(i2.eliminat_per_incompareixences, false) = false
    AND COALESCE(i1.estat_jugador, 'actiu') <> 'retirat'
    AND COALESCE(i2.estat_jugador, 'actiu') <> 'retirat'
  ORDER BY cp.data_programada DESC, cp.hora_inici DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_match_results_public(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_match_results_public(UUID) TO authenticated;

-- Update calendar matches to hide annulled or disqualified players
CREATE OR REPLACE FUNCTION get_calendar_matches_public(p_event_id UUID)
RETURNS TABLE (
  id UUID,
  categoria_id UUID,
  data_programada DATE,
  hora_inici TIME,
  jugador1_id UUID,
  jugador2_id UUID,
  estat TEXT,
  taula_assignada TEXT,
  observacions_junta TEXT,
  jugador1_numero_soci INTEGER,
  jugador1_nom TEXT,
  jugador1_cognoms TEXT,
  jugador2_numero_soci INTEGER,
  jugador2_nom TEXT,
  jugador2_cognoms TEXT
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    cp.id,
    cp.categoria_id,
    cp.data_programada,
    cp.hora_inici,
    cp.jugador1_id,
    cp.jugador2_id,
    cp.estat,
    cp.taula_assignada,
    cp.observacions_junta,
    p1.numero_soci as jugador1_numero_soci,
    s1.nom as jugador1_nom,
    s1.cognoms as jugador1_cognoms,
    p2.numero_soci as jugador2_numero_soci,
    s2.nom as jugador2_nom,
    s2.cognoms as jugador2_cognoms
  FROM calendari_partides cp
  LEFT JOIN players p1 ON cp.jugador1_id = p1.id
  LEFT JOIN socis s1 ON p1.numero_soci = s1.numero_soci
  LEFT JOIN players p2 ON cp.jugador2_id = p2.id
  LEFT JOIN socis s2 ON p2.numero_soci = s2.numero_soci
  LEFT JOIN inscripcions i1 ON i1.event_id = cp.event_id AND i1.soci_numero = p1.numero_soci
  LEFT JOIN inscripcions i2 ON i2.event_id = cp.event_id AND i2.soci_numero = p2.numero_soci
  WHERE EXISTS (
    SELECT 1 FROM categories cat 
    WHERE cat.id = cp.categoria_id 
    AND cat.event_id = p_event_id
  )
  AND cp.estat IN ('generat', 'validat', 'publicat')
  AND COALESCE(cp.partida_anullada, false) = false
  AND COALESCE(i1.eliminat_per_incompareixences, false) = false
  AND COALESCE(i2.eliminat_per_incompareixences, false) = false
  AND COALESCE(i1.estat_jugador, 'actiu') <> 'retirat'
  AND COALESCE(i2.estat_jugador, 'actiu') <> 'retirat'
  ORDER BY cp.data_programada ASC, cp.hora_inici ASC;
$$;

GRANT EXECUTE ON FUNCTION get_calendar_matches_public(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_calendar_matches_public(UUID) TO authenticated;

-- Ignore annulled matches in public classifications
CREATE OR REPLACE FUNCTION get_classifications_public(event_id_param UUID, category_ids UUID[])
RETURNS TABLE (
  id UUID,
  event_id UUID,
  categoria_id UUID,
  player_id UUID,
  posicio INTEGER,
  partides_jugades INTEGER,
  partides_guanyades INTEGER,
  partides_perdudes INTEGER,
  partides_empat INTEGER,
  caramboles_favor INTEGER,
  caramboles_contra INTEGER,
  mitjana_particular NUMERIC,
  punts INTEGER,
  updated_at TIMESTAMPTZ,
  categoria_nom TEXT,
  categoria_distancia INTEGER,
  categoria_ordre SMALLINT,
  soci_nom TEXT,
  soci_cognoms TEXT,
  soci_numero INTEGER
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_stats AS (
    SELECT 
      i.event_id,
      i.categoria_assignada_id as categoria_id,
      p.id as player_id,
      COUNT(CASE WHEN (cp.jugador1_id = p.id OR cp.jugador2_id = p.id) 
                 AND cp.estat = 'validat' AND cp.match_id IS NOT NULL THEN 1 END)::INTEGER as partides_jugades,
      COUNT(CASE WHEN cp.estat = 'validat' AND cp.match_id IS NOT NULL AND (
                  (cp.jugador1_id = p.id AND m.resultat = 'guanya_reptador') OR
                  (cp.jugador2_id = p.id AND m.resultat = 'guanya_reptat')
                ) THEN 1 END)::INTEGER as partides_guanyades,
      COUNT(CASE WHEN cp.estat = 'validat' AND cp.match_id IS NOT NULL AND (
                  (cp.jugador1_id = p.id AND m.resultat = 'guanya_reptat') OR
                  (cp.jugador2_id = p.id AND m.resultat = 'guanya_reptador')
                ) THEN 1 END)::INTEGER as partides_perdudes,
      COUNT(CASE WHEN cp.estat = 'validat' AND cp.match_id IS NOT NULL AND m.resultat = 'empat' THEN 1 END)::INTEGER as partides_empat,
      COALESCE(SUM(CASE WHEN cp.jugador1_id = p.id THEN m.caramboles_reptador 
                        WHEN cp.jugador2_id = p.id THEN m.caramboles_reptat 
                        ELSE 0 END), 0)::INTEGER as caramboles_favor,
      COALESCE(SUM(CASE WHEN cp.jugador1_id = p.id THEN m.caramboles_reptat 
                        WHEN cp.jugador2_id = p.id THEN m.caramboles_reptador 
                        ELSE 0 END), 0)::INTEGER as caramboles_contra
    FROM inscripcions i
    INNER JOIN players p ON i.soci_numero = p.numero_soci
    LEFT JOIN calendari_partides cp ON (cp.jugador1_id = p.id OR cp.jugador2_id = p.id) 
                                    AND cp.event_id = i.event_id
                                    AND COALESCE(cp.partida_anullada, false) = false
    LEFT JOIN matches m ON cp.match_id = m.id
    WHERE i.event_id = event_id_param 
      AND i.categoria_assignada_id IS NOT NULL
      AND (category_ids IS NULL OR i.categoria_assignada_id = ANY(category_ids))
    GROUP BY i.event_id, i.categoria_assignada_id, p.id
  ),
  ranked_players AS (
    SELECT 
      ps.*,
      (ps.partides_guanyades * 2 + ps.partides_empat)::INTEGER as punts,
      CASE WHEN ps.caramboles_contra > 0 
           THEN ROUND((ps.caramboles_favor::NUMERIC / ps.caramboles_contra::NUMERIC), 3)
           ELSE 0 END as mitjana_particular,
      ROW_NUMBER() OVER (PARTITION BY ps.categoria_id ORDER BY 
        (ps.partides_guanyades * 2 + ps.partides_empat) DESC,
        CASE WHEN ps.caramboles_contra > 0 
             THEN ps.caramboles_favor::NUMERIC / ps.caramboles_contra::NUMERIC
             ELSE 0 END DESC,
        ps.caramboles_favor DESC
      )::INTEGER as posicio
    FROM player_stats ps
  )
  SELECT 
    gen_random_uuid() as id,
    rp.event_id,
    rp.categoria_id,
    rp.player_id,
    rp.posicio,
    rp.partides_jugades,
    rp.partides_guanyades,
    rp.partides_perdudes,
    rp.partides_empat,
    rp.caramboles_favor,
    rp.caramboles_contra,
    rp.mitjana_particular,
    rp.punts,
    NOW() as updated_at,
    cat.nom as categoria_nom,
    cat.distancia_caramboles as categoria_distancia,
    cat.ordre_categoria as categoria_ordre,
    s.nom as soci_nom,
    s.cognoms as soci_cognoms,
    p.numero_soci as soci_numero
  FROM ranked_players rp
  LEFT JOIN categories cat ON rp.categoria_id = cat.id
  LEFT JOIN players p ON rp.player_id = p.id
  LEFT JOIN socis s ON p.numero_soci = s.numero_soci
  ORDER BY cat.ordre_categoria ASC, rp.posicio ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_classifications_public(UUID, UUID[]) TO anon;
GRANT EXECUTE ON FUNCTION get_classifications_public(UUID, UUID[]) TO authenticated;

-- Expose eliminat_per_incompareixences in inscriptions RPC
DROP FUNCTION IF EXISTS get_inscripcions_with_socis(UUID);

CREATE OR REPLACE FUNCTION get_inscripcions_with_socis(p_event_id UUID)
RETURNS TABLE (
  id UUID,
  event_id UUID,
  soci_numero INTEGER,
  categoria_assignada_id UUID,
  data_inscripcio TIMESTAMPTZ,
  preferencies_dies TEXT[],
  preferencies_hores TEXT[],
  restriccions_especials TEXT,
  observacions TEXT,
  pagat BOOLEAN,
  confirmat BOOLEAN,
  created_at TIMESTAMPTZ,
  estat_jugador TEXT,
  data_retirada TIMESTAMPTZ,
  motiu_retirada TEXT,
  eliminat_per_incompareixences BOOLEAN,
  nom TEXT,
  cognoms TEXT,
  email TEXT,
  de_baixa BOOLEAN
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    i.id,
    i.event_id,
    i.soci_numero,
    i.categoria_assignada_id,
    i.data_inscripcio,
    i.preferencies_dies,
    i.preferencies_hores,
    i.restriccions_especials,
    i.observacions,
    i.pagat,
    i.confirmat,
    i.created_at,
    i.estat_jugador,
    i.data_retirada,
    i.motiu_retirada,
    COALESCE(i.eliminat_per_incompareixences, false) as eliminat_per_incompareixences,
    s.nom,
    s.cognoms,
    s.email,
    s.de_baixa
  FROM inscripcions i
  INNER JOIN socis s ON i.soci_numero = s.numero_soci
  WHERE i.event_id = p_event_id
    AND s.de_baixa = false
    AND i.confirmat = true
  ORDER BY s.cognoms ASC, s.nom ASC;
$$;

GRANT EXECUTE ON FUNCTION get_inscripcions_with_socis(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_inscripcions_with_socis(UUID) TO authenticated;

-- Mark existing matches for already disqualified players
UPDATE calendari_partides cp
SET
  partida_anullada = true,
  motiu_anul·lacio = 'Jugador eliminat per 2 incompareixences'
FROM players p
JOIN inscripcions i ON i.soci_numero = p.numero_soci
WHERE (cp.jugador1_id = p.id OR cp.jugador2_id = p.id)
  AND i.event_id = cp.event_id
  AND COALESCE(i.eliminat_per_incompareixences, false) = true
  AND COALESCE(cp.partida_anullada, false) = false;
