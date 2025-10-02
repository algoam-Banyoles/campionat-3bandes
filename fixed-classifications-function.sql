-- Fixed function with correct player relationships
-- Drop existing function first
DROP FUNCTION IF EXISTS get_social_league_classifications(UUID);

-- Create new function with correct player relationship through players table
CREATE OR REPLACE FUNCTION get_social_league_classifications(p_event_id UUID)
RETURNS TABLE (
    soci_numero TEXT,
    soci_nom TEXT,
    soci_cognoms TEXT,
    categoria_id UUID,
    categoria_nom TEXT,
    categoria_ordre SMALLINT,
    categoria_distancia INTEGER,
    posicio INTEGER,
    partides_jugades INTEGER,
    punts INTEGER,
    caramboles_totals INTEGER,
    entrades_totals INTEGER,
    mitjana_general NUMERIC,
    millor_mitjana NUMERIC
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH player_stats AS (
        SELECT 
            i.soci_numero,
            i.categoria_assignada_id as categoria_id,
            p.id as player_id,
            
            -- Count matches played (as player 1 or player 2)
            COALESCE(p1_stats.partides_jugades, 0) + COALESCE(p2_stats.partides_jugades, 0) as total_partides_jugades,
            
            -- Count matches won
            COALESCE(p1_stats.partides_guanyades, 0) + COALESCE(p2_stats.partides_guanyades, 0) as total_partides_guanyades,
            
            -- Sum caramboles made and received
            COALESCE(p1_stats.caramboles_a_favor, 0) + COALESCE(p2_stats.caramboles_a_favor, 0) as total_caramboles_a_favor,
            COALESCE(p1_stats.caramboles_en_contra, 0) + COALESCE(p2_stats.caramboles_en_contra, 0) as total_caramboles_en_contra,
            
            -- Sum entries
            COALESCE(p1_stats.entrades_jugades, 0) + COALESCE(p2_stats.entrades_jugades, 0) as total_entrades_jugades
            
        FROM inscripcions i
        JOIN players p ON i.soci_numero = p.numero_soci
        
        -- Stats when playing as player 1
        LEFT JOIN (
            SELECT 
                cp.jugador1_id,
                COUNT(*) as partides_jugades,
                SUM(CASE WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 1 ELSE 0 END) as partides_guanyades,
                SUM(cp.caramboles_jugador1) as caramboles_a_favor,
                SUM(cp.caramboles_jugador2) as caramboles_en_contra,
                SUM(cp.entrades) as entrades_jugades
            FROM calendari_partides cp
            WHERE cp.event_id = p_event_id 
              AND cp.caramboles_jugador1 IS NOT NULL 
              AND cp.caramboles_jugador2 IS NOT NULL
            GROUP BY cp.jugador1_id
        ) p1_stats ON p.id = p1_stats.jugador1_id
        
        -- Stats when playing as player 2
        LEFT JOIN (
            SELECT 
                cp.jugador2_id,
                COUNT(*) as partides_jugades,
                SUM(CASE WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 1 ELSE 0 END) as partides_guanyades,
                SUM(cp.caramboles_jugador2) as caramboles_a_favor,
                SUM(cp.caramboles_jugador1) as caramboles_en_contra,
                SUM(cp.entrades) as entrades_jugades
            FROM calendari_partides cp
            WHERE cp.event_id = p_event_id 
              AND cp.caramboles_jugador1 IS NOT NULL 
              AND cp.caramboles_jugador2 IS NOT NULL
            GROUP BY cp.jugador2_id
        ) p2_stats ON p.id = p2_stats.jugador2_id
        
        WHERE i.event_id = p_event_id
          AND i.confirmat = true
    )
    SELECT 
        ps.soci_numero::TEXT as soci_numero,
        s.nom as soci_nom,
        s.cognoms as soci_cognoms,
        ps.categoria_id,
        c.nom as categoria_nom,
        c.ordre_categoria as categoria_ordre,
        c.distancia_caramboles::INTEGER as categoria_distancia,
        ROW_NUMBER() OVER (
            PARTITION BY ps.categoria_id 
            ORDER BY 
                ps.total_partides_guanyades DESC,
                CASE 
                    WHEN ps.total_entrades_jugades > 0 
                    THEN ps.total_caramboles_a_favor::NUMERIC / ps.total_entrades_jugades 
                    ELSE 0 
                END DESC,
                ps.total_caramboles_a_favor DESC
        )::INTEGER as posicio,
        ps.total_partides_jugades::INTEGER as partides_jugades,
        ps.total_partides_guanyades::INTEGER as punts,
        ps.total_caramboles_a_favor::INTEGER as caramboles_totals,
        ps.total_entrades_jugades::INTEGER as entrades_totals,
        CASE 
            WHEN ps.total_entrades_jugades > 0 
            THEN ROUND(ps.total_caramboles_a_favor::NUMERIC / ps.total_entrades_jugades, 3)
            ELSE 0.000
        END as mitjana_general,
        CASE 
            WHEN ps.total_entrades_jugades > 0 
            THEN ROUND(ps.total_caramboles_a_favor::NUMERIC / ps.total_entrades_jugades, 3)
            ELSE 0.000
        END as millor_mitjana
    FROM player_stats ps
    JOIN socis s ON ps.soci_numero = s.numero_soci
    JOIN categories c ON ps.categoria_id = c.id
    ORDER BY c.ordre_categoria, posicio;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO authenticated;