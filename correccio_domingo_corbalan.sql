-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR DOMINGO CORBALÁN JUAN (8041)
-- ================================================================
-- El jugador Domingo Corbalán Juan (exsoci 8041) té registres històrics 
-- des de 2016-2022 però no existeix a la taula socis
-- 
-- És un exsoci molt actiu que va jugar:
-- • 3 BANDES: 2016-2022 (7 anys)
-- • BANDA: 2016-2022 (7 anys)
-- • LLIURE: 2016-2022 (7 anys)
-- Total: 18 registres històrics
-- ================================================================

BEGIN;

-- Afegir Domingo Corbalán Juan com a exsoci
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (8041, 'Domingo', 'Corbalán Juan', NULL, TRUE, '2022-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'Domingo Corbalán Juan (exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 8041;

COMMIT;