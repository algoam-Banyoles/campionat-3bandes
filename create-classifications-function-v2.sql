-- Crear funció que mostra classificacions de lligues socials
-- Versió 3: Funciona amb UUIDs del calendari i mostra tots els jugadors inscrits

CREATE OR REPLACE FUNCTION get_social_league_classifications(event_id_param UUID)
RETURNS TABLE (
    soci_numero INTEGER,
    nom TEXT,
    cognoms TEXT,
    categoria_nom TEXT,
    categoria_ordre SMALLINT,
    categoria_distancia_caramboles SMALLINT,
    partits_jugats INTEGER,
    partits_guanyats INTEGER,
    caramboles_fetes INTEGER,
    caramboles_rebudes INTEGER,
    diferencia_caramboles INTEGER,
    percentatge_victories NUMERIC(5,2),
    mitjana_caramboles NUMERIC(5,2),
    punts_classificacio INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH jugador_stats AS (
        -- Obtenir tots els jugadors inscrits amb les seves estadístiques
        SELECT 
            i.soci_numero,
            s.nom,
            s.cognoms,
            c.nom as categoria_nom,
            c.ordre as categoria_ordre,
            c.distancia_caramboles as categoria_distancia_caramboles,
            -- Comptar partits jugats (comparant UUID del jugador)
            COALESCE((
                SELECT COUNT(*)::INTEGER
                FROM calendari_partides cp
                WHERE cp.event_id = event_id_param 
                AND (cp.jugador1_id::text = s.id::text OR cp.jugador2_id::text = s.id::text)
                AND cp.caramboles_jugador1 IS NOT NULL 
                AND cp.caramboles_jugador2 IS NOT NULL
            ), 0) as partits_jugats,
            
            -- Comptar partits guanyats
            COALESCE((
                SELECT COUNT(*)::INTEGER
                FROM calendari_partides cp
                WHERE cp.event_id = event_id_param 
                AND (
                    (cp.jugador1_id::text = s.id::text AND cp.caramboles_jugador1 > cp.caramboles_jugador2) OR
                    (cp.jugador2_id::text = s.id::text AND cp.caramboles_jugador2 > cp.caramboles_jugador1)
                )
                AND cp.caramboles_jugador1 IS NOT NULL 
                AND cp.caramboles_jugador2 IS NOT NULL
            ), 0) as partits_guanyats,
            
            -- Caramboles fetes per aquest jugador
            COALESCE((
                SELECT SUM(
                    CASE 
                        WHEN cp.jugador1_id::text = s.id::text THEN cp.caramboles_jugador1
                        WHEN cp.jugador2_id::text = s.id::text THEN cp.caramboles_jugador2
                        ELSE 0
                    END
                )::INTEGER
                FROM calendari_partides cp
                WHERE cp.event_id = event_id_param 
                AND (cp.jugador1_id::text = s.id::text OR cp.jugador2_id::text = s.id::text)
                AND cp.caramboles_jugador1 IS NOT NULL 
                AND cp.caramboles_jugador2 IS NOT NULL
            ), 0) as caramboles_fetes,
            
            -- Caramboles rebudes per aquest jugador
            COALESCE((
                SELECT SUM(
                    CASE 
                        WHEN cp.jugador1_id::text = s.id::text THEN cp.caramboles_jugador2
                        WHEN cp.jugador2_id::text = s.id::text THEN cp.caramboles_jugador1
                        ELSE 0
                    END
                )::INTEGER
                FROM calendari_partides cp
                WHERE cp.event_id = event_id_param 
                AND (cp.jugador1_id::text = s.id::text OR cp.jugador2_id::text = s.id::text)
                AND cp.caramboles_jugador1 IS NOT NULL 
                AND cp.caramboles_jugador2 IS NOT NULL
            ), 0) as caramboles_rebudes
            
        FROM inscripcions i
        INNER JOIN socis s ON i.soci_numero = s.numero
        INNER JOIN categories c ON i.categoria_assignada_id = c.id
        WHERE i.event_id = event_id_param 
        AND i.confirmat = true
    )
    SELECT 
        js.soci_numero,
        js.nom,
        js.cognoms,
        js.categoria_nom,
        js.categoria_ordre,
        js.categoria_distancia_caramboles,
        js.partits_jugats,
        js.partits_guanyats,
        js.caramboles_fetes,
        js.caramboles_rebudes,
        (js.caramboles_fetes - js.caramboles_rebudes) as diferencia_caramboles,
        CASE 
            WHEN js.partits_jugats > 0 THEN ROUND((js.partits_guanyats::NUMERIC / js.partits_jugats::NUMERIC) * 100, 2)
            ELSE 0.00
        END as percentatge_victories,
        CASE 
            WHEN js.partits_jugats > 0 THEN ROUND(js.caramboles_fetes::NUMERIC / js.partits_jugats::NUMERIC, 2)
            ELSE 0.00
        END as mitjana_caramboles,
        -- Punts de classificació: 3 punts per victòria + diferència de caramboles
        (js.partits_guanyats * 3 + (js.caramboles_fetes - js.caramboles_rebudes)) as punts_classificacio
    FROM jugador_stats js
    ORDER BY 
        js.categoria_ordre,
        punts_classificacio DESC,
        diferencia_caramboles DESC,
        js.caramboles_fetes DESC;
END;
$$;