-- PASO 1: Crear taules temporals i mapping
-- Executa aquest primer per preparar les estructures

-- Crear taula temporal de mapping nom_jugador -> numero_soci
DROP TABLE IF EXISTS temp_nom_to_soci;
CREATE TEMP TABLE temp_nom_to_soci (
  nom_original TEXT,
  numero_soci INTEGER
);

-- Omplir la taula de mapping amb totes les correspondències jugador->soci
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
  ('X. FINA', 407);

-- Crear taula temporal per les noves files de mitjanes del CSV
DROP TABLE IF EXISTS temp_new_mitjanes;
CREATE TEMP TABLE temp_new_mitjanes (
  year INTEGER,
  modalitat VARCHAR(20),
  posicio INTEGER,
  nom_jugador TEXT,
  mitjana DECIMAL(5,3)
);

SELECT 'Taules temporals creades correctament!' as resultat;