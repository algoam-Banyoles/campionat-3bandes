-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR L. GONZÁLEZ (SEGON) (0035)
-- ================================================================
-- El segon jugador L. González té registres històrics per 2015 3 BANDES
-- però és un exsoci diferent del soci 7026 (Lluis Gonzalez Carvajal)
-- 
-- S'assigna número inventat 0035 ja que no es coneix el número real
-- És un exsoci que va jugar:
-- • 3 BANDES: 2015 (mitjana 0.244)
-- ================================================================

BEGIN;

-- Afegir segon L. González com a exsoci amb número inventat
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (0035, 'L.', 'González (segon)', NULL, TRUE, '2015-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'L. González (segon exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 0035;

COMMIT;