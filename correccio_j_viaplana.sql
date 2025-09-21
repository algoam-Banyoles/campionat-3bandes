-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR J. VIAPLANA (EXSOCI 0038)
-- ================================================================
-- El jugador J.M. VIAPLANA (soci 7586) té duplicats el 2013 i 2014
-- Els pitjors promitjos s'assignen a J. VIAPLANA (exsoci 0038)
-- - 2013: 3B=0.131, BANDA=0.449, LLIURE=0.497
-- - 2014: 3B=0.134, BANDA=0.432, LLIURE=0.692
-- ================================================================

BEGIN;

-- Afegir J. VIAPLANA com a exsoci 0038
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (38, 'J.', 'VIAPLANA', NULL, TRUE, '2014-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

COMMIT;