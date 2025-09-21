-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR L. GONZÁLEZ (TERCER) (0036)
-- ================================================================
-- El tercer jugador L. González té registres històrics per 2014 3 BANDES
-- però és un exsoci diferent del soci 7026 (Lluis Gonzalez Carvajal)
-- 
-- S'assigna número inventat 0036 ja que no es coneix el número real
-- És un exsoci que va jugar:
-- • 3 BANDES: 2014 (mitjana 0.222)
-- ================================================================

BEGIN;

-- Afegir tercer L. González com a exsoci amb número inventat
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (0036, 'L.', 'González (tercer)', NULL, TRUE, '2014-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'L. González (tercer exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 0036;

COMMIT;