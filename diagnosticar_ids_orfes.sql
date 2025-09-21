-- Script de diagnòstic per identificar soci_id orfes
-- Troba tots els IDs de mitjanes històriques que no existeixen a la taula socis

-- IDs que apareixen a mitjanes històriques però no a socis
SELECT DISTINCT mh.soci_id
FROM mitjanes_historiques mh
LEFT JOIN socis s ON mh.soci_id = s.numero_soci
WHERE s.numero_soci IS NULL
ORDER BY mh.soci_id;

-- Comptar quants IDs orfes hi ha
SELECT COUNT(DISTINCT mh.soci_id) as ids_orfes
FROM mitjanes_historiques mh
LEFT JOIN socis s ON mh.soci_id = s.numero_soci
WHERE s.numero_soci IS NULL;

-- Mostrar rang d'IDs orfes
SELECT 
    MIN(mh.soci_id) as id_minim_orfe,
    MAX(mh.soci_id) as id_maxim_orfe
FROM mitjanes_historiques mh
LEFT JOIN socis s ON mh.soci_id = s.numero_soci
WHERE s.numero_soci IS NULL;