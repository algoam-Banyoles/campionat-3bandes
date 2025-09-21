-- PASO 4: CÒPIA DE SEGURETAT
-- EXECUTA AQUEST PRIMER abans de la càrrega destructiva!

-- Crear taula de backup
CREATE TABLE mitjanes_historiques_backup AS 
SELECT * FROM mitjanes_historiques;

-- Verificar que el backup s'ha creat correctament
SELECT 'BACKUP CREAT:' as info;
SELECT COUNT(*) as files_backup FROM mitjanes_historiques_backup;
SELECT COUNT(*) as files_original FROM mitjanes_historiques;

-- Mostrar primeres files del backup per verificar
SELECT * FROM mitjanes_historiques_backup LIMIT 5;