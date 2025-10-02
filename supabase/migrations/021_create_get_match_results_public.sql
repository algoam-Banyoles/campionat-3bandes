-- Migration to create get_match_results_public function
-- Created: 2025-10-02

-- RPC function to get match results for public access (no authentication required)
-- Updated to read results directly from calendari_partides (for social leagues)
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
  match_id UUID
)
SECURITY DEFINER
LANGUAGE plpgsql
SET search_path = ''
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
    -- For social leagues, results are stored directly in calendari_partides
    cp.caramboles_jugador1 as caramboles_reptador,
    cp.caramboles_jugador2 as caramboles_reptat,
    cp.entrades,
    CASE
      WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 'guanya_reptador'
      WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 'guanya_reptat'
      ELSE 'empat'
    END as resultat,
    cp.match_id
  FROM public.calendari_partides cp
  LEFT JOIN public.players p1 ON cp.jugador1_id = p1.id
  LEFT JOIN public.socis s1 ON p1.numero_soci = s1.numero_soci
  LEFT JOIN public.players p2 ON cp.jugador2_id = p2.id
  LEFT JOIN public.socis s2 ON p2.numero_soci = s2.numero_soci
  LEFT JOIN public.categories cat ON cp.categoria_id = cat.id
  WHERE cp.event_id = p_event_id
    AND cp.estat = 'validat'
    AND cp.caramboles_jugador1 IS NOT NULL
    AND cp.caramboles_jugador2 IS NOT NULL
  ORDER BY cp.data_programada DESC, cp.hora_inici DESC;
END;
$$;

-- Grant execute permission to anonymous users
GRANT EXECUTE ON FUNCTION get_match_results_public(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_match_results_public(UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_match_results_public(UUID) IS 'Returns public match results for social leagues from calendari_partides';