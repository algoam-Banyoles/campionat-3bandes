-- PASO 6: VERIFICACIONS FINALS
-- Comprovar que la càrrega ha anat correctament

-- Estadístiques generals
SELECT 'ESTADÍSTIQUES GENERALS:' as info;
SELECT 
  COUNT(*) as total_mitjanes,
  COUNT(DISTINCT soci_id) as socis_amb_mitjanes,
  MIN(year) as any_mes_antic,
  MAX(year) as any_mes_recent,
  ROUND(AVG(mitjana), 3) as mitjana_global,
  ROUND(MIN(mitjana), 3) as mitjana_minima,
  ROUND(MAX(mitjana), 3) as mitjana_maxima
FROM mitjanes_historiques;

-- Top 10 socis amb més mitjanes històriques
SELECT 'TOP 10 SOCIS AMB MÉS MITJANES:' as info;
SELECT 
  mh.soci_id,
  s.nom,
  s.cognoms,
  COUNT(*) as mitjanes_totals,
  ROUND(AVG(mh.mitjana), 3) as mitjana_promig,
  MIN(mh.year) as primer_any,
  MAX(mh.year) as ultim_any
FROM mitjanes_historiques mh
JOIN socis s ON s.numero_soci = mh.soci_id
GROUP BY mh.soci_id, s.nom, s.cognoms
ORDER BY mitjanes_totals DESC
LIMIT 10;

-- Distribució per anys
SELECT 'DISTRIBUCIÓ PER ANYS:' as info;
SELECT 
  year,
  COUNT(*) as mitjanes_any,
  COUNT(DISTINCT soci_id) as socis_actius,
  ROUND(AVG(mitjana), 3) as mitjana_any
FROM mitjanes_historiques
GROUP BY year
ORDER BY year DESC;

-- Distribució per modalitat
SELECT 'DISTRIBUCIÓ PER MODALITAT:' as info;
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
  s.nom,
  s.cognoms,
  mh.modalitat,
  mh.mitjana
FROM mitjanes_historiques mh
JOIN socis s ON s.numero_soci = mh.soci_id
WHERE mh.year = 2025
ORDER BY mh.mitjana DESC
LIMIT 10;

-- Verificar integritat: socis amb mitjanes que existeixen a la taula socis
SELECT 'VERIFICACIÓ INTEGRITAT:' as info;
SELECT 
  (SELECT COUNT(DISTINCT soci_id) FROM mitjanes_historiques) as socis_amb_mitjanes,
  (SELECT COUNT(*) FROM socis WHERE numero_soci IN (SELECT DISTINCT soci_id FROM mitjanes_historiques)) as socis_valids,
  CASE 
    WHEN (SELECT COUNT(DISTINCT soci_id) FROM mitjanes_historiques) = 
         (SELECT COUNT(*) FROM socis WHERE numero_soci IN (SELECT DISTINCT soci_id FROM mitjanes_historiques))
    THEN 'CORRECTE: Tots els socis amb mitjanes existeixen a la taula socis'
    ELSE 'ERROR: Hi ha socis amb mitjanes que no existeixen a la taula socis'
  END as estat_integritat;