-- ================================================================
-- MAPPING COMPLET JUGADORS EXCEL -> SOCIS REALS
-- Basat en la llista completa de classificacions proporcionada
-- ================================================================

-- JUGADORS IDENTIFICATS AMB CERTESA:
-- 'A. GÓMEZ' -> Albert Gómez Ametller (8648) ✅
-- 'J.F. SANTOS' / 'J. F. SANTOS' -> Juan Felix Santos Gonzalez (7602) ✅
-- 'R. CERVANTES' -> Rafael Cervantes Solsona (7938) ✅
-- 'J.M. CAMPOS' -> José María Campos Gonzalez (8707) ✅
-- 'L. CHUECOS' -> Luís Chuecos Enríquez (8683) ✅
-- 'J. COMAS' -> Jaume Comas Ferrer (6110) ✅
-- 'A. BOIX' -> Agustí Boix González (8077) ✅
-- 'J. RODRÍGUEZ' -> Juan Rodríguez López (8133) ✅
-- 'A. MELGAREJO' -> Antonio Melgarejo Nicolás (8464) ✅
-- 'P. ÁLVAREZ' -> Pedro Álvarez Valencia (8485) ✅
-- 'M. SÁNCHEZ' -> Manuel Sánchez Molera (7967) ✅
-- 'J. VILA' -> Josep Vila Clopés (8690) ✅
-- 'P. CASANOVA' -> Pere Casanova Fregine (7618) ✅

-- NOUS JUGADORS A IDENTIFICAR DE LA LLISTA EXCEL:

-- De la llista de socis, aquests semblen correspondre amb els Excel:
-- 'J.L. ROSERÓ' -> Joel Lincoln Roseró Sánchez (8664)
-- 'A. FUENTES' -> Antonio Fuentes Morilla (8693)
-- 'J. FITÓ' -> Joan Fitó Ibáñez (7196)
-- 'J.A. SAUCEDO' / 'J. A. SAUCEDO' -> José Antonio Saucedo Bascón (8296)
-- 'R. MERCADER' -> Rossend Mercader Bascón (8431)
-- 'J. VEZA' -> Juan Veza Mollá (8523) o Josep Veza Mollá (8603)?
-- 'R. SOTO' -> Rafael Soto Castillo (8524)
-- 'E. DÍAZ' -> Eduard Díaz Martín (8264)
-- 'R. POLLS' -> Ricardo Polls Badia (8181)
-- 'J. GIBERNAU' -> Joaquim Gibernau Quintana (8387)
-- 'M. GONZALVO' -> Mariano Gonzalvo Domingo (8682)
-- 'R. JARQUE' -> Raúl Jarque Sánchez (7308)
-- 'A. MEDINA' -> Antonio Medina Alventosa (8556)
-- 'J. GÓMEZ' -> Jorge Gómez García (8695)
-- 'E. GARCÍA' -> Enric García Baucells (8715) o Artur García Satorra (8716)?
-- 'A. MORA' -> Àngel Mora Santamaria (8438)
-- 'S. MARIN' / 'S. MARÍN' -> Salvador Marín Bellido (1381)
-- 'M. LÓPEZ' -> Miguel López Mallach (8482)
-- 'M. MANZANO' -> Mariano Manzano García (8407)
-- 'E. MILLÁN' -> Eduardo Millán Sánchez (8366)
-- 'P. FERRÀS' -> Pedro Ferràs Omella (7541)
-- 'J. IBÁÑEZ' -> José Ibáñez Forte (8115)
-- 'A. GARCÍA' -> Artur García Satorra (8716)
-- 'J. CARRASCO' -> Joan Carrasco Montes (2749)
-- 'J. VALLÉS' / 'J. VALLES' -> Josep Valles Ros (6512)
-- 'M. QUEROL' -> Manuel Querol Viñals (3463)
-- 'J.M. CASAMOR' -> Josep Maria Casamor Regull (8408)
-- 'F. VERDUGO' -> Francesc Verdugo Martín (8212)
-- 'A. BERMEJO' -> Alfonso Bermejo Alías (8542)
-- 'R. MORENO' -> Rafael Moreno Barcia (8436)
-- 'E. LUENGO' -> Éder Luengo Torre (8732)
-- 'E. CURCÓ' -> Enric Curcó Aguarod (8433)
-- 'J.L. ARROYO' -> Juan Luis Arroyo Durán (8396)
-- 'J. SÁNCHEZ' -> Jesús Sánchez Villa (8728)
-- 'E. LEÓN' -> Esteve León Puig (3019)
-- 'J. DOMINGO' -> Jordi Domingo Juan (8747)
-- 'G. RUIZ' -> Guillem Ruiz Camara (8741)
-- 'J. HERNÁNDEZ' -> Juan Hernández Márquez (8186)
-- 'I. HERNÁNDEZ' -> Ignacio Hernández Falcó (8311)
-- 'J. ORTIZ' -> Jesús Ortiz Romero (6855)

-- DUBTOSOS QUE NECESSITEN CONFIRMACIÓ:
-- 'J. VEZA' -> podria ser Juan Veza Mollá (8523) o Josep Veza Mollá (8603)
-- 'E. GARCÍA' -> podria ser Enric García Baucells (8715) o Artur García Satorra (8716)
-- Altres que no estic segur...

CREATE TEMP TABLE player_mapping_complete AS
SELECT * FROM (VALUES
    -- CONFIRMATS
    ('A. GÓMEZ', 8648),           -- Albert Gómez Ametller
    ('J.F. SANTOS', 7602),        -- Juan Felix Santos Gonzalez
    ('J. F. SANTOS', 7602),       -- Mateix jugador, variant del nom
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
    ('P. CASANOVA', 7618),        -- Pere Casanova Fregine

    -- NOUS IDENTIFICATS (NECESSITEN CONFIRMACIÓ)
    ('J.L. ROSERÓ', 8664),        -- Joel Lincoln Roseró Sánchez
    ('A. FUENTES', 8693),         -- Antonio Fuentes Morilla
    ('J. FITÓ', 7196),            -- Joan Fitó Ibáñez
    ('J.A. SAUCEDO', 8296),       -- José Antonio Saucedo Bascón
    ('J. A. SAUCEDO', 8296),      -- Mateix jugador, variant del nom
    ('R. MERCADER', 8431),        -- Rossend Mercader Bascón
    ('J. VEZA', 8523),            -- Juan Veza Mollá ✅
    ('R. SOTO', 8524),            -- Rafael Soto Castillo
    ('E. DÍAZ', 8264),            -- Eduard Díaz Martín
    ('R. POLLS', 8181),           -- Ricardo Polls Badia
    ('J. GIBERNAU', 8387),        -- Joaquim Gibernau Quintana
    ('M. GONZALVO', 8682),        -- Mariano Gonzalvo Domingo
    ('R. JARQUE', 7308),          -- Raúl Jarque Sánchez
    ('A. MEDINA', 8556),          -- Antonio Medina Alventosa
    ('J. GÓMEZ', 8695),           -- Jorge Gómez García
    ('E. GARCÍA', 8715),          -- Enric García Baucells ✅
    ('A. MORA', 8438),            -- Àngel Mora Santamaria
    ('S. MARIN', 1381),           -- Salvador Marín Bellido
    ('S. MARÍN', 1381),           -- Mateix jugador, variant del nom
    ('M. LÓPEZ', 8482),           -- Miguel López Mallach
    ('M. MANZANO', 8407),         -- Mariano Manzano García
    ('E. MILLÁN', 8366),          -- Eduardo Millán Sánchez
    ('P. FERRÀS', 7541),          -- Pedro Ferràs Omella
    ('J. IBÁÑEZ', 8115),          -- José Ibáñez Forte
    ('A. GARCÍA', 8716),          -- Artur García Satorra
    ('J. CARRASCO', 2749),        -- Joan Carrasco Montes
    ('J. VALLÉS', 6512),          -- Josep Valles Ros
    ('J. VALLES', 6512),          -- Mateix jugador, variant del nom
    ('M. QUEROL', 3463),          -- Manuel Querol Viñals
    ('J.M. CASAMOR', 8408),       -- Josep Maria Casamor Regull
    ('F. VERDUGO', 8212),         -- Francesc Verdugo Martín
    ('A. BERMEJO', 8542),         -- Alfonso Bermejo Alías
    ('R. MORENO', 8436),          -- Rafael Moreno Barcia
    ('E. LUENGO', 8732),          -- Éder Luengo Torre
    ('E. CURCÓ', 8433),           -- Enric Curcó Aguarod
    ('J.L. ARROYO', 8396),        -- Juan Luis Arroyo Durán
    ('J. SÁNCHEZ', 8728),         -- Jesús Sánchez Villa
    ('E. LEÓN', 3019),            -- Esteve León Puig
    ('J. DOMINGO', 8747),         -- Jordi Domingo Juan
    ('G. RUIZ', 8741),            -- Guillem Ruiz Camara
    ('J. HERNÁNDEZ', 8186),       -- Juan Hernández Márquez
    ('I. HERNÁNDEZ', 8311),       -- Ignacio Hernández Falcó
    ('J. ORTIZ', 6855),           -- Jesús Ortiz Romero

    -- CORRECCIONS CONFIRMADES
    ('M. PAMPLONA', 7193),        -- Soci 7193 ✅
    ('I. LÓPEZ', 7439),           -- Isidoro López Zurdo ✅
    ('P. RUIZ', 23),              -- Soci 23 ✅
    ('M. ÁLVAREZ', 8310),         -- Soci 8310 ✅
    ('A. TRILLO', 8208),          -- Antonio Trillo Palma ✅
    ('F. LEDO', 8483),            -- Francesc Ledo Gasia ✅
    ('F. LEDÓ', 8483),            -- Mateix jugador, variant del nom
    ('V. INOCENTES', 5818),       -- Vicens Inocentes Sivilla ✅

    -- ÚLTIMES CORRECCIONS
    ('E. ROYES', 8411),           -- Soci 8411 ✅
    ('F. ROYES', 8411),           -- Mateix que E. ROYES
    ('J. ROYES', 8582),           -- Soci 8582 ✅
    ('J. MUÑOZ', 8439),           -- Soci 8439 ✅
    ('L. GONZÁLEZ', 7026),        -- Soci 7026 ✅
    ('D. CORBALÁN', 8041),        -- Soci 8041 ✅
    ('A. FERNÁNDEZ', 2)           -- Soci 2 ✅

) AS mapping(nom_excel, numero_soci);

-- Verificar el mapping complet
SELECT
    m.nom_excel,
    m.numero_soci,
    p.nom as nom_real,
    p.email,
    CASE WHEN p.id IS NULL THEN '❌ NO TROBAT' ELSE '✅ TROBAT' END as estat
FROM player_mapping_complete m
LEFT JOIN players p ON p.numero_soci = m.numero_soci
ORDER BY m.numero_soci;

-- Jugadors Excel que no tenen mapping encara
SELECT DISTINCT nom_excel
FROM (
    -- Aquí hauria d'anar una llista de tots els noms Excel únics
    -- Però com que és molt llarga, millor fer-ho manualment
    SELECT 'M. PAMPLONA' as nom_excel UNION ALL
    SELECT 'I. LÓPEZ' UNION ALL
    SELECT 'M. ÁLVAREZ' UNION ALL
    SELECT 'P. RUIZ' UNION ALL
    SELECT 'A. TRILLO' UNION ALL
    SELECT 'F. LEDO' UNION ALL
    SELECT 'F. LEDÓ' UNION ALL
    SELECT 'J. ROYES' UNION ALL
    SELECT 'E. ROYES' UNION ALL
    SELECT 'J. MUÑOZ' UNION ALL
    SELECT 'L. GONZÁLEZ' UNION ALL
    SELECT 'D. CORBALÁN' UNION ALL
    SELECT 'V. INOCENTES' UNION ALL
    SELECT 'F. ROYES' UNION ALL
    SELECT 'A. FERNÁNDEZ'
) as excel_names
WHERE nom_excel NOT IN (SELECT nom_excel FROM player_mapping_complete);