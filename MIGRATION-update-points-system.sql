-- ============================================================================
-- MIGRATION: Update Social League Classification Points System
-- ============================================================================
-- Execute this in Supabase SQL Editor
--
-- Changes:
-- - Win = 2 points (was counting as 1)
-- - Draw = 1 point (new)
-- - Loss = 0 points
-- - Added partides_guanyades, partides_empatades, partides_perdudes to output
-- - Updated ORDER BY to sort by points correctly
-- ============================================================================

DROP FUNCTION IF EXISTS get_social_league_classifications(UUID);

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
    partides_guanyades INTEGER,
    partides_empatades INTEGER,
    partides_perdudes INTEGER,
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

            -- Count matches won, drawn, lost
            COALESCE(p1_stats.partides_guanyades, 0) + COALESCE(p2_stats.partides_guanyades, 0) as total_partides_guanyades,
            COALESCE(p1_stats.partides_empatades, 0) + COALESCE(p2_stats.partides_empatades, 0) as total_partides_empatades,
            COALESCE(p1_stats.partides_perdudes, 0) + COALESCE(p2_stats.partides_perdudes, 0) as total_partides_perdudes,

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
                SUM(CASE WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1 ELSE 0 END) as partides_empatades,
                SUM(CASE WHEN cp.caramboles_jugador1 < cp.caramboles_jugador2 THEN 1 ELSE 0 END) as partides_perdudes,
                SUM(cp.caramboles_jugador1) as caramboles_a_favor,
                SUM(cp.caramboles_jugador2) as caramboles_en_contra,
                SUM(cp.entrades) as entrades_jugades
            FROM calendari_partides cp
            WHERE cp.event_id = p_event_id
              AND cp.estat = 'validat'
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
                SUM(CASE WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1 ELSE 0 END) as partides_empatades,
                SUM(CASE WHEN cp.caramboles_jugador2 < cp.caramboles_jugador1 THEN 1 ELSE 0 END) as partides_perdudes,
                SUM(cp.caramboles_jugador2) as caramboles_a_favor,
                SUM(cp.caramboles_jugador1) as caramboles_en_contra,
                SUM(cp.entrades) as entrades_jugades
            FROM calendari_partides cp
            WHERE cp.event_id = p_event_id
              AND cp.estat = 'validat'
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
                -- Order by points (wins*2 + draws*1)
                (ps.total_partides_guanyades * 2 + ps.total_partides_empatades) DESC,
                -- Then by general average
                CASE
                    WHEN ps.total_entrades_jugades > 0
                    THEN ps.total_caramboles_a_favor::NUMERIC / ps.total_entrades_jugades
                    ELSE 0
                END DESC,
                -- Then by total carambles
                ps.total_caramboles_a_favor DESC
        )::INTEGER as posicio,
        ps.total_partides_jugades::INTEGER as partides_jugades,
        ps.total_partides_guanyades::INTEGER as partides_guanyades,
        ps.total_partides_empatades::INTEGER as partides_empatades,
        ps.total_partides_perdudes::INTEGER as partides_perdudes,
        -- Points calculation: wins*2 + draws*1
        (ps.total_partides_guanyades * 2 + ps.total_partides_empatades)::INTEGER as punts,
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

-- Test the function
SELECT
    posicio,
    soci_nom,
    partides_jugades,
    partides_guanyades,
    partides_empatades,
    partides_perdudes,
    punts,
    mitjana_general
FROM get_social_league_classifications('8a81a82e-96c9-4c49-9fbe-b492394462ac')
ORDER BY categoria_ordre, posicio
LIMIT 10;
