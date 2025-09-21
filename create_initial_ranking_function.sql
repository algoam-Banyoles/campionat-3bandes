CREATE OR REPLACE FUNCTION create_initial_ranking_from_ordered_socis(
    p_event_id UUID DEFAULT NULL,
    p_socis_ordered INTEGER[] DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_result JSON;
    v_player_id UUID;
    v_soci_num INTEGER;
    v_position INTEGER;
    v_inserted_count INTEGER := 0;
    v_errors TEXT[] := '{}';
BEGIN
    -- Validar que hi ha un event actiu
    IF p_event_id IS NULL THEN
        SELECT id INTO p_event_id FROM events WHERE actiu = true LIMIT 1;
        IF p_event_id IS NULL THEN
            RETURN json_build_object(
                'success', false,
                'error', 'No hi ha cap event actiu',
                'inserted_count', 0
            );
        END IF;
    END IF;

    -- Si no es proporcionen socis, agafar automàticament els 20 millors
    IF p_socis_ordered IS NULL OR array_length(p_socis_ordered, 1) = 0 THEN
        -- Crear array amb els socis ordenats per millor mitjana històrica
        SELECT array_agg(s.numero_soci ORDER BY 
            CASE 
                WHEN mh.mitjana IS NOT NULL THEN mh.mitjana 
                ELSE 0 
            END DESC,
            s.cognoms, s.nom
        ) INTO p_socis_ordered
        FROM socis s
        LEFT JOIN (
            SELECT DISTINCT ON (soci_id) 
                soci_id, mitjana
            FROM mitjanes_historiques 
            WHERE modalitat = '3 BANDES' 
                AND mitjana IS NOT NULL 
                AND mitjana > 0
                AND year >= EXTRACT(YEAR FROM NOW()) - 1
            ORDER BY soci_id, mitjana DESC
        ) mh ON s.numero_soci = mh.soci_id
        INNER JOIN players p ON s.numero_soci = p.numero_soci
        WHERE (s.de_baixa IS FALSE OR s.de_baixa IS NULL)
        LIMIT 20;
    END IF;

    -- Netejar ranking_positions de l'event actual
    DELETE FROM ranking_positions WHERE event_id = p_event_id;

    -- Inserir els socis ordenats al ranking (màxim 20 posicions)
    FOR v_position IN 1..LEAST(array_length(p_socis_ordered, 1), 20) LOOP
        v_soci_num := p_socis_ordered[v_position];
        
        -- Trobar el player_id corresponent al numero_soci
        SELECT p.id INTO v_player_id 
        FROM players p 
        WHERE p.numero_soci = v_soci_num;
        
        IF v_player_id IS NOT NULL THEN
            -- Inserir a ranking_positions
            INSERT INTO ranking_positions (event_id, player_id, posicio, assignat_el)
            VALUES (p_event_id, v_player_id, v_position, NOW());
            
            v_inserted_count := v_inserted_count + 1;
        ELSE
            -- Afegir error si no es troba el player
            v_errors := array_append(v_errors, 'Soci ' || v_soci_num || ' no té registre a players');
        END IF;
    END LOOP;

    -- Construir resposta
    v_result := json_build_object(
        'success', true,
        'inserted_count', v_inserted_count,
        'total_requested', array_length(p_socis_ordered, 1),
        'event_id', p_event_id,
        'errors', v_errors
    );

    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'inserted_count', v_inserted_count
        );
END;
$$;