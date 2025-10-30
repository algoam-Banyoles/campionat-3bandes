-- Actualitzar la funció get_social_league_classifications per utilitzar entrades_jugador1 i entrades_jugador2
-- Això permet gestionar correctament les incompareixences on cada jugador té les seves pròpies entrades

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
  categoria_distancia_caramboles INTEGER,
  estat_jugador TEXT
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
      -- Utilitzar camps específics de jugador, amb fallback a camps antics per compatibilitat
      CASE
        WHEN cp.jugador1_id = p.id THEN COALESCE(cp.entrades_jugador1, cp.entrades, 0)
        WHEN cp.jugador2_id = p.id THEN COALESCE(cp.entrades_jugador2, cp.entrades, 0)
        ELSE NULL
      END as player_entrades,
      CASE
        WHEN cp.jugador1_id = p.id THEN cp.caramboles_jugador1
        WHEN cp.jugador2_id = p.id THEN cp.caramboles_jugador2
        ELSE NULL
      END as player_caramboles,
      -- Utilitzar punts_jugador1/jugador2 directament (més eficient que calcular)
      CASE
        WHEN cp.jugador1_id = p.id THEN COALESCE(cp.punts_jugador1,
          CASE
            WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
            WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
            ELSE 0
          END)
        WHEN cp.jugador2_id = p.id THEN COALESCE(cp.punts_jugador2,
          CASE
            WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
            WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
            ELSE 0
          END)
        ELSE NULL
      END as player_punts,
      CASE
        WHEN cp.jugador1_id = p.id THEN cp.caramboles_jugador2
        WHEN cp.jugador2_id = p.id THEN cp.caramboles_jugador1
        ELSE NULL
      END as opponent_caramboles,
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
      s.cognoms as soci_cognoms,
      CASE
        WHEN i.eliminat_per_incompareixences = true THEN 'retirat'
        ELSE 'actiu'
      END as estat_jugador
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
      COUNT(pm.match_id)::INTEGER as partides_jugades,
      COUNT(CASE WHEN pm.player_punts = 2 THEN 1 END)::INTEGER as partides_guanyades,
      COUNT(CASE WHEN pm.player_punts = 1 THEN 1 END)::INTEGER as partides_empat,
      COUNT(CASE WHEN pm.player_punts = 0 THEN 1 END)::INTEGER as partides_perdudes,
      COALESCE(SUM(pm.player_punts), 0)::INTEGER as punts,
      COALESCE(SUM(pm.player_caramboles), 0)::INTEGER as caramboles_totals,
      COALESCE(SUM(pm.player_entrades), 0)::INTEGER as entrades_totals,
      -- Mitjana general: només si té entrades (si entrades=0, no afecta la mitjana)
      CASE
        WHEN SUM(pm.player_entrades) > 0 THEN
          ROUND((SUM(pm.player_caramboles)::NUMERIC / SUM(pm.player_entrades)::NUMERIC), 3)
        ELSE NULL  -- NULL si no té entrades (no afecta ordenació)
      END as mitjana_general,
      -- Millor mitjana d'una sola partida (només partides amb entrades > 0)
      COALESCE(MAX(
        CASE
          WHEN pm.player_entrades > 0 THEN
            ROUND((pm.player_caramboles::NUMERIC / pm.player_entrades::NUMERIC), 3)
          ELSE NULL
        END
      ), 0) as millor_mitjana
    FROM all_players ap
    LEFT JOIN player_matches pm ON ap.player_id = pm.player_id AND ap.categoria_id = pm.categoria_id
    GROUP BY ap.categoria_id, ap.player_id, ap.soci_numero, ap.soci_nom, ap.soci_cognoms, ap.estat_jugador
  ),
  ranked_players AS (
    SELECT
      ps.*,
      ROW_NUMBER() OVER (
        PARTITION BY ps.categoria_id
        ORDER BY
          ps.punts DESC,
          COALESCE(ps.mitjana_general, 0) DESC,  -- Tracta NULL com 0 per ordenació
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
    COALESCE(rp.mitjana_general, 0) as mitjana_general,  -- Retorna 0 si NULL per compatibilitat
    rp.millor_mitjana,
    rp.partides_jugades,
    rp.partides_guanyades,
    rp.partides_empat,
    rp.partides_perdudes,
    cat.nom as categoria_nom,
    cat.ordre_categoria as categoria_ordre,
    cat.distancia_caramboles as categoria_distancia_caramboles,
    rp.estat_jugador
  FROM ranked_players rp
  LEFT JOIN categories cat ON rp.categoria_id = cat.id
  ORDER BY cat.ordre_categoria ASC, rp.posicio ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO authenticated;

COMMENT ON FUNCTION get_social_league_classifications(UUID) IS
'Returns real-time classifications for social leagues. Utilitza entrades_jugador1/jugador2 per gestionar incompareixences correctament. SECURITY: Uses SET search_path = public.';
