-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR JAVIER MUÑOZ LÓPEZ (8439)
-- ================================================================
-- El jugador Javier Muñoz López (exsoci 8439) té registres històrics 
-- des de 2021-2022 però no existeix a la taula socis
-- 
-- És un exsoci que va jugar:
-- • 3 BANDES: 2022 (posició 2, mitjana 0,460)
-- • BANDA: 2021 (posició 8, mitjana 0,859)
-- ================================================================

BEGIN;

-- Afegir Javier Muñoz López com a exsoci
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (8439, 'Javier', 'Muñoz López', NULL, TRUE, '2022-12-31') 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    data_baixa,
    'Javier Muñoz López (exsoci) afegit correctament' as status
FROM socis 
WHERE numero_soci = 8439;

COMMIT;