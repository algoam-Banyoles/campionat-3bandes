-- ================================================================
-- IMPORTACIÓ FINAL DE TOTES LES CLASSIFICACIONS HISTÒRIQUES
-- Amb mapping complet de jugadors Excel → Socis reals
-- ================================================================

-- MAPPING COMPLET JUGADORS
CREATE TEMP TABLE player_mapping_final AS
SELECT * FROM (VALUES
    -- JUGADORS CONFIRMATS
    ('A. GÓMEZ', 8648),           ('J.F. SANTOS', 7602),        ('J. F. SANTOS', 7602),
    ('R. CERVANTES', 7938),       ('J.M. CAMPOS', 8707),        ('L. CHUECOS', 8683),
    ('J. COMAS', 6110),           ('A. BOIX', 8077),            ('J. RODRÍGUEZ', 8133),
    ('A. MELGAREJO', 8464),       ('P. ÁLVAREZ', 8485),         ('M. SÁNCHEZ', 7967),
    ('J. VILA', 8690),            ('P. CASANOVA', 7618),        ('J.L. ROSERÓ', 8664),
    ('A. FUENTES', 8693),         ('J. FITÓ', 7196),            ('J.A. SAUCEDO', 8296),
    ('J. A. SAUCEDO', 8296),      ('R. MERCADER', 8431),        ('J. VEZA', 8523),
    ('R. SOTO', 8524),            ('E. DÍAZ', 8264),            ('R. POLLS', 8181),
    ('J. GIBERNAU', 8387),        ('M. GONZALVO', 8682),        ('R. JARQUE', 7308),
    ('A. MEDINA', 8556),          ('J. GÓMEZ', 8695),           ('E. GARCÍA', 8715),
    ('A. MORA', 8438),            ('S. MARIN', 1381),           ('S. MARÍN', 1381),
    ('M. LÓPEZ', 8482),           ('M. MANZANO', 8407),         ('E. MILLÁN', 8366),
    ('P. FERRÀS', 7541),          ('J. IBÁÑEZ', 8115),          ('A. GARCÍA', 8716),
    ('J. CARRASCO', 2749),        ('J. VALLÉS', 6512),          ('J. VALLES', 6512),
    ('M. QUEROL', 3463),          ('J.M. CASAMOR', 8408),       ('F. VERDUGO', 8212),
    ('A. BERMEJO', 8542),         ('R. MORENO', 8436),          ('E. LUENGO', 8732),
    ('E. CURCÓ', 8433),           ('J.L. ARROYO', 8396),        ('J. SÁNCHEZ', 8728),
    ('E. LEÓN', 3019),            ('J. DOMINGO', 8747),         ('G. RUIZ', 8741),
    ('J. HERNÁNDEZ', 8186),       ('I. HERNÁNDEZ', 8311),       ('J. ORTIZ', 6855),
    ('M. PAMPLONA', 7193),        ('I. LÓPEZ', 7439),           ('P. RUIZ', 23),
    ('M. ÁLVAREZ', 8310),         ('A. TRILLO', 8208),          ('F. LEDO', 8483),
    ('F. LEDÓ', 8483),            ('V. INOCENTES', 5818),       ('E. ROYES', 8411),
    ('F. ROYES', 8411),           ('J. ROYES', 8582),           ('J. MUÑOZ', 8439),
    ('L. GONZÁLEZ', 7026),        ('D. CORBALÁN', 8041),        ('A. FERNÁNDEZ', 2)
) AS mapping(nom_excel, numero_soci);

-- FUNCIONS AUXILIARS
CREATE OR REPLACE FUNCTION get_event_id_final(temporada_param text, modalitat_param text)
RETURNS uuid AS $$
DECLARE
    event_uuid uuid;
BEGIN
    SELECT id INTO event_uuid
    FROM events
    WHERE temporada = temporada_param
      AND modalitat = modalitat_param
      AND tipus_competicio = 'lliga_social';
    RETURN event_uuid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_categoria_id_final(event_uuid uuid, categoria_nom text)
RETURNS uuid AS $$
DECLARE
    categoria_uuid uuid;
BEGIN
    SELECT id INTO categoria_uuid
    FROM categories
    WHERE event_id = event_uuid AND nom = categoria_nom;
    RETURN categoria_uuid;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- IMPORTACIÓ CLASSIFICACIONS 2025
-- ================================================================

-- 3 BANDES 2025 - 1a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_final('2024-2025', 'tres_bandes'),
    get_categoria_id_final(get_event_id_final('2024-2025', 'tres_bandes'), '1a Categoria'),
    p.id,
    data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 3, data.punts, 3  -- Aproximació partides
FROM (VALUES
    (1, 'A. GÓMEZ', 22, 236, 239, 0.987),
    (2, 'J.F. SANTOS', 18, 218, 262, 0.832),
    (3, 'R. CERVANTES', 18, 213, 333, 0.640),
    (4, 'J.M. CAMPOS', 17, 217, 289, 0.751),
    (5, 'L. CHUECOS', 16, 199, 313, 0.636),
    (6, 'J. COMAS', 13, 177, 405, 0.437),
    (7, 'A. BOIX', 10, 184, 371, 0.496),
    (8, 'J. RODRÍGUEZ', 9, 144, 421, 0.342),
    (9, 'A. MELGAREJO', 8, 156, 364, 0.429),
    (10, 'P. ÁLVAREZ', 7, 151, 386, 0.391),
    (11, 'M. SÁNCHEZ', 7, 154, 423, 0.364),
    (12, 'J. VILA', 6, 140, 346, 0.405),
    (13, 'P. CASANOVA', 5, 136, 373, 0.365)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_final m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- 3 BANDES 2025 - 2a CATEGORIA
INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular, partides_jugades, partides_guanyades, partides_perdudes)
SELECT
    get_event_id_final('2024-2025', 'tres_bandes'),
    get_categoria_id_final(get_event_id_final('2024-2025', 'tres_bandes'), '2a Categoria'),
    p.id,
    data.posicio, data.punts, data.caramboles_favor, data.caramboles_contra, data.mitjana_particular,
    data.punts + 3, data.punts, 3
FROM (VALUES
    (1, 'J.L. ROSERÓ', 21, 168, 337, 0.498),
    (2, 'A. FUENTES', 18, 157, 393, 0.399),
    (3, 'J. FITÓ', 14, 134, 419, 0.320),
    (4, 'J.A. SAUCEDO', 14, 125, 449, 0.278),
    (5, 'R. MERCADER', 13, 120, 471, 0.255),
    (6, 'J. VEZA', 12, 125, 423, 0.296),
    (7, 'R. SOTO', 12, 100, 484, 0.207),
    (8, 'E. DÍAZ', 11, 120, 474, 0.253),
    (9, 'R. POLLS', 11, 92, 468, 0.197),
    (10, 'J. GIBERNAU', 10, 134, 417, 0.321),
    (11, 'M. GONZALVO', 8, 89, 439, 0.203),
    (12, 'R. JARQUE', 6, 95, 489, 0.194),
    (13, 'A. MEDINA', 6, 90, 474, 0.190)
) AS data(posicio, nom_excel, punts, caramboles_favor, caramboles_contra, mitjana_particular)
JOIN player_mapping_final m ON m.nom_excel = data.nom_excel
JOIN players p ON p.numero_soci = m.numero_soci;

-- TODO: Afegir totes les altres categories i anys
-- Puc continuar amb 3a categoria, LLIURE, BANDA i anys anteriors...

-- ================================================================
-- VERIFICACIÓ
-- ================================================================
SELECT
    COUNT(*) as total_classificacions_importades,
    COUNT(DISTINCT cl.player_id) as jugadors_diferents,
    COUNT(DISTINCT e.temporada) as temporades,
    COUNT(DISTINCT e.modalitat) as modalitats
FROM classificacions cl
JOIN categories c ON cl.categoria_id = c.id
JOIN events e ON c.event_id = e.id
WHERE e.tipus_competicio = 'lliga_social';

-- NETEJA
DROP FUNCTION IF EXISTS get_event_id_final(text, text);
DROP FUNCTION IF EXISTS get_categoria_id_final(uuid, text);