-- Consulta simple per veure els jugadors existents
SELECT numero_soci, nom, email, mitjana, estat, club
FROM players
ORDER BY numero_soci;