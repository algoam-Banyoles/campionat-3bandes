-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR ENRIC LAHOZ TRONI (8183)
-- ================================================================
-- El jugador Enric Lahoz Troni (exsoci 8183) té registres històrics 
-- però no existeix a la taula socis
-- 
-- És un exsoci que necessita ser afegit per resoldre les claus foranes
-- ================================================================

BEGIN;

-- Afegir Enric Lahoz Troni com a exsoci
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (8183, 'Enric', 'Lahoz Troni', NULL, TRUE, '2020-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'Enric Lahoz Troni (exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 8183;

COMMIT;