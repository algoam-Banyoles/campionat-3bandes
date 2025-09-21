-- Assignació de mitjanes històriques per J.F. SANTOS
-- Soci número: 7602

-- Nota: Com que estàs identificant manualment les mitjanes de J.F. SANTOS
-- des del formulari d'administració, aquest SQL serveix per fer l'assignació
-- directa si tens els IDs específics de les mitjanes a assignar.

-- OPCIÓ A: Si vols assignar mitjanes específiques per ID
-- (substitueix els IDs pels que trobis al formulari)
-- UPDATE mitjanes_historiques 
-- SET soci_id = 7602
-- WHERE id IN (123, 456, 789); -- Substitueix pels IDs reals

-- OPCIÓ B: Assignació genèrica per si hi ha mitjanes sense assignar
-- que pertanyen a J.F. SANTOS (7602)
-- UPDATE mitjanes_historiques 
-- SET soci_id = 7602
-- WHERE soci_id IS NULL 
--   AND id IN (
--     -- Llista aquí els IDs específics que has identificat com de J.F. SANTOS
--   );

-- Verificar mitjanes assignades a J.F. SANTOS (7602)
SELECT 
  mh.id, 
  mh.soci_id, 
  mh.year, 
  mh.modalitat, 
  mh.mitjana,
  s.nom,
  s.cognoms
FROM mitjanes_historiques mh
LEFT JOIN socis s ON mh.soci_id = s.numero_soci
WHERE mh.soci_id = 7602
ORDER BY mh.year DESC, mh.modalitat;

-- També pots verificar si hi ha mitjanes no assignades que podrien ser de J.F. SANTOS
SELECT 
  mh.id, 
  mh.year, 
  mh.modalitat, 
  mh.mitjana
FROM mitjanes_historiques mh
WHERE mh.soci_id IS NULL 
ORDER BY mh.year DESC, mh.mitjana DESC;