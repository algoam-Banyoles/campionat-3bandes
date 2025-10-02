-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_social_league_classifications(UUID);

-- Create function to get social league classifications
CREATE OR REPLACE FUNCTION get_social_league_classifications(p_event_id UUID)
RETURNS TABLE(
  player_id UUID,
  soci_numero INTEGER,
  soci_nom TEXT,
  soci_cognoms TEXT,
  categoria_id UUID,
  categoria_nom TEXT,
  categoria_ordre SMALLINT,
  categoria_distancia_caramboles SMALLINT,
  partides_jugades INTEGER,
  punts INTEGER,
  caramboles_totals INTEGER,
  entrades_totals INTEGER,
  mitjana_general NUMERIC,
  millor_mitjana NUMERIC,
  posicio INTEGER
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH player_stats AS (
    -- Calculate statistics for each player from calendari_partides
    SELECT 
      i.id as player_id,
      i.soci_numero,
      s.nom as soci_nom,
      s.cognoms as soci_cognoms,
      i.categoria_assignada_id as categoria_id,
      c.nom as categoria_nom,
      c.ordre_categoria::SMALLINT as categoria_ordre,
      c.distancia_caramboles::SMALLINT as categoria_distancia_caramboles,
      
      -- Count total matches played
      COUNT(
        CASE WHEN (cp.jugador1_id = i.id OR cp.jugador2_id = i.id) 
             AND cp.estat = 'validat' 
             AND cp.caramboles_jugador1 IS NOT NULL 
             AND cp.caramboles_jugador2 IS NOT NULL 
        THEN 1 END
      )::INTEGER as partides_jugades,
      
      -- Calculate total points (3 for win, 1 for tie, 0 for loss)
      COALESCE(SUM(
        CASE 
          WHEN cp.jugador1_id = i.id AND cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 3
          WHEN cp.jugador2_id = i.id AND cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 3
          WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 AND cp.caramboles_jugador1 IS NOT NULL THEN 1
          ELSE 0
        END
      ), 0)::INTEGER as punts,
      
      -- Calculate total caramboles made by the player
      COALESCE(SUM(
        CASE 
          WHEN cp.jugador1_id = i.id AND cp.caramboles_jugador1 IS NOT NULL THEN cp.caramboles_jugador1
          WHEN cp.jugador2_id = i.id AND cp.caramboles_jugador2 IS NOT NULL THEN cp.caramboles_jugador2
          ELSE 0
        END
      ), 0)::INTEGER as caramboles_totals,
      
      -- Calculate total entrades by the player
      COALESCE(SUM(
        CASE 
          WHEN cp.jugador1_id = i.id AND cp.entrades IS NOT NULL THEN cp.entrades
          WHEN cp.jugador2_id = i.id AND cp.entrades IS NOT NULL THEN cp.entrades
          ELSE 0
        END
      ), 0)::INTEGER as entrades_totals,
      
      -- Calculate general average (caramboles / entrades)
      CASE 
        WHEN COALESCE(SUM(
          CASE 
            WHEN cp.jugador1_id = i.id AND cp.entrades IS NOT NULL THEN cp.entrades
            WHEN cp.jugador2_id = i.id AND cp.entrades IS NOT NULL THEN cp.entrades
            ELSE 0
          END
        ), 0) > 0 
        THEN 
          COALESCE(SUM(
            CASE 
              WHEN cp.jugador1_id = i.id AND cp.caramboles_jugador1 IS NOT NULL THEN cp.caramboles_jugador1
              WHEN cp.jugador2_id = i.id AND cp.caramboles_jugador2 IS NOT NULL THEN cp.caramboles_jugador2
              ELSE 0
            END
          ), 0)::NUMERIC / 
          COALESCE(SUM(
            CASE 
              WHEN cp.jugador1_id = i.id AND cp.entrades IS NOT NULL THEN cp.entrades
              WHEN cp.jugador2_id = i.id AND cp.entrades IS NOT NULL THEN cp.entrades
              ELSE 0
            END
          ), 1)::NUMERIC
        ELSE 0.000
      END as mitjana_general,
      
      -- Calculate best average from individual matches
      COALESCE(MAX(
        CASE 
          WHEN cp.jugador1_id = i.id AND cp.entrades IS NOT NULL AND cp.entrades > 0 AND cp.caramboles_jugador1 IS NOT NULL
          THEN cp.caramboles_jugador1::NUMERIC / cp.entrades::NUMERIC
          WHEN cp.jugador2_id = i.id AND cp.entrades IS NOT NULL AND cp.entrades > 0 AND cp.caramboles_jugador2 IS NOT NULL
          THEN cp.caramboles_jugador2::NUMERIC / cp.entrades::NUMERIC
          ELSE NULL
        END
      ), 0.000) as millor_mitjana
      
    FROM public.inscripcions i
    INNER JOIN public.socis s ON i.soci_numero = s.numero_soci
    INNER JOIN public.categories c ON i.categoria_assignada_id = c.id
    LEFT JOIN public.calendari_partides cp ON 
      cp.event_id = i.event_id 
      AND (cp.jugador1_id = i.id OR cp.jugador2_id = i.id)
      AND cp.estat = 'validat'
    WHERE i.event_id = p_event_id
      AND i.confirmat = true
    GROUP BY 
      i.id, i.soci_numero, s.nom, s.cognoms, 
      i.categoria_assignada_id, c.nom, c.ordre_categoria, c.distancia_caramboles
  ),
  ranked_players AS (
    -- Add position ranking within each category
    SELECT 
      ps.*,
      ROW_NUMBER() OVER (
        PARTITION BY ps.categoria_id 
        ORDER BY 
          ps.punts DESC,
          ps.mitjana_general DESC,
          ps.caramboles_totals DESC,
          ps.soci_numero ASC
      ) as posicio
    FROM player_stats ps
  )
  SELECT 
    rp.player_id,
    rp.soci_numero,
    rp.soci_nom,
    rp.soci_cognoms,
    rp.categoria_id,
    rp.categoria_nom,
    rp.categoria_ordre,
    rp.categoria_distancia_caramboles,
    rp.partides_jugades,
    rp.punts,
    rp.caramboles_totals,
    rp.entrades_totals,
    rp.mitjana_general,
    COALESCE(rp.millor_mitjana, 0.000) as millor_mitjana,
    rp.posicio::INTEGER
  FROM ranked_players rp
  ORDER BY 
    rp.categoria_ordre ASC,
    rp.posicio ASC;
END;
$$;

-- Grant execute permission to authenticated and anonymous users
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon;