-- Fix inconsistent match statuses in social leagues:
-- count matches by recorded result fields instead of relying only on cp.estat = 'validat'

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
      AND cp.caramboles_jugador1 IS NOT NULL
      AND cp.caramboles_jugador2 IS NOT NULL
      AND COALESCE(cp.partida_anullada, false) = false
    LEFT JOIN players cp_j1 ON cp.jugador1_id = cp_j1.id
    LEFT JOIN players cp_j2 ON cp.jugador2_id = cp_j2.id
    LEFT JOIN inscripcions i_cp1 ON i_cp1.event_id = i.event_id AND i_cp1.soci_numero = cp_j1.numero_soci
    LEFT JOIN inscripcions i_cp2 ON i_cp2.event_id = i.event_id AND i_cp2.soci_numero = cp_j2.numero_soci
    WHERE i.event_id = p_event_id
      AND i.categoria_assignada_id IS NOT NULL
      AND COALESCE(i_cp1.eliminat_per_incompareixences, false) = false
      AND COALESCE(i_cp2.eliminat_per_incompareixences, false) = false
      AND COALESCE(i_cp1.estat_jugador, 'actiu') <> 'retirat'
      AND COALESCE(i_cp2.estat_jugador, 'actiu') <> 'retirat'
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

GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon, authenticated;

DROP FUNCTION IF EXISTS get_head_to_head_results(UUID, UUID);

CREATE OR REPLACE FUNCTION get_head_to_head_results(
  p_event_id UUID,
  p_categoria_id UUID
)
RETURNS TABLE (
  jugador1_id UUID,
  jugador1_nom TEXT,
  jugador1_cognoms TEXT,
  jugador1_numero_soci INTEGER,
  jugador2_id UUID,
  jugador2_nom TEXT,
  jugador2_cognoms TEXT,
  jugador2_numero_soci INTEGER,
  caramboles_jugador1 INTEGER,
  caramboles_jugador2 INTEGER,
  entrades_jugador1 INTEGER,
  entrades_jugador2 INTEGER,
  punts_jugador1 INTEGER,
  punts_jugador2 INTEGER,
  mitjana_jugador1 NUMERIC
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cp.jugador1_id,
    s1.nom as jugador1_nom,
    s1.cognoms as jugador1_cognoms,
    p1.numero_soci as jugador1_numero_soci,
    cp.jugador2_id,
    s2.nom as jugador2_nom,
    s2.cognoms as jugador2_cognoms,
    p2.numero_soci as jugador2_numero_soci,
    cp.caramboles_jugador1::INTEGER,
    cp.caramboles_jugador2::INTEGER,
    COALESCE(cp.entrades_jugador1, cp.entrades)::INTEGER as entrades_jugador1,
    COALESCE(cp.entrades_jugador2, cp.entrades)::INTEGER as entrades_jugador2,
    COALESCE(
      cp.punts_jugador1,
      CASE
        WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
        WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
        ELSE 0
      END
    )::INTEGER as punts_jugador1,
    COALESCE(
      cp.punts_jugador2,
      CASE
        WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
        WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1
        ELSE 0
      END
    )::INTEGER as punts_jugador2,
    CASE
      WHEN COALESCE(cp.entrades_jugador1, cp.entrades, 0) > 0
      THEN ROUND((cp.caramboles_jugador1::NUMERIC / COALESCE(cp.entrades_jugador1, cp.entrades)::NUMERIC), 3)
      ELSE 0
    END as mitjana_jugador1
  FROM calendari_partides cp
  LEFT JOIN players p1 ON cp.jugador1_id = p1.id
  LEFT JOIN socis s1 ON p1.numero_soci = s1.numero_soci
  LEFT JOIN players p2 ON cp.jugador2_id = p2.id
  LEFT JOIN socis s2 ON p2.numero_soci = s2.numero_soci
  WHERE cp.event_id = p_event_id
    AND cp.categoria_id = p_categoria_id
    AND cp.caramboles_jugador1 IS NOT NULL
    AND cp.caramboles_jugador2 IS NOT NULL
    AND COALESCE(cp.partida_anullada, false) = false
  ORDER BY s1.cognoms, s1.nom, s2.cognoms, s2.nom;
END;
$$;

GRANT EXECUTE ON FUNCTION get_head_to_head_results(UUID, UUID) TO anon, authenticated;

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
SET search_path = public
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

GRANT EXECUTE ON FUNCTION get_match_results_public(UUID) TO anon, authenticated;
