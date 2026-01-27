-- RPC function to get real-time classifications for social leagues
-- Calculates stats directly from calendari_partides (not from matches table)
-- Victory = 2 points, Draw = 1 point, Loss = 0 points

-- Drop existing function first (needed when changing return type)
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
  -- Withdrawal fields
  estat_jugador TEXT,
  data_retirada TIMESTAMPTZ,
  motiu_retirada TEXT
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_matches AS (
    -- Get all matches for each player with their stats
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
    WHERE i.event_id = p_event_id
      AND i.categoria_assignada_id IS NOT NULL
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
      -- Points: win=2, draw=1, loss=0
      (COUNT(CASE WHEN pm.result = 'win' THEN 1 END) * 2 +
       COUNT(CASE WHEN pm.result = 'draw' THEN 1 END))::INTEGER as punts,
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
  head_to_head AS (
    -- Get head-to-head results between players in same category
    SELECT
      i1.categoria_assignada_id as categoria_id,
      cp.jugador1_id as player1_id,
      cp.jugador2_id as player2_id,
      CASE
        WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 1  -- player1 wins
        WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2  -- player2 wins
        ELSE 0  -- draw
      END as winner
    FROM calendari_partides cp
    INNER JOIN inscripcions i1 ON cp.jugador1_id = (
      SELECT p.id FROM players p WHERE p.numero_soci = i1.soci_numero::INTEGER
    ) AND cp.event_id = i1.event_id
    WHERE cp.event_id = p_event_id
      AND cp.estat = 'validat'
      AND cp.caramboles_jugador1 IS NOT NULL
      AND cp.caramboles_jugador2 IS NOT NULL
  ),
  ranked_players AS (
    -- Rank players by: points DESC, average DESC, caramboles DESC, head-to-head, alphabetical
    SELECT
      ps.*,
      ROW_NUMBER() OVER (
        PARTITION BY ps.categoria_id
        ORDER BY
          ps.punts DESC,
          ps.mitjana_general DESC,
          ps.caramboles_totals DESC,
          -- If tied, use alphabetical order by surname then name
          -- Head-to-head is complex to implement in a window function,
          -- so we use name as tiebreaker for now
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

-- Grant execute permission to anonymous and authenticated users
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO authenticated;
