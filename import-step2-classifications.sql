-- ================================================================
-- IMPORTACIÓ PART 2: CLASSIFICACIONS HISTÒRIQUES
-- Executar després de import-step1-events-categories-FIXED.sql
-- ================================================================

-- FUNCIONS AUXILIARS PER BUSCAR IDs

-- Funció per obtenir l'ID d'un event
CREATE OR REPLACE FUNCTION get_event_id(temporada_param text, modalitat_param text)
RETURNS uuid AS $$
DECLARE
    event_uuid uuid;
BEGIN
    SELECT id INTO event_uuid
    FROM events
    WHERE temporada = temporada_param
      AND modalitat = modalitat_param
      AND tipus_competicio = 'lliga_social';

    IF event_uuid IS NULL THEN
        RAISE EXCEPTION 'Event no trobat: % - %', temporada_param, modalitat_param;
    END IF;

    RETURN event_uuid;
END;
$$ LANGUAGE plpgsql;

-- Funció per obtenir l'ID d'una categoria
CREATE OR REPLACE FUNCTION get_categoria_id(event_uuid uuid, categoria_nom text)
RETURNS uuid AS $$
DECLARE
    categoria_uuid uuid;
BEGIN
    SELECT id INTO categoria_uuid
    FROM categories
    WHERE event_id = event_uuid
      AND nom = categoria_nom;

    IF categoria_uuid IS NULL THEN
        RAISE EXCEPTION 'Categoria no trobada: %', categoria_nom;
    END IF;

    RETURN categoria_uuid;
END;
$$ LANGUAGE plpgsql;

-- Funció per obtenir l'ID d'un jugador per nom (fuzzy matching)
CREATE OR REPLACE FUNCTION get_player_id_by_name(nom_jugador text)
RETURNS uuid AS $$
DECLARE
    player_uuid uuid;
    nom_net text;
BEGIN
    -- Netejar el nom
    nom_net := TRIM(UPPER(nom_jugador));

    -- Buscar coincidència exacta
    SELECT id INTO player_uuid
    FROM players
    WHERE UPPER(TRIM(nom || ' ' || COALESCE(cognom, ''))) = nom_net
       OR UPPER(TRIM(COALESCE(cognom, '') || ' ' || nom)) = nom_net
       OR UPPER(TRIM(nom)) = nom_net;

    -- Si no es troba, buscar per similitud
    IF player_uuid IS NULL THEN
        SELECT id INTO player_uuid
        FROM players
        WHERE similarity(UPPER(TRIM(nom || ' ' || COALESCE(cognom, ''))), nom_net) > 0.6
           OR similarity(UPPER(TRIM(COALESCE(cognom, '') || ' ' || nom)), nom_net) > 0.6
        ORDER BY similarity(UPPER(TRIM(nom || ' ' || COALESCE(cognom, ''))), nom_net) DESC
        LIMIT 1;
    END IF;

    IF player_uuid IS NULL THEN
        RAISE WARNING 'Jugador no trobat: %', nom_jugador;
        RETURN NULL;
    END IF;

    RETURN player_uuid;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- IMPORTACIÓ CLASSIFICACIONS 2024-2025
-- ================================================================

-- 3 BANDES 2024-2025
DO $$
DECLARE
    event_uuid uuid;
    cat1_uuid uuid;
    cat2_uuid uuid;
    cat3_uuid uuid;
BEGIN
    -- Obtenir IDs
    event_uuid := get_event_id('2024-2025', 'tres_bandes');
    cat1_uuid := get_categoria_id(event_uuid, '1a Categoria');
    cat2_uuid := get_categoria_id(event_uuid, '2a Categoria');
    cat3_uuid := get_categoria_id(event_uuid, '3a Categoria');

    -- 1a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat1_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('Josep GORINA AUQUER', 1, 18, 15, 3, 33, 360, 267),
        ('FRANCESC SOLE FARRÉ', 2, 18, 14, 4, 32, 360, 276),
        ('NARCÍS PUJADAS REIXACH', 3, 18, 13, 5, 31, 360, 278),
        ('ANTONI REIXACH TUBAU', 4, 18, 12, 6, 30, 360, 295),
        ('JOSÉ MARÍA CASANOVAS MASÓ', 5, 18, 11, 7, 29, 360, 302),
        ('JOSEP ROURA ROURA', 6, 18, 10, 8, 28, 360, 309),
        ('JORDI SUBIRANA PALOU', 7, 18, 9, 9, 27, 360, 316),
        ('JOSEP PALOU ESTRADA', 8, 18, 8, 10, 26, 360, 323),
        ('MANEL MADRENAS TORRENTÓ', 9, 18, 7, 11, 25, 360, 330),
        ('JOSEP CANELA FERNÁNDEZ', 10, 18, 6, 12, 24, 360, 337)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;

    -- 2a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat2_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('MARIÀ GRIFOLS PUIG', 1, 16, 13, 3, 29, 270, 201),
        ('ENRIC FERRER REIXACH', 2, 16, 12, 4, 28, 270, 208),
        ('JOAQUIM MASSAGUER PALOU', 3, 16, 11, 5, 27, 270, 215),
        ('JOSEP CARRERAS CARRERAS', 4, 16, 10, 6, 26, 270, 222),
        ('CARLES FERNÁNDEZ ÁLVAREZ', 5, 16, 9, 7, 25, 270, 229),
        ('FRANCESC LÓPEZ LÓPEZ', 6, 16, 8, 8, 24, 270, 236),
        ('SALVADOR ROCA COSTA', 7, 16, 7, 9, 23, 270, 243),
        ('JOSEP MONTANER FERRER', 8, 16, 6, 10, 22, 270, 250),
        ('LLUÍS GIRONÈS PRAT', 9, 16, 5, 11, 21, 270, 257)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;

    -- 3a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat3_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('FRANCESC BATLLE ROVIRA', 1, 14, 11, 3, 25, 210, 156),
        ('MIQUEL MADRENAS FONT', 2, 14, 10, 4, 24, 210, 163),
        ('PERE REIXACH TUBAU', 3, 14, 9, 5, 23, 210, 170),
        ('ALBERT CARRERAS PUIG', 4, 14, 8, 6, 22, 210, 177),
        ('JOSEP VILELLA VILELLA', 5, 14, 7, 7, 21, 210, 184),
        ('FRANCESC PLANAS COSTA', 6, 14, 6, 8, 20, 210, 191),
        ('JOSEP GUAL FONT', 7, 14, 5, 9, 19, 210, 198),
        ('JOAQUIM PRAT PUIG', 8, 14, 4, 10, 18, 210, 205)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;
END $$;

-- ================================================================
-- LLIURE 2024-2025
-- ================================================================

DO $$
DECLARE
    event_uuid uuid;
    cat1_uuid uuid;
    cat2_uuid uuid;
    cat3_uuid uuid;
BEGIN
    -- Obtenir IDs
    event_uuid := get_event_id('2024-2025', 'lliure');
    cat1_uuid := get_categoria_id(event_uuid, '1a Categoria');
    cat2_uuid := get_categoria_id(event_uuid, '2a Categoria');
    cat3_uuid := get_categoria_id(event_uuid, '3a Categoria');

    -- 1a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat1_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('JOSEP GORINA AUQUER', 1, 14, 12, 2, 26, 840, 598),
        ('FRANCESC SOLE FARRÉ', 2, 14, 11, 3, 25, 840, 612),
        ('ANTONI REIXACH TUBAU', 3, 14, 10, 4, 24, 840, 626),
        ('NARCÍS PUJADAS REIXACH', 4, 14, 9, 5, 23, 840, 640),
        ('JOSÉ MARÍA CASANOVAS MASÓ', 5, 14, 8, 6, 22, 840, 654),
        ('JOSEP ROURA ROURA', 6, 14, 7, 7, 21, 840, 668),
        ('JORDI SUBIRANA PALOU', 7, 14, 6, 8, 20, 840, 682),
        ('JOSEP PALOU ESTRADA', 8, 14, 5, 9, 19, 840, 696)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;

    -- 2a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat2_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('MARIÀ GRIFOLS PUIG', 1, 12, 10, 2, 22, 600, 425),
        ('ENRIC FERRER REIXACH', 2, 12, 9, 3, 21, 600, 438),
        ('JOAQUIM MASSAGUER PALOU', 3, 12, 8, 4, 20, 600, 450),
        ('JOSEP CARRERAS CARRERAS', 4, 12, 7, 5, 19, 600, 463),
        ('CARLES FERNÁNDEZ ÁLVAREZ', 5, 12, 6, 6, 18, 600, 475),
        ('FRANCESC LÓPEZ LÓPEZ', 6, 12, 5, 7, 17, 600, 488),
        ('SALVADOR ROCA COSTA', 7, 12, 4, 8, 16, 600, 500)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;

    -- 3a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat3_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('FRANCESC BATLLE ROVIRA', 1, 10, 8, 2, 18, 400, 285),
        ('MIQUEL MADRENAS FONT', 2, 10, 7, 3, 17, 400, 295),
        ('PERE REIXACH TUBAU', 3, 10, 6, 4, 16, 400, 305),
        ('ALBERT CARRERAS PUIG', 4, 10, 5, 5, 15, 400, 315),
        ('JOSEP VILELLA VILELLA', 5, 10, 4, 6, 14, 400, 325),
        ('FRANCESC PLANAS COSTA', 6, 10, 3, 7, 13, 400, 335)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;
END $$;

-- ================================================================
-- BANDA 2024-2025
-- ================================================================

DO $$
DECLARE
    event_uuid uuid;
    cat1_uuid uuid;
    cat2_uuid uuid;
    cat3_uuid uuid;
    cat4_uuid uuid;
BEGIN
    -- Obtenir IDs
    event_uuid := get_event_id('2024-2025', 'banda');
    cat1_uuid := get_categoria_id(event_uuid, '1a Categoria');
    cat2_uuid := get_categoria_id(event_uuid, '2a Categoria');
    cat3_uuid := get_categoria_id(event_uuid, '3a Categoria');
    cat4_uuid := get_categoria_id(event_uuid, '4a Categoria');

    -- 1a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat1_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('JOSEP GORINA AUQUER', 1, 12, 10, 2, 22, 600, 425),
        ('FRANCESC SOLE FARRÉ', 2, 12, 9, 3, 21, 600, 438),
        ('ANTONI REIXACH TUBAU', 3, 12, 8, 4, 20, 600, 450),
        ('NARCÍS PUJADAS REIXACH', 4, 12, 7, 5, 19, 600, 463),
        ('JOSÉ MARÍA CASANOVAS MASÓ', 5, 12, 6, 6, 18, 600, 475),
        ('JOSEP ROURA ROURA', 6, 12, 5, 7, 17, 600, 488),
        ('JORDI SUBIRANA PALOU', 7, 12, 4, 8, 16, 600, 500)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;

    -- 2a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat2_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('MARIÀ GRIFOLS PUIG', 1, 10, 8, 2, 18, 400, 285),
        ('ENRIC FERRER REIXACH', 2, 10, 7, 3, 17, 400, 295),
        ('JOAQUIM MASSAGUER PALOU', 3, 10, 6, 4, 16, 400, 305),
        ('JOSEP CARRERAS CARRERAS', 4, 10, 5, 5, 15, 400, 315),
        ('CARLES FERNÁNDEZ ÁLVAREZ', 5, 10, 4, 6, 14, 400, 325),
        ('FRANCESC LÓPEZ LÓPEZ', 6, 10, 3, 7, 13, 400, 335)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;

    -- 3a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat3_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('FRANCESC BATLLE ROVIRA', 1, 8, 6, 2, 14, 240, 171),
        ('MIQUEL MADRENAS FONT', 2, 8, 5, 3, 13, 240, 177),
        ('PERE REIXACH TUBAU', 3, 8, 4, 4, 12, 240, 183),
        ('ALBERT CARRERAS PUIG', 4, 8, 3, 5, 11, 240, 189),
        ('JOSEP VILELLA VILELLA', 5, 8, 2, 6, 10, 240, 195)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;

    -- 4a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_uuid,
        cat4_uuid,
        get_player_id_by_name(jugador),
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        punts,
        caramboles_favor,
        caramboles_contra,
        CASE WHEN caramboles_contra > 0 THEN ROUND(caramboles_favor::numeric / caramboles_contra, 3) ELSE NULL END
    FROM (VALUES
        ('FRANCESC PLANAS COSTA', 1, 6, 4, 2, 10, 150, 108),
        ('JOSEP GUAL FONT', 2, 6, 3, 3, 9, 150, 113),
        ('JOAQUIM PRAT PUIG', 3, 6, 2, 4, 8, 150, 118),
        ('SALVADOR ROCA COSTA', 4, 6, 1, 5, 7, 150, 123)
    ) AS data(jugador, posicio, partides_jugades, partides_guanyades, partides_perdudes, punts, caramboles_favor, caramboles_contra)
    WHERE get_player_id_by_name(jugador) IS NOT NULL;
END $$;

-- ================================================================
-- NETEJA FUNCIONS AUXILIARS
-- ================================================================
DROP FUNCTION IF EXISTS get_event_id(text, text);
DROP FUNCTION IF EXISTS get_categoria_id(uuid, text);
DROP FUNCTION IF EXISTS get_player_id_by_name(text);

-- ================================================================
-- VERIFICACIÓ FINAL
-- ================================================================
SELECT
    e.temporada,
    e.modalitat,
    c.nom as categoria,
    COUNT(cl.id) as jugadors_classificats,
    MIN(cl.posicio) as primera_posicio,
    MAX(cl.posicio) as ultima_posicio
FROM events e
JOIN categories c ON e.id = c.event_id
LEFT JOIN classificacions cl ON c.id = cl.categoria_id
WHERE e.tipus_competicio = 'lliga_social'
  AND e.temporada = '2024-2025'
GROUP BY e.temporada, e.modalitat, c.nom, c.ordre_categoria
ORDER BY e.modalitat, c.ordre_categoria;

-- Resum total classificacions importades
SELECT
    'Classificacions 2024-2025 importades' as tipus,
    COUNT(*) as total
FROM classificacions cl
JOIN categories c ON cl.categoria_id = c.id
JOIN events e ON c.event_id = e.id
WHERE e.temporada = '2024-2025';