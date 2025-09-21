-- =================================================================
-- SCRIPT SIMPLIFICAT: NOMÉS EXSOCIS
-- =================================================================
-- Data: 2025-09-21 12:58:33
-- Objectiu: Afegir només els exsocis necessaris
-- Els socis actius ja existeixen a la base de dades
-- 
-- COBERTURA:
-- • Exsocis històrics (1-34): 34 socis
-- • Exsocis coneguts: 48 socis
-- • Socis actius: ja existeixen a la BD
-- =================================================================

BEGIN;

-- =================================================================
-- STEP 1: EXSOCIS HISTÒRICS (IDs 1-34)
-- =================================================================

-- Afegir camp 'de_baixa' si no existeix
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'de_baixa'
    ) THEN
        ALTER TABLE socis ADD COLUMN de_baixa BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Camp de_baixa afegit a la taula socis';
    END IF;
END $$;

-- Afegir camp 'data_baixa' si no existeix
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'socis' AND column_name = 'data_baixa'
    ) THEN
        ALTER TABLE socis ADD COLUMN data_baixa DATE NULL;
        RAISE NOTICE 'Camp data_baixa afegit a la taula socis';
    END IF;
END $$;

-- Crear índex per millorar consultes
CREATE INDEX IF NOT EXISTS idx_socis_de_baixa ON socis(de_baixa);

-- Eliminar exsocis 1-34 si ja existeixen
DELETE FROM socis WHERE numero_soci BETWEEN 1 AND 34;

-- Inserir exsocis històrics
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES
(1, 'A.', 'ALUJA', NULL, TRUE, '2011-12-31'),
(2, 'A.', 'FERNÁNDEZ', NULL, TRUE, '2024-12-31'),
(3, 'A.', 'MARTÍ', NULL, TRUE, '2009-12-31'),
(4, '[EXSOCI]', 'ALBARRACIN', NULL, TRUE, '2009-12-31'),
(5, '[EXSOCI]', 'ALCARAZ', NULL, TRUE, '2008-12-31'),
(6, '[EXSOCI]', 'BARRIENTOS', NULL, TRUE, '2009-12-31'),
(7, '[EXSOCI]', 'BARRIERE', NULL, TRUE, '2004-12-31'),
(8, 'C.', 'GIRÓ', NULL, TRUE, '2012-12-31'),
(9, '[EXSOCI]', 'CASBAS', NULL, TRUE, '2004-12-31'),
(10, '[EXSOCI]', 'DOMÉNECH', NULL, TRUE, '2017-12-31'),
(11, '[EXSOCI]', 'DONADEU', NULL, TRUE, '2003-12-31'),
(12, '[EXSOCI]', 'DURAN', NULL, TRUE, '2009-12-31'),
(13, 'E.', 'GIRÓ', NULL, TRUE, '2012-12-31'),
(14, 'E.', 'LLORENTE', NULL, TRUE, '2021-12-31'),
(15, '[EXSOCI]', 'ERRA', NULL, TRUE, '2008-12-31'),
(16, 'J.', 'LAHOZ', NULL, TRUE, '2017-12-31'),
(17, 'J.', 'ROVIROSA', NULL, TRUE, '2011-12-31'),
(18, 'JUAN', 'GÓMEZ', NULL, TRUE, '2018-12-31'),
(19, 'M.', 'ALMIRALL', NULL, TRUE, '2011-12-31'),
(20, 'M.', 'PALAU', NULL, TRUE, '2011-12-31'),
(21, 'M.', 'PRAT', NULL, TRUE, '2012-12-31'),
(22, '[EXSOCI]', 'MAGRIÑA', NULL, TRUE, '2003-12-31'),
(23, 'P.', 'RUIZ', NULL, TRUE, '2023-12-31'),
(24, '[EXSOCI]', 'PEÑA', NULL, TRUE, '2006-12-31'),
(25, '[EXSOCI]', 'PUIG', NULL, TRUE, '2007-12-31'),
(26, '[EXSOCI]', 'REAL', NULL, TRUE, '2007-12-31'),
(27, '[EXSOCI]', 'RODRÍGUEZ', NULL, TRUE, '2009-12-31'),
(28, 'S.', 'BASCÓN', NULL, TRUE, '2020-12-31'),
(29, '[EXSOCI]', 'SOLANES', NULL, TRUE, '2009-12-31'),
(30, '[EXSOCI]', 'SOLANS', NULL, TRUE, '2008-12-31'),
(31, '[EXSOCI]', 'SUÑE', NULL, TRUE, '2008-12-31'),
(32, '[EXSOCI]', 'TABERNER', NULL, TRUE, '2005-12-31'),
(33, '[EXSOCI]', 'TALAVERA', NULL, TRUE, '2004-12-31'),
(34, '[EXSOCI]', 'VIVAS', NULL, TRUE, '2009-12-31');

-- =================================================================
-- STEP 2: EXSOCIS CONEGUTS AMB DADES REALS
-- =================================================================
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7807, 'Alfons', 'Campillo Gallego', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5261, 'Andreu', 'Del Rio Soler', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8031, 'Angel', 'Diez Diez', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7009, 'Andres', 'Martinez Garcia', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7954, 'Alberto-Oscar', 'Pometti Cos', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7408, 'Albertyo', 'Porta Alesanco', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1988, 'Carles', 'Vidal Pons', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7431, 'Eduardo', 'Rodriguez Rios', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7952, 'Sergi', 'Escoda Llort', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7190, 'Francisco', 'Barcia Lora', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7010, 'Felipe', 'Gomez Gimenez', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1908, 'Francesc', 'Tares Millan', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8229, 'Francisco', 'Torrecillas Ramirez', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6728, 'Miquel', 'Farré Quintana', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6844, 'Gabriel', 'Gimenez Garcia', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7184, 'Alfonso', 'Garcia Garcia', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7148, 'Isaac', 'Gomez Gimenez', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6953, 'Juan', 'Hernandez Marquez', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6332, 'Josep', 'Fernández Biarnau', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5655, 'Josep', 'Gelabert Von-Weber', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (4073, 'Jaume', 'Griñó Borbón', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (2548, 'Josep', 'Mir Bellmunt', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6550, 'Joan', 'Montero Perez', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8582, 'Jose', 'Royes Lapeña', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (2377, 'Joan', 'Sanz Mora', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (3049, 'Jordi', 'Selgas Catala', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7189, 'Josep Ma', 'Soms Grau', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7937, 'Josep Ma', 'Val Aina', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (4166, 'Miquel', 'Gimeno Hernández', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7026, 'Lluis', 'Gonzalez Carvajal', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8310, 'Jose Miguel', 'Alvarez Martínez', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7543, 'Manel', 'Bruquetas Vall', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7139, 'Mario', 'Ebri Martinez', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7193, 'Manel', 'Pamplona Peralta', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (987, 'David', 'Nogues Blanco', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8185, 'Oscar', 'Ramirez Torres', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7279, 'Pascual', 'Ballester Diaz', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6685, 'Pau', 'Serra Balaguer', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8102, 'Pere', 'Solergibert Fauría', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7150, 'Jesus', 'Perez Garcia', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (6670, 'Joan', 'Quevedo Roig', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7642, 'Ramon', 'Bures Valls', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (263, 'Ramon', 'Colom Codina', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (5935, 'Ricard', 'Grau Menal', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (8093, 'Ramon', 'Pallarès Casanovas', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7417, 'Salvador', 'Barris Oms', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (1381, 'Salvador', 'Marin Bellido', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) VALUES (7640, 'Hammer', 'Kladivo Vladislav', NULL, TRUE, '2024-12-31') ON CONFLICT (numero_soci) DO NOTHING;

-- =================================================================
-- VERIFICACIONS FINALS
-- =================================================================

-- Comptar exsocis afegits
SELECT 
    CASE 
        WHEN numero_soci BETWEEN 1 AND 34 THEN 'Exsocis històrics'
        WHEN de_baixa = TRUE THEN 'Exsocis coneguts'
        ELSE 'Socis actius'
    END as categoria,
    COUNT(*) as total
FROM socis 
GROUP BY categoria
ORDER BY categoria;

COMMIT;
