-- Function to get categories for an event with public access
-- This allows anonymous users to see categories for social championships
-- without requiring authentication

CREATE OR REPLACE FUNCTION get_categories_for_event(p_event_id UUID)
RETURNS TABLE (
  id UUID,
  nom TEXT,
  distancia_caramboles INTEGER,
  ordre_categoria INTEGER,
  max_entrades INTEGER,
  min_jugadors INTEGER,
  max_jugadors INTEGER
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.id,
    c.nom,
    c.distancia_caramboles,
    c.ordre_categoria,
    c.max_entrades,
    c.min_jugadors,
    c.max_jugadors
  FROM categories c
  WHERE c.event_id = p_event_id
  ORDER BY c.ordre_categoria ASC;
$$;

-- Grant permissions for anon and authenticated users
GRANT EXECUTE ON FUNCTION get_categories_for_event(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_categories_for_event(UUID) TO authenticated;

-- Add comment explaining the function
COMMENT ON FUNCTION get_categories_for_event(UUID) IS 
'Returns categories for an event with public access. Used for displaying social championship categories to all users.';