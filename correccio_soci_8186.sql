-- =================================================================
-- CORRECCIÓ: AFEGIR SOCI 8186 MANCAT
-- =================================================================
-- El soci 8186 té 31 registres històrics des de 2014-2024
-- però no existeix a la taula socis
-- 
-- S'afegeix com a soci actiu sense determinar si és exsoci
-- =================================================================

BEGIN;

-- Afegir soci 8186 mancat
INSERT INTO socis (numero_soci, nom, cognoms, email, de_baixa, data_baixa) 
VALUES (8186, '[MANCAT]', 'SOCI_8186', NULL, FALSE, NULL) ON CONFLICT (numero_soci) DO NOTHING;

-- Verificar que s'ha afegit
SELECT numero_soci, nom, cognoms, de_baixa FROM socis WHERE numero_soci = 8186;

COMMIT;
