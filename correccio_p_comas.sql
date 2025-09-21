-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR P. COMAS (EXSOCI 0037)
-- ================================================================
-- Els jugadors J. COMAS (soci 6110) i P. COMAS comparteixen soci_id
-- El pitjor promitjig s'assigna a P. COMAS (exsoci 0037)
-- - LLIURE 2008: 1.440 (pitjor vs 1.650)
-- ================================================================

BEGIN;

-- Afegir P. COMAS com a exsoci 0037
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (37, 'P.', 'COMAS', NULL, TRUE, '2008-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

COMMIT;