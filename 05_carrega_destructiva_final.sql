-- PASO 5: CÀRREGA DESTRUCTIVA amb gestió de duplicats
-- IMPORTANT: S'executarà dins d'una transacció per poder fer ROLLBACK si cal

BEGIN;

-- Esborrar totes les mitjanes històriques existents
DELETE FROM mitjanes_historiques;

-- Inserir NOMÉS les MILLORS mitjanes dels jugadors que SÓN socis
-- (en cas de duplicats per soci+any+modalitat, es pren la mitjana més alta)
INSERT INTO mitjanes_historiques (soci_id, year, modalitat, mitjana, created_at)
SELECT 
  soci_id,
  year,
  modalitat,
  MAX(mitjana) as millor_mitjana,  -- Prendre la millor mitjana
  NOW() as created_at
FROM (
  SELECT 
    nts.numero_soci_text::integer as soci_id,
    mh.year,
    mh.modalitat,
    mh.mitjana
  FROM temp_mitjanes_historiques mh
  JOIN temp_nom_to_soci nts ON mh.nom_jugador = nts.nom_jugador
  WHERE nts.numero_soci_text != 'Nosoci'
    AND nts.numero_soci_text ~ '^[0-9]+$' -- Només números vàlids
) dades_socis
GROUP BY soci_id, year, modalitat;

-- Mostrar estadístiques de la càrrega
SELECT 'ESTADÍSTIQUES CÀRREGA:' as info;
SELECT COUNT(*) as mitjanes_inserides FROM mitjanes_historiques;

SELECT 'TOP 10 SOCIS AMB MÉS MITJANES:' as info;
SELECT 
  mh.soci_id,
  s.nom,
  s.cognoms,
  COUNT(*) as mitjanes_totals
FROM mitjanes_historiques mh
JOIN socis s ON s.numero_soci = mh.soci_id
GROUP BY mh.soci_id, s.nom, s.cognoms
ORDER BY mitjanes_totals DESC
LIMIT 10;

-- CHECKPOINT: Revisar abans de fer COMMIT
SELECT 'REVISAR AQUESTES DADES ABANS DE FER COMMIT:' as info;
SELECT 
  COUNT(*) as total_mitjanes,
  COUNT(DISTINCT soci_id) as socis_diferents,
  MIN(year) as any_minim,
  MAX(year) as any_maxim,
  ROUND(AVG(mitjana), 3) as mitjana_global
FROM mitjanes_historiques;

-- Mostrar alguns exemples de la càrrega
SELECT 'EXEMPLES DE MITJANES CARREGADES:' as info;
SELECT 
  mh.soci_id,
  s.nom,
  s.cognoms,
  mh.year,
  mh.modalitat,
  mh.mitjana
FROM mitjanes_historiques mh
JOIN socis s ON s.numero_soci = mh.soci_id
ORDER BY mh.year DESC, mh.mitjana DESC
LIMIT 15;

-- DESCOMENTA LA LÍNIA SEGÜENT PER FER COMMIT DEFINITIU:
-- COMMIT;

-- MANTENIR UNCOMMENTAT PER PODER REVISAR:
SELECT 'TRANSACCIÓ EN CURS - Fes COMMIT; per confirmar o ROLLBACK; per desfer' as avisos;