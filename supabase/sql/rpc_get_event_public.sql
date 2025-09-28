-- RPC function to get basic event data for public access
CREATE OR REPLACE FUNCTION get_event_public(p_event_id UUID)
RETURNS TABLE (
  id UUID,
  nom TEXT,
  temporada TEXT,
  modalitat TEXT,
  tipus_competicio TEXT,
  estat_competicio TEXT,
  data_inici TIMESTAMPTZ,
  data_fi TIMESTAMPTZ,
  actiu BOOLEAN
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id,
    e.nom,
    e.temporada,
    e.modalitat,
    e.tipus_competicio,
    e.estat_competicio,
    e.data_inici,
    e.data_fi,
    e.actiu
  FROM events e
  WHERE e.id = p_event_id
    AND e.tipus_competicio = 'lliga_social';
END;
$$;

-- Grant execute permission to anonymous users
GRANT EXECUTE ON FUNCTION get_event_public(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_event_public(UUID) TO authenticated;