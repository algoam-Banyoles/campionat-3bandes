-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR ARTURO CASTILLO JUAN (6897)
-- ================================================================
-- El jugador Arturo Castillo Juan (exsoci 6897) té registres històrics 
-- des de 2013-2020 però no existeix a la taula socis
-- 
-- És un exsoci molt actiu que va jugar:
-- • 3 BANDES: 2013-2020 (8 anys)
-- • BANDA: 2013-2020 (8 anys)
-- • LLIURE: 2013-2020 (8 anys)
-- Total: més de 20 registres històrics
-- ================================================================

BEGIN;

-- Afegir Arturo Castillo Juan com a exsoci
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (6897, 'Arturo', 'Castillo Juan', NULL, TRUE, '2020-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'Arturo Castillo Juan (exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 6897;

COMMIT;