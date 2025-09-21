-- PASO 3: PREVISUALITZACIONS
-- Executa aquestes consultes per revisar abans de la càrrega final

-- 3A) Comptar files que farien match per cada mapping
SELECT 'MATCHING PER JUGADOR:' as info;
SELECT t.numero_soci, t.nom_original, count(*) AS files_coincidents
FROM temp_nom_to_soci t
JOIN temp_new_mitjanes m ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%'
GROUP BY t.numero_soci, t.nom_original
ORDER BY files_coincidents DESC;

-- 3B) Noms de jugadors sense assignar (per detectar mappings pendents)
SELECT 'JUGADORS SENSE ASSIGNAR:' as info;
SELECT m.nom_jugador, count(*) as vegades_apareix
FROM temp_new_mitjanes m
LEFT JOIN temp_nom_to_soci t ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%'
WHERE t.numero_soci IS NULL
GROUP BY m.nom_jugador
ORDER BY vegades_apareix DESC
LIMIT 50;

-- 3C) Mostra de files finals que s'insertaran
SELECT 'MOSTRA DE DADES FINALS:' as info;
SELECT m.year, m.modalitat, m.nom_jugador,
  COALESCE(t.numero_soci, NULL) AS soci_assignat,
  m.mitjana
FROM temp_new_mitjanes m
LEFT JOIN temp_nom_to_soci t ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%'
ORDER BY m.year DESC, m.modalitat, m.posicio
LIMIT 30;

-- 3D) Resum estadístic
SELECT 'RESUM ESTADÍSTIC:' as info;
SELECT 
  COUNT(*) as total_mitjanes_csv,
  COUNT(t.numero_soci) as mitjanes_amb_soci,
  COUNT(*) - COUNT(t.numero_soci) as mitjanes_sense_soci,
  ROUND(COUNT(t.numero_soci) * 100.0 / COUNT(*), 2) as percentatge_assignat
FROM temp_new_mitjanes m
LEFT JOIN temp_nom_to_soci t ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%';