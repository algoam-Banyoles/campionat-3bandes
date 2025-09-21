-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR JAUME ARMENGOL CREUS (7044)
-- ================================================================
-- El jugador Jaume Armengol Creus (exsoci 7044) té registres històrics 
-- des de 2009-2014 però no existeix a la taula socis
-- 
-- És un exsoci actiu que va jugar:
-- • 3 BANDES: 2009, 2013, 2014 (3 anys)
-- • BANDA: 2014 (1 any)
-- • LLIURE: 2009, 2013, 2014 (3 anys)
-- Total: 7 registres històrics
-- ================================================================

BEGIN;

-- Afegir Jaume Armengol Creus com a exsoci
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (7044, 'Jaume', 'Armengol Creus', NULL, TRUE, '2014-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'Jaume Armengol Creus (exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 7044;

COMMIT;