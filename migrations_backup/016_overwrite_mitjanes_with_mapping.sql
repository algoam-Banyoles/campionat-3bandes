-- Migració 016: Càrrega completa de mitjanes històriques des del CSV Ranquing
-- ADVERTÈNCIA: aquesta migració farà TRUNCATE de la taula i INSERT de moltes files.
-- Llegeix amb cura, executa els SELECT de previsualització i només descomenta
-- la part destructiva quan estiguis preparat i tinguis una còpia de seguretat.

-- 1) Crear taula temporal de mapping nom_jugador -> numero_soci
DROP TABLE IF EXISTS temp_nom_to_soci;
CREATE TEMP TABLE temp_nom_to_soci (
  nom_original TEXT,
  numero_soci INTEGER
);

-- 2) Omplir la taula de mapping amb totes les correspondències jugador->soci.
-- Example entries (replace/extend with the full mapping you provided):
INSERT INTO temp_nom_to_soci (nom_original, numero_soci) VALUES
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

-- 3) Crear taula temporal per les noves files de mitjanes del CSV.
DROP TABLE IF EXISTS temp_new_mitjanes;
CREATE TEMP TABLE temp_new_mitjanes (
  year INTEGER,
  modalitat VARCHAR(20),
  posicio INTEGER,
  nom_jugador TEXT,
  mitjana DECIMAL(5,3)
);

-- 4) Carregar les files del CSV a temp_new_mitjanes.
-- EXECUTA AQUEST COMANDAMENT AL TERMINAL (PowerShell):
-- psql "$env:SUPABASE_DB_URL" -c "\copy temp_new_mitjanes(year, modalitat, posicio, nom_jugador, mitjana) FROM 'dades/Ranquing (1) (1).csv' WITH (FORMAT csv, DELIMITER ';', HEADER true)"

-- 5) PREVISUALITZACIÓ: Comptar files que farien match per cada mapping.
SELECT t.numero_soci, t.nom_original, count(*) AS files_coincidents
FROM temp_nom_to_soci t
JOIN temp_new_mitjanes m ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%'
GROUP BY t.numero_soci, t.nom_original
ORDER BY files_coincidents DESC;

-- 6) PREVISUALITZACIÓ: Noms de jugadors sense assignar (per detectar mappings pendents)
SELECT m.nom_jugador, count(*) as vegades_apareix
FROM temp_new_mitjanes m
LEFT JOIN temp_nom_to_soci t ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%'
WHERE t.numero_soci IS NULL
GROUP BY m.nom_jugador
ORDER BY vegades_apareix DESC
LIMIT 200;

-- 7) PREVISUALITZACIÓ: Files finals que s'insertaran a mitjanes_historiques.
SELECT m.year, m.modalitat, m.nom_jugador,
  COALESCE(t.numero_soci, NULL) AS soci_assignat,
  m.mitjana
FROM temp_new_mitjanes m
LEFT JOIN temp_nom_to_soci t ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%'
ORDER BY m.year DESC, m.modalitat, m.posicio
LIMIT 200;

-- 8) OPERACIÓ DESTRUCTIVA: TRUNCATE + INSERT.
-- Aquest bloc està comentat. Revisa les previsualitzacions anteriors, 
-- fes una còpia de seguretat de la BD, i després descomenta per executar.

-- BEGIN;
-- TRUNCATE TABLE mitjanes_historiques;
-- INSERT INTO mitjanes_historiques (soci_id, year, modalitat, mitjana, created_at)
-- SELECT COALESCE(t.numero_soci, NULL) AS soci_id,
--        m.year,
--        m.modalitat,
--        m.mitjana,
--        NOW()
-- FROM temp_new_mitjanes m
-- LEFT JOIN temp_nom_to_soci t ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%';
-- COMMIT;

-- NOTES IMPORTANTS:
-- - El matching usa LIKE case-insensitive; per millors resultats considera
--   normalitzar accents amb unaccent() o afegir variants del mapping.
-- - Si alguns jugadors han de quedar sense soci_id, manté COALESCE(..., NULL).
-- - Fes sempre una còpia de seguretat abans d'executar el bloc destructiu.
