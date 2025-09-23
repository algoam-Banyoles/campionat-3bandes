-- Consulta per trobar socis que podrien correspondre als noms Excel restants
SELECT numero_soci, nom, cognom, email
FROM socis
WHERE
   -- Buscar possibles coincidències pels noms que falten
   UPPER(nom || ' ' || COALESCE(cognom, '')) LIKE '%ROYES%' OR
   UPPER(nom || ' ' || COALESCE(cognom, '')) LIKE '%MUÑOZ%' OR
   UPPER(nom || ' ' || COALESCE(cognom, '')) LIKE '%GONZÁLEZ%' OR
   UPPER(nom || ' ' || COALESCE(cognom, '')) LIKE '%CORBALÁN%' OR
   UPPER(nom || ' ' || COALESCE(cognom, '')) LIKE '%FERNÁNDEZ%'
ORDER BY numero_soci;