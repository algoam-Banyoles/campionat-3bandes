-- Fix: Actualitzar get_social_league_classifications per usar entrades_jugador1/jugador2
-- 
-- PROBLEMA: Les entrades no es calculaven correctament perquè usava cp.entrades en lloc dels camps individuals
-- SOLUCIÓ: Utilitzar COALESCE(cp.entrades_jugador1, cp.entrades, 0) per cada jugador
--
-- Això corregeix el càlcul de les mitjanes en les classificacions

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
  motiu_retirada TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_matches AS (
    -- Get all matches for each player with their stats
    SELECT
      base.*,
      CASE
        WHEN base.player_points IS NULL OR base.opponent_points IS NULL THEN NULL
        WHEN base.player_points > base.opponent_points THEN 'win'
        WHEN base.player_points = base.opponent_points THEN 'draw'
        ELSE 'loss'
      END as result
    FROM (
      SELECT
        i.categoria_assignada_id as categoria_id,
        p.id as player_id,
        p.numero_soci as soci_numero,
        s.nom as soci_nom,
        s.cognoms as soci_cognoms,
        cp.id as match_id,
        cp.caramboles_jugador1,
        cp.caramboles_jugador2,
        -- Utilitzar entrades_jugador1/jugador2 si estan disponibles, sinó usar entrades compartida
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
        -- Punts: preferir punts_jugador1/2 si existeixen, sinó calcular per caramboles
        CASE
          WHEN cp.id IS NULL THEN NULL
          WHEN cp.jugador1_id = p.id THEN
            CASE
              WHEN cp.punts_jugador1 IS NOT NULL THEN cp.punts_jugador1
              WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
              WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
              ELSE 0
            END
          WHEN cp.jugador2_id = p.id THEN
            CASE
              WHEN cp.punts_jugador2 IS NOT NULL THEN cp.punts_jugador2
              WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
              WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1
              ELSE 0
            END
          ELSE NULL
        END as player_points,
        CASE
          WHEN cp.id IS NULL THEN NULL
          WHEN cp.jugador1_id = p.id THEN
            CASE
              WHEN cp.punts_jugador2 IS NOT NULL THEN cp.punts_jugador2
              WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
              WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1
              ELSE 0
            END
          WHEN cp.jugador2_id = p.id THEN
            CASE
              WHEN cp.punts_jugador1 IS NOT NULL THEN cp.punts_jugador1
              WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
              WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
              ELSE 0
            END
          ELSE NULL
        END as opponent_points
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
    ) base
  ),
  all_players AS (
    -- Get ALL inscribed players, even if they haven't played
    SELECT DISTINCT
      i.categoria_assignada_id as categoria_id,
      p.id as player_id,
      p.numero_soci as soci_numero,
      s.nom as soci_nom,
      s.cognoms as soci_cognoms,
      i.estat_jugador,
      i.data_retirada,
      i.motiu_retirada
    FROM inscripcions i
    INNER JOIN players p ON i.soci_numero = p.numero_soci
    LEFT JOIN socis s ON p.numero_soci = s.numero_soci
    WHERE i.event_id = p_event_id
      AND i.categoria_assignada_id IS NOT NULL
  ),
  player_stats AS (
    -- Calculate stats for each player (join all players with their matches)
    SELECT
      ap.categoria_id,
      ap.player_id,
      ap.soci_numero,
      ap.soci_nom,
      ap.soci_cognoms,
      ap.estat_jugador,
      ap.data_retirada,
      ap.motiu_retirada,
      COUNT(pm.match_id)::INTEGER as partides_jugades,
      COUNT(CASE WHEN pm.result = 'win' THEN 1 END)::INTEGER as partides_guanyades,
      COUNT(CASE WHEN pm.result = 'draw' THEN 1 END)::INTEGER as partides_empat,
      COUNT(CASE WHEN pm.result = 'loss' THEN 1 END)::INTEGER as partides_perdudes,
      -- Points: preferir punts_jugador1/2; sinó derivar del resultat
      COALESCE(SUM(pm.player_points), 0)::INTEGER as punts,
      COALESCE(SUM(pm.player_caramboles), 0)::INTEGER as caramboles_totals,
      COALESCE(SUM(pm.entrades), 0)::INTEGER as entrades_totals,
      -- General average: total caramboles / total entrades
      CASE
        WHEN SUM(pm.entrades) > 0 THEN
          ROUND((SUM(pm.player_caramboles)::NUMERIC / SUM(pm.entrades)::NUMERIC), 3)
        ELSE 0
      END as mitjana_general,
      -- Best average: best single match average
      COALESCE(MAX(
        CASE
          WHEN pm.entrades > 0 THEN
            ROUND((pm.player_caramboles::NUMERIC / pm.entrades::NUMERIC), 3)
          ELSE 0
        END
      ), 0) as millor_mitjana
    FROM all_players ap
    LEFT JOIN player_matches pm ON ap.player_id = pm.player_id AND ap.categoria_id = pm.categoria_id
    GROUP BY ap.categoria_id, ap.player_id, ap.soci_numero, ap.soci_nom, ap.soci_cognoms, ap.estat_jugador, ap.data_retirada, ap.motiu_retirada
  ),
  ranked_players AS (
    -- Rank players within each category
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
    rp.motiu_retirada
  FROM ranked_players rp
  LEFT JOIN categories cat ON rp.categoria_id = cat.id
  ORDER BY cat.ordre_categoria ASC, rp.posicio ASC;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO authenticated;

-- Add comment explaining the function
COMMENT ON FUNCTION get_social_league_classifications(UUID) IS 
'Returns real-time classifications for social leagues. 
Calculates stats directly from calendari_partides.
Uses entrades_jugador1/jugador2 if available, falls back to entrades field for compatibility.
Victory = 2 points, Draw = 1 point, Loss = 0 points.
SECURITY: Uses SET search_path = public.';
