-- PASO 6: VERIFICACIONS FINALS
-- Executa aquestes consultes després de la càrrega per verificar

-- Estadístiques generals
SELECT 'ESTADÍSTIQUES GENERALS:' as info;
SELECT 
  COUNT(*) as total_mitjanes,
  COUNT(soci_id) as mitjanes_assignades,
  COUNT(*) - COUNT(soci_id) as mitjanes_sense_assignar,
  MIN(year) as primer_any,
  MAX(year) as darrer_any
FROM mitjanes_historiques;

-- Per modalitat i any
SELECT 'PER MODALITAT I ANY:' as info;
SELECT year, modalitat, COUNT(*) as total
FROM mitjanes_historiques 
GROUP BY year, modalitat 
ORDER BY year DESC, modalitat;

-- Top 10 jugadors amb més mitjanes
SELECT 'TOP JUGADORS AMB MÉS MITJANES:' as info;
SELECT 
  s.nom, 
  s.cognoms, 
  COUNT(*) as mitjanes_totals,
  MIN(mh.year) as primer_any,
  MAX(mh.year) as darrer_any,
  ROUND(AVG(mh.mitjana), 3) as mitjana_global
FROM mitjanes_historiques mh
JOIN socis s ON mh.soci_id = s.numero_soci
GROUP BY s.numero_soci, s.nom, s.cognoms
ORDER BY mitjanes_totals DESC
LIMIT 10;

-- Mitjanes sense assignar (si n'hi ha)
SELECT 'MITJANES SENSE ASSIGNAR:' as info;
SELECT year, modalitat, mitjana
FROM mitjanes_historiques 
WHERE soci_id IS NULL
ORDER BY year DESC, mitjana DESC
LIMIT 20;