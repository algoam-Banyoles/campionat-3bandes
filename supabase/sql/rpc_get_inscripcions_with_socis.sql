-- Function to get inscripcions with socis data for public access
-- This allows anonymous users to see players registered in social championships
-- without requiring authentication

-- Drop existing function first to allow changing return type
DROP FUNCTION IF EXISTS get_inscripcions_with_socis(UUID);

CREATE OR REPLACE FUNCTION get_inscripcions_with_socis(p_event_id UUID)
RETURNS TABLE (
  id UUID,
  event_id UUID,
  soci_numero INTEGER,
  categoria_assignada_id UUID,
  data_inscripcio TIMESTAMPTZ,
  preferencies_dies TEXT[],
  preferencies_hores TEXT[],
  restriccions_especials TEXT,
  observacions TEXT,
  pagat BOOLEAN,
  confirmat BOOLEAN,
  created_at TIMESTAMPTZ,
  -- Withdrawal fields
  estat_jugador TEXT,
  data_retirada TIMESTAMPTZ,
  motiu_retirada TEXT,
  eliminat_per_incompareixences BOOLEAN,
  -- Socis information
  nom TEXT,
  cognoms TEXT,
  email TEXT,
  de_baixa BOOLEAN
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    i.id,
    i.event_id,
    i.soci_numero,
    i.categoria_assignada_id,
    i.data_inscripcio,
    i.preferencies_dies,
    i.preferencies_hores,
    i.restriccions_especials,
    i.observacions,
    i.pagat,
    i.confirmat,
    i.created_at,
    i.estat_jugador,
    i.data_retirada,
    i.motiu_retirada,
    COALESCE(i.eliminat_per_incompareixences, false) as eliminat_per_incompareixences,
    s.nom,
    s.cognoms,
    s.email,
    s.de_baixa
  FROM inscripcions i
  INNER JOIN socis s ON i.soci_numero = s.numero_soci
  WHERE i.event_id = p_event_id
    AND s.de_baixa = false
    AND i.confirmat = true
  ORDER BY s.cognoms ASC, s.nom ASC;
$$;

-- Grant permissions for anon and authenticated users
GRANT EXECUTE ON FUNCTION get_inscripcions_with_socis(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_inscripcions_with_socis(UUID) TO authenticated;

-- Add comment explaining the function
COMMENT ON FUNCTION get_inscripcions_with_socis(UUID) IS 
'Returns inscriptions with member data for public access in social championships. Filters only confirmed registrations from active members.';