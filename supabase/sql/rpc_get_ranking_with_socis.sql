-- Function to get ranking with socis data
-- This replaces the need for complex JOIN queries in the client

CREATE OR REPLACE FUNCTION get_ranking_with_socis(p_event_id UUID)
RETURNS TABLE (
  posicio SMALLINT,
  player_id UUID,
  mitjana NUMERIC(6,3),
  estat player_state,
  data_ultim_repte DATE,
  numero_soci INTEGER,
  nom TEXT,
  cognoms TEXT
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    rp.posicio,
    rp.player_id,
    rp.mitjana,
    rp.estat,
    rp.data_ultim_repte,
    s.numero_soci,
    s.nom,
    s.cognoms
  FROM ranking_positions rp
  INNER JOIN socis s ON rp.player_id = s.id
  WHERE rp.event_id = p_event_id
  ORDER BY rp.posicio ASC;
$$;

-- Grant permissions for anon and authenticated users
GRANT EXECUTE ON FUNCTION get_ranking_with_socis(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_ranking_with_socis(UUID) TO authenticated;