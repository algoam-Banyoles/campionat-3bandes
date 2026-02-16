-- Function to get calendar matches with player data for public access
-- This allows anonymous users to see the calendar for social championships
-- without requiring authentication

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
  -- Jugador 1 info
  jugador1_numero_soci INTEGER,
  jugador1_nom TEXT,
  jugador1_cognoms TEXT,
  -- Jugador 2 info
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
    -- Jugador 1
    p1.numero_soci as jugador1_numero_soci,
    s1.nom as jugador1_nom,
    s1.cognoms as jugador1_cognoms,
    -- Jugador 2
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

-- Grant permissions for anon and authenticated users
GRANT EXECUTE ON FUNCTION get_calendar_matches_public(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_calendar_matches_public(UUID) TO authenticated;

-- Add comment explaining the function
COMMENT ON FUNCTION get_calendar_matches_public(UUID) IS 
'Returns calendar matches with player data for public access. Only shows published matches for social championships.';