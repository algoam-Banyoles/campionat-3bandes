-- RPC function to get classifications for public acc    FROM inscripcions i
    INNER JOIN players p ON i.soci_numero = p.numero_soci
    LEFT JOIN calendari_partides cp ON (cp.jugador1_id = p.id OR cp.jugador2_id = p.id) 
                                    AND cp.event_id = i.event_id
                                    AND COALESCE(cp.partida_anullada, false) = false
    LEFT JOIN matches m ON cp.match_id = m.id
    WHERE i.event_id = event_id_param 
      AND i.categoria_assignada_id IS NOT NULL
      AND (category_ids IS NULL OR i.categoria_assignada_id = ANY(category_ids))
    GROUP BY i.event_id, i.categoria_assignada_id, p.idauthentication required)
-- Generates live classifications based on inscriptions, showing all players even if no matches played
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
    -- Calculate stats from actual matches for each player
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
    LEFT JOIN matches m ON cp.match_id = m.id
    WHERE i.event_id = event_id_param 
      AND i.categoria_assignada_id IS NOT NULL
      AND (category_ids IS NULL OR i.categoria_assignada_id = ANY(category_ids))
    GROUP BY i.event_id, i.categoria_assignada_id, p.id
  ),
  ranked_players AS (
    -- Rank players by points (wins * 2 + draws * 1)
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

-- Grant execute permission to anonymous users
GRANT EXECUTE ON FUNCTION get_classifications_public(UUID, UUID[]) TO anon;
GRANT EXECUTE ON FUNCTION get_classifications_public(UUID, UUID[]) TO authenticated;