-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR JAUME CIVIL DELCOR (8073)
-- ================================================================
-- El jugador Jaume Civil Delcor (exsoci 8073) té registres històrics 
-- des de 2017 però no existeix a la taula socis
-- 
-- És un exsoci que va jugar:
-- • BANDA: 2017
-- • LLIURE: 2017
-- ================================================================

BEGIN;

-- Afegir Jaume Civil Delcor com a exsoci
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (8073, 'Jaume', 'Civil Delcor', NULL, TRUE, '2017-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'Jaume Civil Delcor (exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 8073;

COMMIT;