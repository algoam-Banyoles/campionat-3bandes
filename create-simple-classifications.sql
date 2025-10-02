-- Funció simplificada que només mostra jugadors inscrits sense estadístiques de partits
-- Versió 4: Funció simple per debug

-- Drop existing function first to handle return type changes
DROP FUNCTION IF EXISTS get_social_league_classifications(UUID);

CREATE OR REPLACE FUNCTION get_social_league_classifications(p_event_id UUID)
RETURNS TABLE (
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
    mitjana_general NUMERIC(5,3),
    millor_mitjana NUMERIC(5,3),
    posicio INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.soci_numero,
        s.nom as soci_nom,
        s.cognoms as soci_cognoms,
        c.id as categoria_id,
        c.nom as categoria_nom,
        c.ordre_categoria as categoria_ordre,
        c.distancia_caramboles::SMALLINT as categoria_distancia_caramboles,
        0::INTEGER as partides_jugades,      -- Inicial, tots tenen 0 partides jugades
        0::INTEGER as punts,                 -- Inicial, tots tenen 0 punts
        0::INTEGER as caramboles_totals,     -- Inicial, tots tenen 0 caramboles
        0::INTEGER as entrades_totals,       -- Inicial, tots tenen 0 entrades
        0.000::NUMERIC(5,3) as mitjana_general,    -- Inicial, 0.000
        0.000::NUMERIC(5,3) as millor_mitjana,     -- Inicial, 0.000
        ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY s.cognoms, s.nom)::INTEGER as posicio
    FROM inscripcions i
    INNER JOIN socis s ON i.soci_numero = s.numero_soci
    INNER JOIN categories c ON i.categoria_assignada_id = c.id
    WHERE i.event_id = p_event_id 
    AND i.confirmat = true
    ORDER BY 
        c.ordre_categoria,
        s.cognoms,
        s.nom;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO authenticated;