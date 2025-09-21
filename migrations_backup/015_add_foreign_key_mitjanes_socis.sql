-- Afegir clau forana entre mitjanes_historiques i socis
-- Primer, assegurem-nos que totes les referències existents són vàlides

-- Eliminar registres orfes (si n'hi ha)
DELETE FROM mitjanes_historiques 
WHERE soci_id NOT IN (SELECT numero_soci FROM socis);

-- Afegir la clau forana només si no existeix
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_mitjanes_historiques_soci_id'
    ) THEN
        ALTER TABLE mitjanes_historiques 
        ADD CONSTRAINT fk_mitjanes_historiques_soci_id 
        FOREIGN KEY (soci_id) REFERENCES socis(numero_soci) 
        ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;

-- Comentari per documentar la relació
COMMENT ON CONSTRAINT fk_mitjanes_historiques_soci_id ON mitjanes_historiques 
IS 'Clau forana que relaciona mitjanes històriques amb socis';