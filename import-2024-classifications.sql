-- ================================================================
-- IMPORTACIÓ CLASSIFICACIONS 2024 (temporada 2023-2024)
-- Totes les modalitats i categories
-- ================================================================

-- REUTILITZAR MAPPING I FUNCIONS
CREATE TEMP TABLE player_mapping_2024 AS
SELECT * FROM (VALUES
    ('A. GÓMEZ', 8648), ('J.F. SANTOS', 7602), ('J. F. SANTOS', 7602),
    ('R. CERVANTES', 7938), ('J.M. CAMPOS', 8707), ('L. CHUECOS', 8683),
    ('J. COMAS', 6110), ('A. BOIX', 8077), ('J. RODRÍGUEZ', 8133),
    ('A. MELGAREJO', 8464), ('P. ÁLVAREZ', 8485), ('M. SÁNCHEZ', 7967),
    ('J. VILA', 8690), ('P. CASANOVA', 7618), ('J.L. ROSERÓ', 8664),
    ('A. FUENTES', 8693), ('J. FITÓ', 7196), ('J.A. SAUCEDO', 8296),
    ('J. A. SAUCEDO', 8296), ('R. MERCADER', 8431), ('J. VEZA', 8523),
    ('R. SOTO', 8524), ('E. DÍAZ', 8264), ('R. POLLS', 8181),
    ('J. GIBERNAU', 8387), ('M. GONZALVO', 8682), ('R. JARQUE', 7308),
    ('A. MEDINA', 8556), ('J. GÓMEZ', 8695), ('E. GARCÍA', 8715),
    ('A. MORA', 8438), ('S. MARIN', 1381), ('S. MARÍN', 1381),
    ('M. LÓPEZ', 8482), ('M. MANZANO', 8407), ('E. MILLÁN', 8366),
    ('P. FERRÀS', 7541), ('J. IBÁÑEZ', 8115), ('A. GARCÍA', 8716),
    ('J. CARRASCO', 2749), ('J. VALLÉS', 6512), ('J. VALLES', 6512),
    ('M. QUEROL', 3463), ('J.M. CASAMOR', 8408), ('F. VERDUGO', 8212),
    ('A. BERMEJO', 8542), ('R. MORENO', 8436), ('E. LUENGO', 8732),
    ('E. CURCÓ', 8433), ('J.L. ARROYO', 8396), ('J. SÁNCHEZ', 8728),
    ('E. LEÓN', 3019), ('J. DOMINGO', 8747), ('G. RUIZ', 8741),
    ('J. HERNÁNDEZ', 8186), ('I. HERNÁNDEZ', 8311), ('J. ORTIZ', 6855),
    ('M. PAMPLONA', 7193), ('I. LÓPEZ', 7439), ('P. RUIZ', 23),
    ('M. ÁLVAREZ', 8310), ('A. TRILLO', 8208), ('F. LEDO', 8483),
    ('F. LEDÓ', 8483), ('V. INOCENTES', 5818), ('E. ROYES', 8411),
    ('F. ROYES', 8411), ('J. ROYES', 8582), ('J. MUÑOZ', 8439),
    ('L. GONZÁLEZ', 7026), ('D. CORBALÁN', 8041), ('A. FERNÁNDEZ', 2)
) AS mapping(nom_excel, numero_soci);

CREATE OR REPLACE FUNCTION get_event_2024(modalitat_param text)
RETURNS uuid AS $$
BEGIN
    RETURN (SELECT id FROM events WHERE temporada = '2023-2024' AND modalitat = modalitat_param AND tipus_competicio = 'lliga_social');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_categoria_2024(event_uuid uuid, categoria_nom text)
RETURNS uuid AS $$
BEGIN
    RETURN (SELECT id FROM categories WHERE event_id = event_uuid AND nom = categoria_nom);
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- 3 BANDES 2024
-- ================================================================

-- 3 BANDES 2024 - 1a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('tres_bandes'),
    get_categoria_2024(get_event_2024('tres_bandes'), '1a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 3, data.punts, 3
FROM (VALUES
    (1, 'A. GÓMEZ', 22, 239, 264, 0.905),
    (2, 'E. LEÓN', 20, 218, 296, 0.736),
    (3, 'J.F. SANTOS', 16, 218, 301, 0.724),
    (4, 'A. BOIX', 14, 184, 343, 0.536),
    (5, 'J. RODRÍGUEZ', 14, 191, 366, 0.522),
    (6, 'A. MELGAREJO', 14, 171, 393, 0.435),
    (7, 'J.M. CAMPOS', 13, 208, 334, 0.623),
    (8, 'R. CERVANTES', 12, 183, 356, 0.514),
    (9, 'J. COMAS', 9, 154, 389, 0.396),
    (10, 'R. MORENO', 8, 131, 448, 0.292),
    (11, 'P. CASANOVA', 6, 128, 449, 0.285),
    (12, 'E. DÍAZ', 6, 117, 432, 0.271),
    (13, 'J. HERNÁNDEZ', 2, 107, 461, 0.232)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- 3 BANDES 2024 - 2a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('tres_bandes'),
    get_categoria_2024(get_event_2024('tres_bandes'), '2a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 3, data.punts, 3
FROM (VALUES
    (1, 'P. ÁLVAREZ', 16, 115, 309, 0.372),
    (2, 'R. MERCADER', 13, 101, 343, 0.294),
    (3, 'M. SÁNCHEZ', 12, 109, 329, 0.331),
    (4, 'J. FITÓ', 10, 91, 358, 0.254),
    (5, 'J. VEZA', 9, 87, 343, 0.254),
    (6, 'R. SOTO', 8, 84, 366, 0.230),
    (7, 'E. MILLÁN', 7, 60, 383, 0.157),
    (8, 'J.A. SAUCEDO', 6, 83, 352, 0.236),
    (9, 'J.L. ARROYO', 5, 68, 356, 0.191),
    (10, 'E. CURCÓ', 4, 78, 367, 0.213)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- 3 BANDES 2024 - 3a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('tres_bandes'),
    get_categoria_2024(get_event_2024('tres_bandes'), '3a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 5, data.punts, 5
FROM (VALUES
    (1, 'M. QUEROL', 15, 62, 376, 0.165),
    (2, 'A. MEDINA', 14, 72, 336, 0.214),
    (3, 'R. POLLS', 14, 72, 346, 0.208),
    (4, 'R. JARQUE', 12, 61, 369, 0.165),
    (5, 'J. CARRASCO', 11, 51, 367, 0.139),
    (6, 'M. MANZANO', 8, 51, 383, 0.133),
    (7, 'J.M. CASAMOR', 6, 49, 401, 0.122),
    (8, 'F. VERDUGO', 4, 44, 400, 0.110),
    (9, 'J. ORTIZ', 4, 41, 409, 0.100),
    (10, 'J. VALLÉS', 2, 40, 410, 0.098)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- ================================================================
-- BANDA 2024
-- ================================================================

-- BANDA 2024 - 1a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('banda'),
    get_categoria_2024(get_event_2024('banda'), '1a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 4, data.punts, 4
FROM (VALUES
    (1, 'L. CHUECOS', 24, 582, 513, 1.135),
    (2, 'J.F. SANTOS', 22, 575, 436, 1.319),
    (3, 'E. LEÓN', 14, 557, 493, 1.130),
    (4, 'A. BOIX', 14, 543, 524, 1.036),
    (5, 'I. HERNÁNDEZ', 12, 534, 530, 1.008),
    (6, 'A. GÓMEZ', 12, 489, 524, 0.933),
    (7, 'J. COMAS', 12, 513, 551, 0.931),
    (8, 'R. CERVANTES', 10, 507, 580, 0.874),
    (9, 'R. MORENO', 10, 442, 521, 0.848),
    (10, 'P. ÁLVAREZ', 10, 434, 542, 0.801),
    (11, 'J. RODRÍGUEZ', 6, 406, 525, 0.773),
    (12, 'J.L. ROSERÓ', 6, 404, 545, 0.741),
    (13, 'R. POLLS', 2, 310, 526, 0.589)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- BANDA 2024 - 2a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('banda'),
    get_categoria_2024(get_event_2024('banda'), '2a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 4, data.punts, 4
FROM (VALUES
    (1, 'P. CASANOVA', 20, 420, 517, 0.812),
    (2, 'E. DÍAZ', 18, 334, 465, 0.718),
    (3, 'J. VEZA', 14, 363, 520, 0.698),
    (4, 'J.L. ARROYO', 13, 322, 483, 0.667),
    (5, 'J. FITÓ', 12, 268, 476, 0.563),
    (6, 'M. SÁNCHEZ', 10, 306, 481, 0.636),
    (7, 'E. CURCÓ', 10, 252, 486, 0.519),
    (8, 'M. GONZALVO', 10, 233, 481, 0.484),
    (9, 'J. GIBERNAU', 9, 289, 494, 0.585),
    (10, 'F. LEDO', 8, 267, 498, 0.536),
    (11, 'A. MEDINA', 6, 221, 500, 0.442),
    (12, 'M. MANZANO', 2, 178, 493, 0.361)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- BANDA 2024 - 3a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('banda'),
    get_categoria_2024(get_event_2024('banda'), '3a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 4, data.punts, 4
FROM (VALUES
    (1, 'J. IBÁÑEZ', 17, 232, 496, 0.468),
    (2, 'R. JARQUE', 17, 222, 490, 0.453),
    (3, 'E. MILLÁN', 16, 224, 500, 0.448),
    (4, 'J. CARRASCO', 14, 197, 493, 0.400),
    (5, 'R. SOTO', 10, 201, 497, 0.404),
    (6, 'M. QUEROL', 10, 162, 499, 0.325),
    (7, 'F. VERDUGO', 8, 137, 491, 0.279),
    (8, 'J. VALLÉS', 6, 180, 500, 0.360),
    (9, 'J. ORTIZ', 6, 128, 500, 0.256),
    (10, 'E. ROYES', 4, 161, 500, 0.322),
    (11, 'J.M. CASAMOR', 2, 120, 500, 0.240)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- ================================================================
-- LLIURE 2024
-- ================================================================

-- LLIURE 2024 - 1a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('lliure'),
    get_categoria_2024(get_event_2024('lliure'), '1a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 5, data.punts, 5
FROM (VALUES
    (1, 'A. BERMEJO', 20, 738, 389, 1.897),
    (2, 'J.F. SANTOS', 18, 722, 316, 2.285),
    (3, 'R. CERVANTES', 16, 654, 481, 1.360),
    (4, 'J. COMAS', 12, 647, 451, 1.435),
    (5, 'I. HERNÁNDEZ', 11, 656, 424, 1.547),
    (6, 'R. MORENO', 11, 633, 454, 1.394),
    (7, 'A. BOIX', 10, 568, 450, 1.262),
    (8, 'A. GÓMEZ', 4, 531, 455, 1.167),
    (9, 'E. DÍAZ', 4, 505, 469, 1.077),
    (10, 'P. CASANOVA', 2, 447, 434, 1.030),
    (11, 'M. SÁNCHEZ', 2, 412, 471, 0.875)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- LLIURE 2024 - 2a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('lliure'),
    get_categoria_2024(get_event_2024('lliure'), '2a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 5, data.punts, 5
FROM (VALUES
    (1, 'J. GIBERNAU', 16, 355, 445, 0.798),
    (2, 'J.L. ROSERÓ', 14, 399, 416, 0.959),
    (3, 'E. CURCÓ', 12, 337, 431, 0.782),
    (4, 'J.L. ARROYO', 12, 337, 435, 0.775),
    (5, 'J. FITÓ', 10, 266, 442, 0.602),
    (6, 'J. IBÁÑEZ', 10, 335, 440, 0.761),
    (7, 'R. MERCADER', 10, 312, 450, 0.693),
    (8, 'J.A. SAUCEDO', 4, 215, 441, 0.488),
    (9, 'E. MILLÁN', 4, 281, 448, 0.627),
    (10, 'R. SOTO', 0, 211, 448, 0.471)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- LLIURE 2024 - 3a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_2024('lliure'),
    get_categoria_2024(get_event_2024('lliure'), '3a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 8, data.punts, 8
FROM (VALUES
    (1, 'R. POLLS', 19, 381, 533, 0.715),
    (2, 'A. MEDINA', 12, 130, 300, 0.433),
    (3, 'R. JARQUE', 11, 133, 350, 0.380),
    (4, 'J. VALLÉS', 8, 139, 450, 0.309),
    (5, 'J.M. CASAMOR', 6, 97, 246, 0.394),
    (6, 'J. CARRASCO', 6, 141, 400, 0.353),
    (7, 'A. FERNÁNDEZ', 6, 89, 300, 0.297),
    (8, 'F. VERDUGO', 4, 102, 300, 0.340),
    (9, 'M. QUEROL', 2, 126, 400, 0.315),
    (10, 'E. ROYES', 2, 49, 200, 0.245),
    (11, 'J. ORTIZ', 2, 85, 350, 0.243)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_2024 m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- NETEJA
DROP FUNCTION IF EXISTS get_event_2024(text);
DROP FUNCTION IF EXISTS get_categoria_2024(uuid, text);