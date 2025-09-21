-- PASO 3: PREVISUALITZACIONS amb estructura correcta
-- Basat en socis.csv, noms-soci.csv i Libro1.csv

-- 3A) Verificar càrrega de fitxers
SELECT 'RESUM CÀRREGA FITXERS:' as info;
SELECT COUNT(*) as socis_carregats FROM temp_socis;
SELECT COUNT(*) as mappings_carregats FROM temp_nom_to_soci;
SELECT COUNT(*) as mitjanes_carregades FROM temp_mitjanes_historiques;

-- 3B) Mostrar diferents tipus de mapping
SELECT 'TIPUS DE MAPPING:' as info;
SELECT 
  numero_soci_text,
  COUNT(*) as quantitat
FROM temp_nom_to_soci 
GROUP BY numero_soci_text 
ORDER BY COUNT(*) DESC
LIMIT 10;

-- 3C) Jugadors que SÓN socis (tenen número de soci vàlid)
SELECT 'JUGADORS QUE SÓN SOCIS:' as info;
SELECT 
  mh.nom_jugador,
  nts.numero_soci_text,
  s.nom as nom_soci,
  s.cognoms,
  COUNT(*) as mitjanes_disponibles
FROM temp_mitjanes_historiques mh
JOIN temp_nom_to_soci nts ON mh.nom_jugador = nts.nom_jugador
JOIN temp_socis s ON s.numero_soci::text = nts.numero_soci_text
WHERE nts.numero_soci_text != 'Nosoci'
GROUP BY mh.nom_jugador, nts.numero_soci_text, s.nom, s.cognoms
ORDER BY mitjanes_disponibles DESC
LIMIT 20;

-- 3D) Jugadors que NO són socis
SELECT 'JUGADORS QUE NO SÓN SOCIS:' as info;
SELECT 
  mh.nom_jugador,
  COUNT(*) as mitjanes_disponibles
FROM temp_mitjanes_historiques mh
JOIN temp_nom_to_soci nts ON mh.nom_jugador = nts.nom_jugador
WHERE nts.numero_soci_text = 'Nosoci'
GROUP BY mh.nom_jugador
ORDER BY mitjanes_disponibles DESC
LIMIT 20;

-- 3E) Estadístiques generals
SELECT 'ESTADÍSTIQUES GENERALS:' as info;
SELECT 
  COUNT(DISTINCT mh.nom_jugador) as jugadors_totals,
  COUNT(DISTINCT CASE WHEN nts.numero_soci_text != 'Nosoci' THEN mh.nom_jugador END) as jugadors_socis,
  COUNT(DISTINCT CASE WHEN nts.numero_soci_text = 'Nosoci' THEN mh.nom_jugador END) as jugadors_no_socis,
  COUNT(*) as total_mitjanes
FROM temp_mitjanes_historiques mh
JOIN temp_nom_to_soci nts ON mh.nom_jugador = nts.nom_jugador;

-- 3F) Mostra de dades finals que s'insertaran
SELECT 'MOSTRA DADES FINALS (NOMÉS SOCIS):' as info;
SELECT 
  mh.year,
  mh.modalitat,
  mh.nom_jugador,
  nts.numero_soci_text::integer as soci_id,
  s.nom as nom_soci,
  s.cognoms,
  mh.mitjana
FROM temp_mitjanes_historiques mh
JOIN temp_nom_to_soci nts ON mh.nom_jugador = nts.nom_jugador
JOIN temp_socis s ON s.numero_soci::text = nts.numero_soci_text
WHERE nts.numero_soci_text != 'Nosoci'
ORDER BY mh.year DESC, mh.modalitat, mh.posicio
LIMIT 30;