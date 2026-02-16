-- Eliminar el constraint actual
ALTER TABLE calendari_partides DROP CONSTRAINT IF EXISTS calendari_partides_estat_check;

-- Crear el nou constraint amb l'estat 'publicat'
ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_estat_check 
    CHECK (estat IN ('generat', 'validat', 'publicat'));