-- =================================================================
-- SCRIPT COMPLET: SOLUCIÓ DEFINITIVA FOREIGN KEYS
-- =================================================================
-- Data: 2025-09-21 12:54:57
-- Objectiu: Afegir tots els socis necessaris per a mitjanes històriques
-- 
-- COBERTURA:
-- • Exsocis 1-34: amb dades històriques estimades
-- • Exsocis coneguts: 48 amb noms i cognoms reals
-- • Placeholders: 71 socis sense dades conegudes
-- =================================================================

BEGIN;

-- =================================================================
-- STEP 1: EXSOCIS HISTÒRICS (IDs 1-34)
-- =================================================================

-- STEP 1: Preparar l'esquema de la taula socis
-- =============================================================
-- Estructura actual: numero_soci (int), cognoms (text NOT NULL), nom (text), email (text)

-- Afegir camp 'de_baixa' per gestionar socis donats de baixa
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'de_baixa'
    ) THEN
        ALTER TABLE socis ADD COLUMN de_baixa BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Camp "de_baixa" afegit a la taula socis';
    ELSE
        RAISE NOTICE 'Camp "de_baixa" ja existeix a la taula socis';
    END IF;
END $$;

-- Afegir camp 'data_baixa' per registrar quan es va donar de baixa
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'data_baixa'
    ) THEN
        ALTER TABLE socis ADD COLUMN data_baixa DATE NULL;
        RAISE NOTICE 'Camp "data_baixa" afegit a la taula socis';
    ELSE
        RAISE NOTICE 'Camp "data_baixa" ja existeix a la taula socis';
    END IF;
END $$;

-- Crear índex per millorar consultes per estat de baixa
CREATE INDEX IF NOT EXISTS idx_socis_de_baixa ON socis(de_baixa);

-- STEP 2: Inserir exsocis identificats
-- =============================================================

-- Eliminar exsocis existents en el rang 1-34 per evitar duplicats
DELETE FROM socis WHERE numero_soci BETWEEN 1 AND 34;

-- Inserir tots els exsocis amb la seva informació (separant nom i cognoms)
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES
(1, 'A.', 'ALUJA', NULL, TRUE, '2011-12-31'),
(2, 'A.', 'FERNÁNDEZ', NULL, TRUE, '2024-12-31'),
(3, 'A.', 'MARTÍ', NULL, TRUE, '2009-12-31'),
(4, '', 'ALBARRACIN', NULL, TRUE, '2009-12-31'),
(5, '', 'ALCARAZ', NULL, TRUE, '2008-12-31'),
(6, '', 'BARRIENTOS', NULL, TRUE, '2009-12-31'),
(7, '', 'BARRIERE', NULL, TRUE, '2004-12-31'),
(8, 'C.', 'GIRÓ', NULL, TRUE, '2012-12-31'),
(9, '', 'CASBAS', NULL, TRUE, '2004-12-31'),
(10, '', 'DOMÉNECH', NULL, TRUE, '2017-12-31'),
(11, '', 'DONADEU', NULL, TRUE, '2003-12-31'),
(12, '', 'DURAN', NULL, TRUE, '2009-12-31'),
(13, 'E.', 'GIRÓ', NULL, TRUE, '2012-12-31'),
(14, 'E.', 'LLORENTE', NULL, TRUE, '2021-12-31'),
(15, '', 'ERRA', NULL, TRUE, '2008-12-31'),
(16, 'J.', 'LAHOZ', NULL, TRUE, '2017-12-31'),
(17, 'J.', 'ROVIROSA', NULL, TRUE, '2011-12-31'),
(18, 'JUAN', 'GÓMEZ', NULL, TRUE, '2018-12-31'),
(19, 'M.', 'ALMIRALL', NULL, TRUE, '2011-12-31'),
(20, 'M.', 'PALAU', NULL, TRUE, '2011-12-31'),
(21, 'M.', 'PRAT', NULL, TRUE, '2012-12-31'),
(22, '', 'MAGRIÑA', NULL, TRUE, '2003-12-31'),
(23, 'P.', 'RUIZ', NULL, TRUE, '2023-12-31'),
(24, '', 'PEÑA', NULL, TRUE, '2006-12-31'),
(25, '', 'PUIG', NULL, TRUE, '2007-12-31'),
(26, '', 'REAL', NULL, TRUE, '2007-12-31'),
(27, '', 'RODRÍGUEZ', NULL, TRUE, '2009-12-31'),
(28, 'S.', 'BASCÓN', NULL, TRUE, '2020-12-31'),
(29, '', 'SOLANES', NULL, TRUE, '2009-12-31'),
(30, '', 'SOLANS', NULL, TRUE, '2008-12-31'),
(31, '', 'SUÑE', NULL, TRUE, '2008-12-31'),
(32, '', 'TABERNER', NULL, TRUE, '2005-12-31'),
(33, '', 'TALAVERA', NULL, TRUE, '2004-12-31'),
(34, '', 'VIVAS', NULL, TRUE, '2009-12-31');

-- STEP 3: Verificació i consultes
-- =============================================================

-- Verificar la inserció d'exsocis
SELECT 
    COUNT(*) as exsocis_inserits,
    MIN(numero_soci) as id_minim,
    MAX(numero_soci) as id_maxim
FROM socis 
WHERE de_baixa = TRUE AND numero_soci BETWEEN 1 AND 34;

-- Mostrar resum per estat de baixa
SELECT 
    de_baixa,
    COUNT(*) as total_socis
FROM socis 
GROUP BY de_baixa
ORDER BY de_baixa;

-- Mostrar tots els exsocis ordenats per número de soci
SELECT 
    numero_soci, 
    nom, 
    cognoms,
    email,
    de_baixa,
    data_baixa
FROM socis 
WHERE de_baixa = TRUE AND numero_soci BETWEEN 1 AND 34
ORDER BY numero_soci;

-- Verificar que els IDs de mitjanes històriques ara són vàlids
SELECT 
    COUNT(DISTINCT mh.soci_id) as exsocis_amb_mitjanes,
    MIN(mh.soci_id) as id_minim,
    MAX(mh.soci_id) as id_maxim
FROM mitjanes_historiques mh
INNER JOIN socis s ON mh.soci_id = s.numero_soci
WHERE s.de_baixa = TRUE;


-- =================================================================
-- STEP 2: EXSOCIS CONEGUTS AMB DADES REALS
-- =================================================================

-- Eliminar exsocis coneguts si ja existeixen per evitar duplicats
DELETE FROM socis WHERE numero_soci IN (263,987,1381,1908,1988,2377,2548,3049,4073,4166,5261,5655,5935,6332,6550,6670,6685,6728,6844,6953,7009,7010,7026,7139,7148,7150,7184,7189,7190,7193,7279,7408,7417,7431,7543,7640,7642,7807,7937,7952,7954,8031,8093,8102,8185,8229,8310,8582);

-- Inserir exsocis coneguts amb dades reals
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (263, 'Ramon', 'Colom Codina', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (987, 'David', 'Nogues Blanco', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1381, 'Salvador', 'Marin Bellido', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1908, 'Francesc', 'Tares Millan', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1988, 'Carles', 'Vidal Pons', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (2377, 'Joan', 'Sanz Mora', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (2548, 'Josep', 'Mir Bellmunt', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (3049, 'Jordi', 'Selgas Catala', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (4073, 'Jaume', 'Griñó Borbón', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (4166, 'Miquel', 'Gimeno Hernández', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5261, 'Andreu', 'Del Rio Soler', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5655, 'Josep', 'Gelabert Von-Weber', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5935, 'Ricard', 'Grau Menal', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6332, 'Josep', 'Fernández Biarnau', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6550, 'Joan', 'Montero Perez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6670, 'Joan', 'Quevedo Roig', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6685, 'Pau', 'Serra Balaguer', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6728, 'Miquel', 'Farré Quintana', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6844, 'Gabriel', 'Gimenez Garcia', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6953, 'Juan', 'Hernandez Marquez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7009, 'Andres', 'Martinez Garcia', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7010, 'Felipe', 'Gomez Gimenez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7026, 'Lluis', 'Gonzalez Carvajal', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7139, 'Mario', 'Ebri Martinez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7148, 'Isaac', 'Gomez Gimenez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7150, 'Jesus', 'Perez Garcia', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7184, 'Alfonso', 'Garcia Garcia', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7189, 'Josep Ma', 'Soms Grau', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7190, 'Francisco', 'Barcia Lora', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7193, 'Manel', 'Pamplona Peralta', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7279, 'Pascual', 'Ballester Diaz', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7408, 'Albertyo', 'Porta Alesanco', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7417, 'Salvador', 'Barris Oms', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7431, 'Eduardo', 'Rodriguez Rios', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7543, 'Manel', 'Bruquetas Vall', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7640, 'Hammer', 'Kladivo Vladislav', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7642, 'Ramon', 'Bures Valls', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7807, 'Alfons', 'Campillo Gallego', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7937, 'Josep Ma', 'Val Aina', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7952, 'Sergi', 'Escoda Llort', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7954, 'Alberto-Oscar', 'Pometti Cos', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8031, 'Angel', 'Diez Diez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8093, 'Ramon', 'Pallarès Casanovas', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8102, 'Pere', 'Solergibert Fauría', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8185, 'Oscar', 'Ramirez Torres', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8229, 'Francisco', 'Torrecillas Ramirez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8310, 'Jose Miguel', 'Alvarez Martínez', NULL, TRUE, '2024-12-31');
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8582, 'Jose', 'Royes Lapeña', NULL, TRUE, '2024-12-31');

-- Verificacions
SELECT COUNT(*) as exsocis_coneguts_inserits FROM socis WHERE numero_soci IN (263,987,1381,1908,1988,2377,2548,3049,4073,4166,5261,5655,5935,6332,6550,6670,6685,6728,6844,6953,7009,7010,7026,7139,7148,7150,7184,7189,7190,7193,7279,7408,7417,7431,7543,7640,7642,7807,7937,7952,7954,8031,8093,8102,8185,8229,8310,8582);

-- Mostrar alguns exsocis inserits
SELECT numero_soci, nom, cognoms, de_baixa FROM socis WHERE numero_soci IN (263,987,1381,1908,1988,2377,2548,3049,4073,4166,5261,5655,5935,6332,6550,6670,6685,6728,6844,6953,7009,7010,7026,7139,7148,7150,7184,7189,7190,7193,7279,7408,7417,7431,7543,7640,7642,7807,7937,7952,7954,8031,8093,8102,8185,8229,8310,8582) ORDER BY numero_soci LIMIT 10;


-- =================================================================
-- STEP 3: PLACEHOLDERS PER SOCIS DESCONEGUTS
-- =================================================================
-- Aquests són socis que apareixen a mitjanes històriques però
-- no tenim les seves dades. Es creen com a placeholders.

INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (261, 'SOCI_261', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (407, 'SOCI_407', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (2749, 'SOCI_2749', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (3019, 'SOCI_3019', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (3463, 'SOCI_3463', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5818, 'SOCI_5818', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6110, 'SOCI_6110', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6203, 'SOCI_6203', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6512, 'SOCI_6512', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6811, 'SOCI_6811', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6855, 'SOCI_6855', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6897, 'SOCI_6897', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7044, 'SOCI_7044', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7196, 'SOCI_7196', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7308, 'SOCI_7308', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7439, 'SOCI_7439', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7541, 'SOCI_7541', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7586, 'SOCI_7586', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7602, 'SOCI_7602', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7618, 'SOCI_7618', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7938, 'SOCI_7938', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7967, 'SOCI_7967', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8041, 'SOCI_8041', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8062, 'SOCI_8062', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8073, 'SOCI_8073', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8077, 'SOCI_8077', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8115, 'SOCI_8115', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8133, 'SOCI_8133', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8137, 'SOCI_8137', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8181, 'SOCI_8181', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8183, 'SOCI_8183', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8186, 'SOCI_8186', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8208, 'SOCI_8208', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8212, 'SOCI_8212', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8264, 'SOCI_8264', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8296, 'SOCI_8296', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8311, 'SOCI_8311', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8366, 'SOCI_8366', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8387, 'SOCI_8387', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8396, 'SOCI_8396', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8407, 'SOCI_8407', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8408, 'SOCI_8408', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8411, 'SOCI_8411', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8431, 'SOCI_8431', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8433, 'SOCI_8433', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8436, 'SOCI_8436', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8438, 'SOCI_8438', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8439, 'SOCI_8439', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8464, 'SOCI_8464', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8482, 'SOCI_8482', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8483, 'SOCI_8483', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8485, 'SOCI_8485', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8523, 'SOCI_8523', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8524, 'SOCI_8524', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8535, 'SOCI_8535', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8542, 'SOCI_8542', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8556, 'SOCI_8556', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8648, 'SOCI_8648', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8664, 'SOCI_8664', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8682, 'SOCI_8682', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8683, 'SOCI_8683', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8690, 'SOCI_8690', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8693, 'SOCI_8693', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8695, 'SOCI_8695', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8707, 'SOCI_8707', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8715, 'SOCI_8715', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8716, 'SOCI_8716', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8728, 'SOCI_8728', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8732, 'SOCI_8732', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8741, 'SOCI_8741', 'DESCONEGUT', NULL, FALSE, NULL);
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8747, 'SOCI_8747', 'DESCONEGUT', NULL, FALSE, NULL);

-- =================================================================
-- STEP 4: VERIFICACIONS FINALS
-- =================================================================

-- Comptar tots els socis per categoria
SELECT 
    CASE 
        WHEN numero_soci BETWEEN 1 AND 34 THEN 'Exsocis històrics'
        WHEN nom NOT LIKE 'SOCI_%' AND de_baixa = TRUE THEN 'Exsocis coneguts'
        WHEN nom LIKE 'SOCI_%' THEN 'Placeholders'
        ELSE 'Socis actius'
    END as categoria,
    COUNT(*) as total
FROM socis 
GROUP BY 
    CASE 
        WHEN numero_soci BETWEEN 1 AND 34 THEN 'Exsocis històrics'
        WHEN nom NOT LIKE 'SOCI_%' AND de_baixa = TRUE THEN 'Exsocis coneguts'
        WHEN nom LIKE 'SOCI_%' THEN 'Placeholders'
        ELSE 'Socis actius'
    END
ORDER BY categoria;

-- Verificar que no hi ha cap ID orfe a mitjanes històriques
SELECT COUNT(*) as ids_orfes 
FROM mitjanes_historiques mh 
LEFT JOIN socis s ON mh.soci_id = s.numero_soci 
WHERE s.numero_soci IS NULL;

COMMIT;

-- =================================================================
-- RESULTAT FINAL ESPERAT:
-- • Total socis: 119
-- • Exsocis històrics: 34
-- • Exsocis coneguts: 48
-- • Placeholders: 71
-- • IDs orfes: 0
-- =================================================================
