-- ================================================================
-- CORRECCIÓ ESPECÍFICA: AFEGIR JUAN HERNÁNDEZ MÁRQUEZ (8186)
-- ================================================================
-- El jugador Juan Hernández Márquez (soci 8186) té 31 registres històrics 
-- des de 2011-2024 però no existeix a la taula socis
-- 
-- És un jugador molt actiu que juga les 3 modalitats:
-- • 3 BANDES: 2011-2024 (14 anys)
-- • BANDA: 2011-2024 (14 anys) 
-- • LLIURE: 2011-2024 (14 anys)
-- ================================================================

BEGIN;

-- Afegir Juan Hernández Márquez amb dades reals
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (8186, 'Juan', 'Hernández Márquez', NULL, FALSE, NULL) 
ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit correctament
SELECT 
    numero_soci, 
    nom, 
    cognoms, 
    de_baixa,
    'Juan Hernández Márquez afegit correctament' as status
FROM socis 
WHERE numero_soci = 8186;

COMMIT;