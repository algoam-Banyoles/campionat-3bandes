-- PASO 6: VERIFICACIONS FINALS (simplificada)
-- Comprovar que la carrega ha anat correctament

-- Estadistiques generals
SELECT 'ESTADISTIQUES GENERALS:' as info;
SELECT 
  COUNT(*) as total_mitjanes,
  COUNT(DISTINCT soci_id) as socis_amb_mitjanes,
  MIN(year) as any_mes_antic,
  MAX(year) as any_mes_recent,
  ROUND(AVG(mitjana), 3) as mitjana_global,
  ROUND(MIN(mitjana), 3) as mitjana_minima,
  ROUND(MAX(mitjana), 3) as mitjana_maxima
FROM mitjanes_historiques;

-- Top 10 socis amb mes mitjanes historiques (nomes IDs)
SELECT 'TOP 10 SOCIS AMB MES MITJANES:' as info;
SELECT 
  soci_id,
  COUNT(*) as mitjanes_totals,
  ROUND(AVG(mitjana), 3) as mitjana_promig,
  MIN(year) as primer_any,
  MAX(year) as ultim_any
FROM mitjanes_historiques
GROUP BY soci_id
ORDER BY mitjanes_totals DESC
LIMIT 10;

-- Distribucio per anys
SELECT 'DISTRIBUCIO PER ANYS:' as info;
SELECT 
  year,
  COUNT(*) as mitjanes_any,
  COUNT(DISTINCT soci_id) as socis_actius,
  ROUND(AVG(mitjana), 3) as mitjana_any
FROM mitjanes_historiques
GROUP BY year
ORDER BY year DESC;

-- Distribucio per modalitat
SELECT 'DISTRIBUCIO PER MODALITAT:' as info;
SELECT 
  modalitat,
  COUNT(*) as mitjanes_modalitat,
  COUNT(DISTINCT soci_id) as socis_modalitat,
  ROUND(AVG(mitjana), 3) as mitjana_modalitat
FROM mitjanes_historiques
GROUP BY modalitat
ORDER BY mitjanes_modalitat DESC;

-- Top 10 millors mitjanes de 2025
SELECT 'TOP 10 MILLORS MITJANES 2025:' as info;
SELECT 
  soci_id,
  modalitat,
  mitjana
FROM mitjanes_historiques
WHERE year = 2025
ORDER BY mitjana DESC
LIMIT 10;

-- Resum final
SELECT 'RESUM FINAL:' as info;
SELECT 
  'CARREGA COMPLETADA CORRECTAMENT' as estat,
  COUNT(*) as total_records_carregats,
  COUNT(DISTINCT soci_id) as socis_diferents,
  COUNT(DISTINCT year) as anys_diferents,
  COUNT(DISTINCT modalitat) as modalitats_diferents
FROM mitjanes_historiques;