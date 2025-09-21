-- ASSIGNACIONS MASSIVES DE MITJANES HISTÒRIQUES
-- Data: 2025-09-20
-- 
-- Aquest SQL assigna mitjanes històriques a socis basant-se en patrons de noms
-- identificats manualment des de les dades originals.

-- ====================================================================================
-- ASSIGNACIONS DEFINIDES:
-- ====================================================================================
-- J.F. SANTOS → 7602
-- J.M. Campos (o Campos) → 8707  
-- Roseró (amb/sense accent, amb J., J, J.L., etc) → 8664
-- J. Rodríguez (darrers 2 anys mínim) → 8133
-- Fitó (amb/sense accent) → 7196
-- M. López = Mallach → 8482
-- E. Garcia (amb/sense accent) → 8715
-- Saucedo → 8296
-- S. Marín → 1381
-- J. Ibáñez → 8115
-- J.M. Casamor → 8408

-- ====================================================================================
-- NOTA IMPORTANT: Aquest SQL està preparat per quan les mitjanes no assignades 
-- estiguin carregades a la base de dades amb una columna que contingui els noms.
-- 
-- SUBSTITUEIX 'nom_jugador' per la columna real que contingui els noms:
-- - nom_jugador
-- - nom_complet  
-- - player_name
-- - nom (si és així)
-- - etc.
-- ====================================================================================

-- Estadístiques ABANS de les assignacions
SELECT 'ABANS DE LES ASSIGNACIONS' as fase;
SELECT 
    COUNT(*) as total_mitjanes,
    COUNT(soci_id) as assignades,
    COUNT(*) - COUNT(soci_id) as no_assignades
FROM mitjanes_historiques;

-- ====================================================================================
-- ASSIGNACIONS PER PATRÓ DE NOM
-- ====================================================================================
-- ====================================================================================
-- MÈTODE GENERAL AMB TAULA TEMPORAL DE MAPPING
-- ====================================================================================
-- Aquest bloc crea una taula temporal amb el mapping (nom -> numero_soci)
-- i mostra com fer un UPDATE segur. Substitueix `nom_jugador` per la
-- columna real que contingui el nom a `mitjanes_historiques` si cal.
--
-- PASOS RECOMANATS:
-- 1) Revisa el contingut de la taula temporal amb el SELECT de demo.
-- 2) Executa el SELECT de pre-visualització (no fa canvis) per veure
--    quantes files farien MATCH per cada soci.
-- 3) Si és correcte, fes l'UPDATE dins d'una transacció o fent un
--    BACKUP de la taula `mitjanes_historiques` abans.

-- (A) Creem una taula temporal amb el mapping. Posa aquí totes les línies
-- del mapping "Jugador, numero_soci" que m'has enviat. Exemple:
-- ('A. BERMEJO', 8542), ('A. BOIX', 8077), ...
DROP TABLE IF EXISTS temp_nom_to_soci;
CREATE TEMP TABLE temp_nom_to_soci (
  nom_original text,
  numero_soci integer
);

INSERT INTO temp_nom_to_soci (nom_original, numero_soci) VALUES
    -- <-- PASTE YOUR MAPPING LINES HERE (see instructions below)
    ('A. BERMEJO', 8542),
    ('A. BOIX', 8077),
    ('A. FUENTES', 8693),
    ('A. GARCÍA', 8716),
    ('A. GÓMEZ', 8648),
    ('A. MEDINA', 8556),
    ('A. MELGAREJO', 8464),
    ('A. MORA', 8438),
    ('J. FITÓ', 7196),
    ('J.A. SAUCEDO', 8296),
    ('J.F. SANTOS', 7602),
    ('J.L. ROSERÓ', 8664),
    ('J.M. CAMPOS', 8707),
    ('J.M. CASAMOR', 8408),
    ('J.M. MUNTANÉ', 8137),
    ('J.M. RODRÍGUEZ', 6811),
    ('J.M. VIAPLANA', 7586),
    ('J. ORTIZ', 6855),
    ('J. RODRÍGUEZ', 8133),
    ('J. SELGA', 6203),
    ('J. VALLÉS', 6512),
    ('J. VEZA', 8523),
    ('J. VILA', 8690),
    ('L. CHUECOS', 8683),
    ('M. QUEROL', 3463),
    ('M. SÁNCHEZ', 7967),
    ('M.L. MALLACH', 8482),
    ('P. ÁLVAREZ', 8485),
    ('P. CASANOVA', 7618),
    ('P. COMAS', 6110),
    ('P. FERRÀS', 7541),
    ('R. JARQUE', 7308),
    ('R. MERCADER', 8431),
    ('R. MORENO', 8436),
    ('R. CERVANTES', 7938),
    ('R. FINA', 407),
    ('S. MARÍN', 1381),
    ('V. INOCENTES', 5818),
    ('X. FINA', 407)
    ;

-- (B) Pre-visualització: quantes entrades farien MATCH si fem un LIKE
-- IMPORTANT: aquest SELECT no actualitza dades, només mostra counts.
SELECT t.numero_soci, t.nom_original, COUNT(mh.*) as matches
FROM temp_nom_to_soci t
LEFT JOIN mitjanes_historiques mh
  ON mh.soci_id IS NULL
  AND UPPER(mh.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%'
GROUP BY t.numero_soci, t.nom_original
ORDER BY matches DESC;

-- (C) Llista detallada de files que farien MATCH (exemple limitat a 200)
SELECT mh.id, mh.year, mh.modalitat, mh.mitjana, mh.nom_jugador, t.numero_soci
FROM temp_nom_to_soci t
JOIN mitjanes_historiques mh
  ON mh.soci_id IS NULL
  AND UPPER(mh.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%'
ORDER BY t.numero_soci, mh.year DESC
LIMIT 200;

-- (D) UPDATE segur (descomenta per executar). Recomendat fer en TRANSACTIO
-- BEGIN;
-- UPDATE mitjanes_historiques mh
-- SET soci_id = t.numero_soci
-- FROM temp_nom_to_soci t
-- WHERE mh.soci_id IS NULL
--   AND UPPER(mh.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%';
-- COMMIT;

-- NOTES FINALS:
-- - Si la columna amb els noms no es diu `nom_jugador`, substitueix
--   `mh.nom_jugador` per el nom correcte a les consultes anteriors.
-- - Si tens noms amb variants (accentuacions, inicials amb/o sense punts),
--   afegeix entrades addicionals a `temp_nom_to_soci` per cobrir-los.
-- - Posa la llista completa que m'has proporcionat dins de VALUES si vols
--   que el script inclogui tothom automàticament.

-- J.F. SANTOS → 7602
UPDATE mitjanes_historiques 
SET soci_id = 7602
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%J.F.%SANTOS%' OR
    UPPER(nom_jugador) LIKE '%JF%SANTOS%' OR
    UPPER(nom_jugador) LIKE '%J. F.%SANTOS%' OR
    UPPER(nom_jugador) LIKE '%SANTOS%J.F.%' OR
    UPPER(nom_jugador) LIKE '%SANTOS%JF%'
  );

-- J.M. Campos → 8707
UPDATE mitjanes_historiques 
SET soci_id = 8707
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%CAMPOS%' OR
    UPPER(nom_jugador) LIKE '%J.M.%CAMPOS%' OR
    UPPER(nom_jugador) LIKE '%JM%CAMPOS%'
  );

-- Roseró → 8664
UPDATE mitjanes_historiques 
SET soci_id = 8664
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%ROSERO%' OR
    UPPER(nom_jugador) LIKE '%ROSERÓ%' OR
    UPPER(nom_jugador) LIKE '%J.%ROSERO%' OR
    UPPER(nom_jugador) LIKE '%J.%ROSERÓ%' OR
    UPPER(nom_jugador) LIKE '%J.L.%ROSERO%' OR
    UPPER(nom_jugador) LIKE '%J.L.%ROSERÓ%' OR
    UPPER(nom_jugador) LIKE '%JL%ROSERO%' OR
    UPPER(nom_jugador) LIKE '%JL%ROSERÓ%'
  );

-- J. Rodríguez (darrers 2 anys) → 8133
UPDATE mitjanes_historiques 
SET soci_id = 8133
WHERE soci_id IS NULL 
  AND year >= 2023  -- Darrers 2 anys (2023-2025)
  AND (
    UPPER(nom_jugador) LIKE '%J.%RODRIGUEZ%' OR
    UPPER(nom_jugador) LIKE '%J.%RODRÍGUEZ%' OR
    UPPER(nom_jugador) LIKE '%RODRIGUEZ%J.%' OR
    UPPER(nom_jugador) LIKE '%RODRÍGUEZ%J.%'
  );

-- Fitó → 7196
UPDATE mitjanes_historiques 
SET soci_id = 7196
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%FITO%' OR
    UPPER(nom_jugador) LIKE '%FITÓ%'
  );

-- M. López = Mallach → 8482
UPDATE mitjanes_historiques 
SET soci_id = 8482
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%M.%LOPEZ%' OR
    UPPER(nom_jugador) LIKE '%M.%LÓPEZ%' OR
    UPPER(nom_jugador) LIKE '%MALLACH%' OR
    UPPER(nom_jugador) LIKE '%LOPEZ%M.%' OR
    UPPER(nom_jugador) LIKE '%LÓPEZ%M.%'
  );

-- E. Garcia → 8715
UPDATE mitjanes_historiques 
SET soci_id = 8715
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%E.%GARCIA%' OR
    UPPER(nom_jugador) LIKE '%E.%GARCÍA%' OR
    UPPER(nom_jugador) LIKE '%GARCIA%E.%' OR
    UPPER(nom_jugador) LIKE '%GARCÍA%E.%'
  );

-- Saucedo → 8296
UPDATE mitjanes_historiques 
SET soci_id = 8296
WHERE soci_id IS NULL 
  AND UPPER(nom_jugador) LIKE '%SAUCEDO%';

-- S. Marín → 1381
UPDATE mitjanes_historiques 
SET soci_id = 1381
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%S.%MARIN%' OR
    UPPER(nom_jugador) LIKE '%S.%MARÍN%' OR
    UPPER(nom_jugador) LIKE '%MARIN%S.%' OR
    UPPER(nom_jugador) LIKE '%MARÍN%S.%'
  );

-- J. Ibáñez → 8115
UPDATE mitjanes_historiques 
SET soci_id = 8115
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%J.%IBANEZ%' OR
    UPPER(nom_jugador) LIKE '%J.%IBÁÑEZ%' OR
    UPPER(nom_jugador) LIKE '%J.%IBAÑEZ%' OR
    UPPER(nom_jugador) LIKE '%IBANEZ%J.%' OR
    UPPER(nom_jugador) LIKE '%IBÁÑEZ%J.%' OR
    UPPER(nom_jugador) LIKE '%IBAÑEZ%J.%'
  );

-- J.M. Casamor → 8408
UPDATE mitjanes_historiques 
SET soci_id = 8408
WHERE soci_id IS NULL 
  AND (
    UPPER(nom_jugador) LIKE '%J.M.%CASAMOR%' OR
    UPPER(nom_jugador) LIKE '%JM%CASAMOR%' OR
    UPPER(nom_jugador) LIKE '%CASAMOR%J.M.%' OR
    UPPER(nom_jugador) LIKE '%CASAMOR%JM%'
  );

-- ====================================================================================
-- VERIFICACIONS I ESTADÍSTIQUES
-- ====================================================================================

-- Estadístiques DESPRÉS de les assignacions
SELECT 'DESPRÉS DE LES ASSIGNACIONS' as fase;
SELECT 
    COUNT(*) as total_mitjanes,
    COUNT(soci_id) as assignades,
    COUNT(*) - COUNT(soci_id) as no_assignades
FROM mitjanes_historiques;

-- Resum per soci assignat
SELECT 'RESUM PER SOCI ASSIGNAT' as info;
SELECT 
    mh.soci_id,
    s.nom,
    s.cognoms,
    COUNT(*) as mitjanes_assignades,
    MIN(mh.year) as primer_any,
    MAX(mh.year) as darrer_any,
    ROUND(AVG(mh.mitjana), 3) as mitjana_global
FROM mitjanes_historiques mh
JOIN socis s ON mh.soci_id = s.numero_soci
WHERE mh.soci_id IN (7602, 8707, 8664, 8133, 7196, 8482, 8715, 8296, 1381, 8115, 8408)
GROUP BY mh.soci_id, s.nom, s.cognoms
ORDER BY mitjanes_assignades DESC;

-- Llistar mitjanes que encara no s'han assignat
SELECT 'MITJANES ENCARA SENSE ASSIGNAR' as info;
SELECT 
    id,
    year,
    modalitat,
    mitjana
    -- Afegir aquí la columna del nom quan estigui disponible:
    -- , nom_jugador  -- o el nom real de la columna
FROM mitjanes_historiques 
WHERE soci_id IS NULL
ORDER BY year DESC, mitjana DESC
LIMIT 50;  -- Limitem a 50 per no sobrecarregar l'output