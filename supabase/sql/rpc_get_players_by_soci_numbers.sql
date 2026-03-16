-- Function to get players by soci numbers for public access
-- This allows anonymous users to resolve soci_numero -> player_id mapping

DROP FUNCTION IF EXISTS get_players_by_soci_numbers(INTEGER[]);

CREATE OR REPLACE FUNCTION get_players_by_soci_numbers(p_soci_numbers INTEGER[])
RETURNS TABLE (
  id UUID,
  numero_soci INTEGER
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.numero_soci
  FROM players p
  WHERE p.numero_soci = ANY(p_soci_numbers);
$$;

GRANT EXECUTE ON FUNCTION get_players_by_soci_numbers(INTEGER[]) TO anon;
GRANT EXECUTE ON FUNCTION get_players_by_soci_numbers(INTEGER[]) TO authenticated;

COMMENT ON FUNCTION get_players_by_soci_numbers(INTEGER[]) IS
'Returns player IDs for given soci numbers. Used for public head-to-head grid access.';
