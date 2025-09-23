-- ================================================================
-- IMPORTACIÓ CLASSIFICACIONS REALS 2025
-- Mapping entre jugadors Excel i socis reals
-- ================================================================

-- MAPPING IDENTIFICAT:
-- Excel -> Soci real
-- 'A. GÓMEZ' -> Albert Gómez Ametller (8648)
-- 'J.F. SANTOS' -> Juan Felix Santos Gonzalez (7602)
-- 'R. CERVANTES' -> Rafael Cervantes Solsona (7938)
-- 'J.M. CAMPOS' -> José María Campos Gonzalez (8707)
-- 'L. CHUECOS' -> Luís Chuecos Enríquez (8683)
-- 'J. COMAS' -> Jaume Comas Ferrer (6110)
-- 'A. BOIX' -> Agustí Boix González (8077)
-- 'J. RODRÍGUEZ' -> Juan Rodríguez López (8133)
-- 'A. MELGAREJO' -> Antonio Melgarejo Nicolás (8464)
-- 'P. ÁLVAREZ' -> Pedro Álvarez Valencia (8485)
-- 'M. SÁNCHEZ' -> Manuel Sánchez Molera (7967)
-- 'J. VILA' -> Josep Vila Clopés (8690)
-- 'P. CASANOVA' -> Pere Casanova Fregine (7618)

-- Crear taula de mapping definitiva
CREATE TEMP TABLE jugador_final_mapping AS
SELECT * FROM (VALUES
    -- 3 BANDES 2025 - Classificació basada en els Excel
    ('A. GÓMEZ', 8648),           -- Albert Gómez Ametller
    ('J.F. SANTOS', 7602),        -- Juan Felix Santos Gonzalez
    ('R. CERVANTES', 7938),       -- Rafael Cervantes Solsona
    ('J.M. CAMPOS', 8707),        -- José María Campos Gonzalez
    ('L. CHUECOS', 8683),         -- Luís Chuecos Enríquez
    ('J. COMAS', 6110),           -- Jaume Comas Ferrer
    ('A. BOIX', 8077),            -- Agustí Boix González
    ('J. RODRÍGUEZ', 8133),       -- Juan Rodríguez López
    ('A. MELGAREJO', 8464),       -- Antonio Melgarejo Nicolás
    ('P. ÁLVAREZ', 8485),         -- Pedro Álvarez Valencia
    ('M. SÁNCHEZ', 7967),         -- Manuel Sánchez Molera
    ('J. VILA', 8690),            -- Josep Vila Clopés
    ('P. CASANOVA', 7618)         -- Pere Casanova Fregine

    -- TODO: Afegir més jugadors quan tinguem més dades Excel

) AS mapping(nom_excel, numero_soci);

-- Verificar el mapping amb els socis reals
SELECT
    m.nom_excel,
    m.numero_soci,
    p.nom as nom_real,
    p.email,
    p.estat
FROM jugador_final_mapping m
LEFT JOIN players p ON p.numero_soci = m.numero_soci
ORDER BY m.numero_soci;

-- ================================================================
-- IMPORTACIÓ CLASSIFICACIONS 3 BANDES 2025 - 1a CATEGORIA
-- ================================================================

DO $$
DECLARE
    event_2025_3b UUID;
    cat_1a_3b UUID;
BEGIN
    -- Obtenir ID de l'event 3 Bandes 2024-2025
    SELECT id INTO event_2025_3b
    FROM events
    WHERE temporada = '2024-2025'
      AND modalitat = 'tres_bandes'
      AND tipus_competicio = 'lliga_social';

    IF event_2025_3b IS NULL THEN
        RAISE EXCEPTION 'Event 3 Bandes 2024-2025 no trobat';
    END IF;

    -- Obtenir ID de la 1a categoria
    SELECT id INTO cat_1a_3b
    FROM categories
    WHERE event_id = event_2025_3b
      AND nom = '1a Categoria';

    IF cat_1a_3b IS NULL THEN
        RAISE EXCEPTION '1a Categoria no trobada per event 3 Bandes 2024-2025';
    END IF;

    -- Inserir classificacions 1a categoria (dades reals d'Excel)
    INSERT INTO classificacions (
        event_id,
        categoria_id,
        player_id,
        posicio,
        punts,
        caramboles_favor,
        caramboles_contra,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        mitjana_particular
    )
    SELECT
        event_2025_3b,
        cat_1a_3b,
        p.id,
        data.posicio,
        data.punts,
        data.caramboles_favor,
        data.caramboles_contra,
        data.partides_jugades,
        data.partides_guanyades,
        data.partides_perdudes,
        data.mitjana_particular
    FROM (VALUES
        -- Posició, Nom Excel, Punts, Caramboles Favor, Caramboles Contra, PJ, PG, PP, Mitjana
        (1, 'A. GÓMEZ', 22, 236, 239, 11, 11, 0, 0.987),
        (2, 'J.F. SANTOS', 18, 218, 262, 10, 9, 1, 0.832),
        (3, 'R. CERVANTES', 18, 213, 333, 10, 9, 1, 0.640),
        (4, 'J.M. CAMPOS', 17, 217, 289, 10, 8, 2, 0.751),
        (5, 'L. CHUECOS', 16, 199, 313, 9, 8, 1, 0.636),
        (6, 'J. COMAS', 13, 177, 405, 8, 6, 2, 0.437),
        (7, 'A. BOIX', 10, 184, 371, 7, 5, 2, 0.496),
        (8, 'J. RODRÍGUEZ', 9, 144, 421, 6, 4, 2, 0.342),
        (9, 'A. MELGAREJO', 8, 156, 364, 6, 4, 2, 0.429),
        (10, 'P. ÁLVAREZ', 7, 151, 386, 5, 3, 2, 0.391),
        (11, 'M. SÁNCHEZ', 7, 154, 423, 5, 3, 2, 0.364),
        (12, 'J. VILA', 6, 140, 346, 4, 3, 1, 0.405),
        (13, 'P. CASANOVA', 5, 136, 373, 4, 2, 2, 0.365)
    ) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra,
              partides_jugades, partides_guanyades, partides_perdudes, mitjana_particular)
    JOIN jugador_final_mapping m ON m.nom_excel = data.nom_excel
    JOIN players p ON p.numero_soci = m.numero_soci;

    -- Mostrar resum de la importació
    RAISE NOTICE 'Importades % classificacions per 3 Bandes 2025 - 1a Categoria',
        (SELECT COUNT(*) FROM classificacions WHERE categoria_id = cat_1a_3b);

END $$;

-- ================================================================
-- TODO: AFEGIR MÉS CATEGORIES I MODALITATS
-- ================================================================

/*
Quan tinguem més dades Excel, podem afegir:

- 3 BANDES 2025 - 2a Categoria
- 3 BANDES 2025 - 3a Categoria
- LLIURE 2025 - 1a, 2a, 3a Categories
- BANDA 2025 - 1a, 2a, 3a, 4a Categories

Mateix format:
DO $$
DECLARE
    event_uuid UUID;
    categoria_uuid UUID;
BEGIN
    -- Obtenir IDs
    SELECT id INTO event_uuid FROM events WHERE temporada = '2024-2025' AND modalitat = 'lliure';
    SELECT id INTO categoria_uuid FROM categories WHERE event_id = event_uuid AND nom = '1a Categoria';

    -- Inserir classificacions
    INSERT INTO classificacions (...) SELECT ... FROM (VALUES ...) AS data ...
END $$;
*/

-- ================================================================
-- VERIFICACIÓ FINAL
-- ================================================================

SELECT
    e.nom as event,
    c.nom as categoria,
    cl.posicio,
    p.nom as jugador,
    p.numero_soci,
    cl.punts,
    cl.caramboles_favor,
    cl.caramboles_contra,
    cl.mitjana_particular
FROM classificacions cl
JOIN categories c ON cl.categoria_id = c.id
JOIN events e ON c.event_id = e.id
JOIN players p ON cl.player_id = p.id
WHERE e.temporada = '2024-2025'
ORDER BY e.modalitat, c.ordre_categoria, cl.posicio;