-- Migració 008: Afegir promig mínim per promoció entre categories
-- Per implementar la norma dels dos primers classificats que poden pujar de categoria

BEGIN;

-- Afegir camp promig_minim a la taula categories
ALTER TABLE categories
ADD COLUMN IF NOT EXISTS promig_minim numeric(6,3) DEFAULT NULL;

-- Afegir comentari per documentar la funcionalitat
COMMENT ON COLUMN categories.promig_minim IS 'Promig mínim requerit perquè els dos primers classificats puguin pujar a la categoria superior la temporada següent. NULL significa sense restricció.';

-- Crear funció per calcular promocions automàtiques
CREATE OR REPLACE FUNCTION get_eligible_promotions(event_id_param uuid)
RETURNS TABLE (
    player_id uuid,
    player_name text,
    current_category_id uuid,
    current_category_name text,
    current_position integer,
    current_average numeric,
    target_category_id uuid,
    target_category_name text,
    meets_minimum boolean,
    required_minimum numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.player_id,
        p.nom as player_name,
        c.categoria_id as current_category_id,
        cat.nom as current_category_name,
        c.posicio as current_position,
        c.mitjana_particular as current_average,
        cat_superior.id as target_category_id,
        cat_superior.nom as target_category_name,
        CASE
            WHEN cat.promig_minim IS NULL THEN true
            ELSE c.mitjana_particular >= cat.promig_minim
        END as meets_minimum,
        cat.promig_minim as required_minimum
    FROM classificacions c
    INNER JOIN categories cat ON c.categoria_id = cat.id
    INNER JOIN players p ON c.player_id = p.id
    LEFT JOIN categories cat_superior ON (
        cat_superior.event_id = cat.event_id AND
        cat_superior.ordre_categoria = cat.ordre_categoria - 1
    )
    WHERE
        c.event_id = event_id_param
        AND c.posicio IN (1, 2)  -- Només primer i segon classificat
        AND cat_superior.id IS NOT NULL  -- Només si existeix categoria superior
        AND c.mitjana_particular IS NOT NULL  -- Ha de tenir mitjana calculada
    ORDER BY
        cat.ordre_categoria DESC,
        c.posicio ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear funció per aplicar promocions automàtiques a la següent temporada
CREATE OR REPLACE FUNCTION apply_automatic_promotions(
    source_event_id uuid,
    target_event_id uuid
)
RETURNS TABLE (
    player_id uuid,
    player_name text,
    promoted_to_category text,
    previous_category text
) AS $$
DECLARE
    promotion_record record;
    target_category_id uuid;
BEGIN
    -- Iterar sobre tots els jugadors elegibles per promoció
    FOR promotion_record IN
        SELECT * FROM get_eligible_promotions(source_event_id)
        WHERE meets_minimum = true
    LOOP
        -- Buscar la categoria equivalent a la següent temporada
        SELECT id INTO target_category_id
        FROM categories
        WHERE event_id = target_event_id
        AND ordre_categoria = (
            SELECT ordre_categoria - 1
            FROM categories
            WHERE id = promotion_record.current_category_id
        )
        LIMIT 1;

        -- Si existeix la categoria superior a la nova temporada
        IF target_category_id IS NOT NULL THEN
            -- Actualitzar la inscripció del jugador (si ja existeix) o crear-la
            INSERT INTO inscripcions (event_id, player_id, categoria_assignada_id, data_inscripcio)
            VALUES (target_event_id, promotion_record.player_id, target_category_id, now())
            ON CONFLICT (event_id, player_id)
            DO UPDATE SET categoria_assignada_id = target_category_id;

            -- Retornar el resultat
            RETURN QUERY
            SELECT
                promotion_record.player_id,
                promotion_record.player_name,
                promotion_record.target_category_name,
                promotion_record.current_category_name;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Vista per veure promocions candidates
CREATE OR REPLACE VIEW v_promocions_candidates AS
SELECT
    e.nom as event_name,
    e.id as event_id,
    p.player_id,
    p.player_name,
    p.current_category_name,
    p.current_position,
    p.current_average,
    p.target_category_name,
    p.meets_minimum,
    p.required_minimum,
    CASE
        WHEN p.meets_minimum THEN 'Apte per promoció'
        ELSE concat('Promig insuficient (mínim: ', p.required_minimum, ')')
    END as estat_promocio
FROM events e
CROSS JOIN LATERAL get_eligible_promotions(e.id) p
WHERE e.estat_competicio = 'finalitzat'
ORDER BY e.nom, p.current_category_name, p.current_position;

-- Permisos per les noves funcions
GRANT EXECUTE ON FUNCTION get_eligible_promotions TO authenticated;
GRANT EXECUTE ON FUNCTION apply_automatic_promotions TO authenticated;
GRANT SELECT ON v_promocions_candidates TO authenticated;

COMMIT;