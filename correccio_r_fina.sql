-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR R. FINA (EXSOCI 0036)
-- ================================================================
-- El jugador R. FINA té duplicats amb X. FINA (soci 407) el 2005
-- Els pitjors promitjos s'assignen a R. FINA (exsoci 0036)
-- - 3 BANDES 2005: 0.082 (pitjor vs 0.319)
-- - BANDA 2005: 0.510 (pitjor vs 0.960)
-- ================================================================

BEGIN;

-- Afegir R. FINA com a exsoci 0036
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (36, 'R.', 'FINA', NULL, TRUE, '2005-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

COMMIT;