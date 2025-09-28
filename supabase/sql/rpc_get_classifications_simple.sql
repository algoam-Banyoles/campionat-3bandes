-- Simple RPC function to get classifications for public access
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
  SELECT 
    gen_random_uuid() as id,
    i.event_id,
    i.categoria_assignada_id as categoria_id,
    p.id as player_id,
    ROW_NUMBER() OVER (PARTITION BY i.categoria_assignada_id ORDER BY s.nom)::INTEGER as posicio,
    0::INTEGER as partides_jugades,
    0::INTEGER as partides_guanyades,
    0::INTEGER as partides_perdudes,
    0::INTEGER as partides_empat,
    0::INTEGER as caramboles_favor,
    0::INTEGER as caramboles_contra,
    0::NUMERIC as mitjana_particular,
    0::INTEGER as punts,
    NOW() as updated_at,
    cat.nom as categoria_nom,
    cat.distancia_caramboles as categoria_distancia,
    cat.ordre_categoria as categoria_ordre,
    s.nom as soci_nom,
    s.cognoms as soci_cognoms,
    p.numero_soci as soci_numero
  FROM inscripcions i
  INNER JOIN players p ON i.soci_numero = p.numero_soci
  INNER JOIN socis s ON p.numero_soci = s.numero_soci
  LEFT JOIN categories cat ON i.categoria_assignada_id = cat.id
  WHERE i.event_id = event_id_param
    AND i.categoria_assignada_id IS NOT NULL
    AND (category_ids IS NULL OR i.categoria_assignada_id = ANY(category_ids))
  ORDER BY cat.ordre_categoria ASC, s.nom ASC;
END;
$$;

-- Grant execute permission to anonymous users
GRANT EXECUTE ON FUNCTION get_classifications_public(UUID, UUID[]) TO anon;
GRANT EXECUTE ON FUNCTION get_classifications_public(UUID, UUID[]) TO authenticated;