-- ROLLBACK D'EMERGÈNCIA
-- Usa aquest script si alguna cosa ha anat malament i vols recuperar les dades originals

BEGIN;

-- Eliminar les dades incorrectes
TRUNCATE TABLE mitjanes_historiques;

-- Restaurar des del backup
INSERT INTO mitjanes_historiques 
SELECT * FROM mitjanes_historiques_backup;

-- Verificar que la restauració ha funcionat
SELECT 'ROLLBACK COMPLETAT:' as info;
SELECT COUNT(*) as files_restaurades FROM mitjanes_historiques;

COMMIT;

-- Opcional: eliminar el backup després de confirmar que tot funciona
-- DROP TABLE mitjanes_historiques_backup;