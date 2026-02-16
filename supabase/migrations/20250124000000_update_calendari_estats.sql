-- Actualitzar el constraint d'estats de calendari_partides per incloure tots els estats utilitzats

-- Eliminar el constraint actual
ALTER TABLE calendari_partides DROP CONSTRAINT IF EXISTS calendari_partides_estat_check;

-- Crear el nou constraint amb tots els estats utilitzats a l'aplicació
ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_estat_check
    CHECK (estat IN (
        'generat',
        'validat',
        'publicat',
        'reprogramada',
        'jugada',
        'cancel·lada',
        'pendent_programar'
    ));
