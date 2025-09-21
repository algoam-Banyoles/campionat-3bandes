-- PASO 5: CÀRREGA DESTRUCTIVA
-- ATENCIÓ: Això eliminarà totes les dades de mitjanes_historiques!
-- Assegura't d'haver fet el backup primer!

BEGIN;

-- Eliminar totes les dades actuals
TRUNCATE TABLE mitjanes_historiques;

-- Inserir les noves dades amb mapping
INSERT INTO mitjanes_historiques (soci_id, year, modalitat, mitjana, created_at)
SELECT 
  COALESCE(t.numero_soci, NULL) AS soci_id,
  m.year,
  m.modalitat,
  m.mitjana,
  NOW()
FROM temp_new_mitjanes m
LEFT JOIN temp_nom_to_soci t ON UPPER(m.nom_jugador) LIKE '%' || UPPER(t.nom_original) || '%';

-- Mostrar resum de la càrrega
SELECT 'CÀRREGA COMPLETADA:' as info;
SELECT 
  COUNT(*) as total_insertades,
  COUNT(soci_id) as amb_soci_assignat,
  COUNT(*) - COUNT(soci_id) as sense_soci
FROM mitjanes_historiques;

-- Si tot està bé, fes COMMIT. Si no, fes ROLLBACK!
COMMIT;

-- Per fer rollback si alguna cosa va malament:
-- ROLLBACK;