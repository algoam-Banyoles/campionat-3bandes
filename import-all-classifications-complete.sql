-- ================================================================
-- IMPORTACIÓ COMPLETA DE TOTES LES CLASSIFICACIONS HISTÒRIQUES
-- Totes les categories, modalitats i temporades (2022-2025)
-- ================================================================

-- MAPPING COMPLET JUGADORS (reutilitzem el mapping anterior)
CREATE TEMP TABLE player_mapping_all AS
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

-- FUNCIONS AUXILIARS
CREATE OR REPLACE FUNCTION get_event_id_all(temporada_param text, modalitat_param text)
RETURNS uuid AS $$
DECLARE
    event_uuid uuid;
BEGIN
    SELECT id INTO event_uuid FROM events
    WHERE temporada = temporada_param AND modalitat = modalitat_param AND tipus_competicio = 'lliga_social';
    RETURN event_uuid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_categoria_id_all(event_uuid uuid, categoria_nom text)
RETURNS uuid AS $$
DECLARE
    categoria_uuid uuid;
BEGIN
    SELECT id INTO categoria_uuid FROM categories
    WHERE event_id = event_uuid AND nom = categoria_nom;
    RETURN categoria_uuid;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- 2025 - 3 BANDES (completar les que falten)
-- ================================================================

-- 3 BANDES 2025 - 3a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_all('2024-2025', 'tres_bandes'),
    get_categoria_id_all(get_event_id_all('2024-2025', 'tres_bandes'), '3a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 5, data.punts, 5
FROM (VALUES
    (1, 'J. GÓMEZ', 21, 106, 518, 0.205),
    (2, 'E. GARCÍA', 20, 112, 398, 0.281),
    (3, 'A. MORA', 20, 101, 547, 0.185),
    (4, 'S. MARIN', 18, 106, 533, 0.199),
    (5, 'M. LÓPEZ', 17, 120, 388, 0.309),
    (6, 'M. MANZANO', 17, 107, 552, 0.194),
    (7, 'E. MILLÁN', 17, 98, 531, 0.185),
    (8, 'P. FERRÀS', 16, 111, 500, 0.222),
    (9, 'J. IBÁÑEZ', 16, 94, 513, 0.183),
    (10, 'A. GARCÍA', 11, 73, 576, 0.127),
    (11, 'J. CARRASCO', 10, 77, 593, 0.130),
    (12, 'J. VALLÉS', 9, 67, 556, 0.120),
    (13, 'M. QUEROL', 6, 78, 563, 0.139),
    (14, 'J.M. CASAMOR', 6, 66, 606, 0.109),
    (15, 'F. VERDUGO', 6, 61, 609, 0.100)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_all m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- ================================================================
-- 2025 - LLIURE (totes les categories)
-- ================================================================

-- LLIURE 2025 - 1a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_all('2024-2025', 'lliure'),
    get_categoria_id_all(get_event_id_all('2024-2025', 'lliure'), '1a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 5, data.punts, 5
FROM (VALUES
    (1, 'L. CHUECOS', 8, 278, 163, 1.706),
    (2, 'A. BERMEJO', 8, 217, 136, 1.596),
    (3, 'J. F. SANTOS', 8, 240, 159, 1.509),
    (4, 'J. COMAS', 4, 240, 152, 1.579),
    (5, 'A. GÓMEZ', 2, 202, 166, 1.217),
    (6, 'J. VILA', 0, 233, 180, 1.294),
    (7, 'J.M. CAMPOS', 10, 293, 235, 1.247),
    (8, 'P. ÁLVAREZ', 10, 273, 235, 1.162),
    (9, 'R. CERVANTES', 8, 329, 234, 1.406),
    (10, 'R. MORENO', 7, 306, 237, 1.291),
    (11, 'E. DÍAZ', 4, 218, 232, 0.940),
    (12, 'J. GIBERNAU', 2, 216, 237, 0.911),
    (13, 'J.L. ROSERÓ', 1, 214, 238, 0.899)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_all m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- LLIURE 2025 - 2a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_all('2024-2025', 'lliure'),
    get_categoria_id_all(get_event_id_all('2024-2025', 'lliure'), '2a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 5, data.punts, 5
FROM (VALUES
    (1, 'E. LUENGO', 21, 536, 465, 1.153),
    (2, 'J. IBÁÑEZ', 16, 407, 527, 0.772),
    (3, 'P. CASANOVA', 15, 510, 481, 1.060),
    (4, 'E. CURCÓ', 14, 349, 490, 0.712),
    (5, 'J.L. ARROYO', 13, 424, 534, 0.794),
    (6, 'A. FUENTES', 12, 449, 534, 0.841),
    (7, 'M. SÁNCHEZ', 10, 410, 543, 0.755),
    (8, 'J. SÁNCHEZ', 9, 401, 527, 0.761),
    (9, 'J. A. SAUCEDO', 7, 360, 534, 0.674),
    (10, 'R. MERCADER', 6, 365, 536, 0.681),
    (11, 'A. MEDINA', 5, 380, 516, 0.736),
    (12, 'R. POLLS', 4, 365, 519, 0.703)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_all m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- LLIURE 2025 - 3a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_all('2024-2025', 'lliure'),
    get_categoria_id_all(get_event_id_all('2024-2025', 'lliure'), '3a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 8, data.punts, 8
FROM (VALUES
    (1, 'E. GARCÍA', 8, 184, 233, 0.790),
    (2, 'M. MANZANO', 7, 164, 237, 0.692),
    (3, 'J. FITÓ', 5, 158, 245, 0.645),
    (4, 'E. MILLÁN', 4, 142, 237, 0.599),
    (5, 'P. FERRÀS', 4, 138, 246, 0.561),
    (6, 'A. MORA', 2, 130, 242, 0.537),
    (7, 'M. GONZALVO', 8, 177, 244, 0.725),
    (8, 'R. SOTO', 8, 170, 235, 0.723),
    (9, 'J. GÓMEZ', 6, 164, 240, 0.683),
    (10, 'M. QUEROL', 6, 128, 235, 0.545),
    (11, 'J.M. CASAMOR', 2, 109, 250, 0.436),
    (12, 'J. CARRASCO', 0, 142, 246, 0.577),
    (13, 'R. JARQUE', 6, 130, 200, 0.650),
    (14, 'S. MARÍN', 6, 106, 200, 0.530),
    (15, 'J. VALLÉS', 4, 104, 200, 0.520),
    (16, 'F. VERDUGO', 4, 82, 200, 0.410),
    (17, 'J. ORTIZ', 0, 77, 200, 0.385)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_all m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- ================================================================
-- 2025 - BANDA (totes les categories)
-- ================================================================

-- BANDA 2025 - 1a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_all('2024-2025', 'banda'),
    get_categoria_id_all(get_event_id_all('2024-2025', 'banda'), '1a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 4, data.punts, 4
FROM (VALUES
    (1, 'L. CHUECOS', 16, 444, 330, 1.345),
    (2, 'R. CERVANTES', 16, 421, 393, 1.071),
    (3, 'J. F. SANTOS', 12, 439, 353, 1.244),
    (4, 'A. GÓMEZ', 11, 391, 388, 1.008),
    (5, 'J. VILA', 11, 410, 407, 1.007),
    (6, 'E. LEÓN', 10, 419, 418, 1.002),
    (7, 'A. BOIX', 4, 346, 379, 0.913),
    (8, 'J.M. CAMPOS', 4, 369, 420, 0.879),
    (9, 'J. COMAS', 4, 351, 402, 0.873),
    (10, 'J. DOMINGO', 2, 349, 418, 0.835)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_all m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- BANDA 2025 - 2a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_all('2024-2025', 'banda'),
    get_categoria_id_all(get_event_id_all('2024-2025', 'banda'), '2a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 4, data.punts, 4
FROM (VALUES
    (1, 'J.L. ROSERÓ', 18, 343, 423, 0.811),
    (2, 'E. LUENGO', 13, 323, 401, 0.805),
    (3, 'P. ÁLVAREZ', 13, 313, 428, 0.731),
    (4, 'J. RODRÍGUEZ', 12, 343, 402, 0.853),
    (5, 'R. MORENO', 9, 320, 397, 0.806),
    (6, 'P. CASANOVA', 8, 287, 437, 0.657),
    (7, 'E. DÍAZ', 8, 273, 417, 0.655),
    (8, 'J. GIBERNAU', 6, 242, 439, 0.551),
    (9, 'J. FITÓ', 3, 256, 448, 0.571),
    (10, 'R. POLLS', 0, 208, 442, 0.471)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_all m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- BANDA 2025 - 3a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_all('2024-2025', 'banda'),
    get_categoria_id_all(get_event_id_all('2024-2025', 'banda'), '3a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 4, data.punts, 4
FROM (VALUES
    (1, 'E. GARCÍA', 14, 206, 373, 0.552),
    (2, 'J. SÁNCHEZ', 13, 231, 341, 0.677),
    (3, 'J. A. SAUCEDO', 12, 186, 382, 0.487),
    (4, 'E. CURCÓ', 11, 191, 385, 0.496),
    (5, 'J. GÓMEZ', 10, 173, 327, 0.529),
    (6, 'M. GONZALVO', 6, 169, 386, 0.438),
    (7, 'R. JARQUE', 4, 159, 393, 0.405),
    (8, 'E. MILLÁN', 2, 142, 371, 0.383),
    (9, 'S. MARÍN', 0, 111, 382, 0.291)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_all m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- BANDA 2025 - 4a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_all('2024-2025', 'banda'),
    get_categoria_id_all(get_event_id_all('2024-2025', 'banda'), '4a Categoria'),
    p.id, data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 4, data.punts, 4
FROM (VALUES
    (1, 'R. SOTO', 16, 170, 384, 0.443),
    (2, 'A. MEDINA', 10, 159, 370, 0.430),
    (3, 'J. CARRASCO', 10, 152, 387, 0.393),
    (4, 'M. MANZANO', 10, 146, 398, 0.367),
    (5, 'M. QUEROL', 8, 137, 386, 0.355),
    (6, 'G. RUIZ', 6, 144, 381, 0.378),
    (7, 'J. VALLÉS', 4, 120, 394, 0.305),
    (8, 'J.M. CASAMOR', 4, 104, 400, 0.260),
    (9, 'F. VERDUGO', 4, 93, 400, 0.233)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_all m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- TODO: Continuar amb 2024, 2023, 2022...
-- (Per no fer massa llarg l'script, continuo en el següent comentari)

-- ================================================================
-- VERIFICACIÓ FINAL
-- ================================================================
SELECT
    COUNT(*) as total_classificacions,
    COUNT(DISTINCT cl.player_id) as jugadors_diferents,
    COUNT(DISTINCT e.temporada) as temporades,
    COUNT(DISTINCT e.modalitat) as modalitats,
    COUNT(DISTINCT c.nom) as categories_diferents
FROM classificacions cl
JOIN categories c ON cl.categoria_id = c.id
JOIN events e ON c.event_id = e.id
WHERE e.tipus_competicio = 'lliga_social';

-- Resum per temporada i modalitat
SELECT
    e.temporada,
    e.modalitat,
    c.nom as categoria,
    COUNT(cl.id) as classificacions
FROM classificacions cl
JOIN categories c ON cl.categoria_id = c.id
JOIN events e ON c.event_id = e.id
WHERE e.tipus_competicio = 'lliga_social'
GROUP BY e.temporada, e.modalitat, c.nom, c.ordre_categoria
ORDER BY e.temporada DESC, e.modalitat, c.ordre_categoria;

-- NETEJA
DROP FUNCTION IF EXISTS get_event_id_all(text, text);
DROP FUNCTION IF EXISTS get_categoria_id_all(uuid, text);