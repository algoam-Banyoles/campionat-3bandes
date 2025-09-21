-- PASO 1: Crear taules temporals amb l'estructura correcta
-- Basat en: socis.csv, noms-soci.csv, Libro1.csv

-- 1. Taula per socis reals (des de socis.csv)
DROP TABLE IF EXISTS temp_socis;
CREATE TABLE temp_socis (
  numero_soci INTEGER,
  nom TEXT,
  cognoms TEXT,
  email TEXT
);

-- 2. Taula per mapping nom_jugador -> numero_soci (des de noms-soci.csv)
DROP TABLE IF EXISTS temp_nom_to_soci;
CREATE TABLE temp_nom_to_soci (
  nom_jugador TEXT,
  numero_soci_text TEXT  -- pot ser un numero o "Nosoci"
);

-- 3. Taula per mitjanes històriques (des de Libro1.csv)
DROP TABLE IF EXISTS temp_mitjanes_historiques;
CREATE TABLE temp_mitjanes_historiques (
  year INTEGER,
  modalitat VARCHAR(20),
  posicio INTEGER,
  nom_jugador TEXT,
  mitjana DECIMAL(5,3)
);

SELECT 'Taules temporals creades correctament!' as resultat;