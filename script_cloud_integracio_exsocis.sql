-- =================================================================
-- SCRIPT COMPLET: INTEGRACIÓ EXSOCIS A LA BASE DE DADES
-- =================================================================
-- Data: 2025-09-21
-- Objectiu: Integrar exsocis identificats a la taula socis amb estat 'baixa'
-- Descripció: Aquest script permet gestionar adequadament l'historial de socis
--             i facilita la baixa de socis actuals quan sigui necessari
-- =================================================================

BEGIN;

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

COMMIT;

-- =================================================================
-- INFORMACIÓ FINAL
-- =================================================================
-- ✅ Esquema actualitzat amb camps: de_baixa (boolean), data_baixa (date)
-- ✅ 34 exsocis inserits amb numero_soci 1-34
-- ✅ Camp de_baixa = TRUE per a tots els exsocis
-- ✅ Dates aproximades basades en historial de mitjanes
-- ✅ Índex creat per optimitzar consultes per estat de baixa
-- ✅ Verificacions incloses per assegurar la integritat
--
-- GESTIÓ FUTURA DE BAIXES:
-- 1. Donar de baixa un soci: UPDATE socis SET de_baixa = TRUE, data_baixa = CURRENT_DATE WHERE numero_soci = [ID]
-- 2. Reactivar un soci: UPDATE socis SET de_baixa = FALSE, data_baixa = NULL WHERE numero_soci = [ID]
-- 3. Consultar socis actius: SELECT * FROM socis WHERE de_baixa = FALSE OR de_baixa IS NULL
-- 4. Consultar exsocis: SELECT * FROM socis WHERE de_baixa = TRUE
-- =================================================================