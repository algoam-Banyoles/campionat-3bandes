-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR EDUARDO ROYES GARCIA (8411)
-- ================================================================
-- El jugador Eduardo Royes Garcia (exsoci 8411) té registres històrics 
-- des de 2021-2024 però no existeix a la taula socis
-- 
-- És un exsoci que va jugar:
-- • 3 BANDES: 2021, 2023
-- • BANDA: 2021, 2022, 2024
-- • LLIURE: 2023, 2024
-- ================================================================

BEGIN;

-- Afegir Eduardo Royes Garcia com a exsoci
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (8411, 'Eduardo', 'Royes Garcia', NULL, TRUE, '2024-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'Eduardo Royes Garcia (exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 8411;

COMMIT;