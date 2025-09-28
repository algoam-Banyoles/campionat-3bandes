-- Migració 011: Arreglar referències a socis per compatibilitat

BEGIN;

-- 1. Afegir columna id a socis si no existeix
ALTER TABLE socis ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid();

-- 2. Crear índex únic per id si no existeix
CREATE UNIQUE INDEX IF NOT EXISTS socis_id_unique ON socis(id);

-- 3. Modificar les taules que fan referència a socis per utilitzar el tipus correcte
-- Primer, comprovem el tipus actual de soci_id a inscripcions
DO $$
DECLARE
    soci_id_type text;
BEGIN
    -- Obtenir el tipus actual de soci_id
    SELECT data_type INTO soci_id_type
    FROM information_schema.columns
    WHERE table_name = 'inscripcions'
    AND column_name = 'soci_id'
    AND table_schema = 'public';

    -- Si soci_id no és uuid, la modifiquem
    IF soci_id_type != 'uuid' THEN
        -- Eliminar constraint de foreign key temporalment
        ALTER TABLE inscripcions DROP CONSTRAINT IF EXISTS inscripcions_soci_id_fkey;

        -- Convertir soci_id a UUID utilitzant el mapping amb socis
        ALTER TABLE inscripcions ADD COLUMN soci_id_new uuid;

        UPDATE inscripcions SET soci_id_new = s.id
        FROM socis s
        WHERE s.numero_soci::text = inscripcions.soci_id::text;

        -- Eliminar columna antiga i renombrar la nova
        ALTER TABLE inscripcions DROP COLUMN soci_id;
        ALTER TABLE inscripcions RENAME COLUMN soci_id_new TO soci_id;
        ALTER TABLE inscripcions ALTER COLUMN soci_id SET NOT NULL;

        -- Recrear foreign key
        ALTER TABLE inscripcions ADD CONSTRAINT inscripcions_soci_id_fkey
            FOREIGN KEY (soci_id) REFERENCES socis(id) ON DELETE CASCADE;
    END IF;
END
$$;

-- 4. Fer el mateix per altres taules si existeixen
DO $$
BEGIN
    -- Arreglar llista_espera si existeix
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'llista_espera') THEN
        -- Comprovar tipus de soci_id
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'llista_espera'
            AND column_name = 'soci_id'
            AND data_type != 'uuid'
        ) THEN
            ALTER TABLE llista_espera DROP CONSTRAINT IF EXISTS llista_espera_soci_id_fkey;

            ALTER TABLE llista_espera ADD COLUMN soci_id_new uuid;

            UPDATE llista_espera SET soci_id_new = s.id
            FROM socis s
            WHERE s.numero_soci::text = llista_espera.soci_id::text;

            ALTER TABLE llista_espera DROP COLUMN soci_id;
            ALTER TABLE llista_espera RENAME COLUMN soci_id_new TO soci_id;
            ALTER TABLE llista_espera ALTER COLUMN soci_id SET NOT NULL;

            ALTER TABLE llista_espera ADD CONSTRAINT llista_espera_soci_id_fkey
                FOREIGN KEY (soci_id) REFERENCES socis(id) ON DELETE CASCADE;
        END IF;
    END IF;

    -- Arreglar classificacions si existeix
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'classificacions') THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'classificacions'
            AND column_name = 'soci_id'
            AND data_type != 'uuid'
        ) THEN
            ALTER TABLE classificacions DROP CONSTRAINT IF EXISTS classificacions_soci_id_fkey;

            ALTER TABLE classificacions ADD COLUMN soci_id_new uuid;

            UPDATE classificacions SET soci_id_new = s.id
            FROM socis s
            WHERE s.numero_soci::text = classificacions.soci_id::text;

            ALTER TABLE classificacions DROP COLUMN soci_id;
            ALTER TABLE classificacions RENAME COLUMN soci_id_new TO soci_id;
            ALTER TABLE classificacions ALTER COLUMN soci_id SET NOT NULL;

            ALTER TABLE classificacions ADD CONSTRAINT classificacions_soci_id_fkey
                FOREIGN KEY (soci_id) REFERENCES socis(id) ON DELETE CASCADE;
        END IF;
    END IF;

    -- Arreglar calendari_partides si existeix
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'calendari_partides') THEN
        -- Jugador1_id
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'calendari_partides'
            AND column_name = 'jugador1_id'
            AND data_type != 'uuid'
        ) THEN
            ALTER TABLE calendari_partides DROP CONSTRAINT IF EXISTS calendari_partides_jugador1_id_fkey;

            ALTER TABLE calendari_partides ADD COLUMN jugador1_id_new uuid;

            UPDATE calendari_partides SET jugador1_id_new = s.id
            FROM socis s
            WHERE s.numero_soci::text = calendari_partides.jugador1_id::text;

            ALTER TABLE calendari_partides DROP COLUMN jugador1_id;
            ALTER TABLE calendari_partides RENAME COLUMN jugador1_id_new TO jugador1_id;
            ALTER TABLE calendari_partides ALTER COLUMN jugador1_id SET NOT NULL;

            ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_jugador1_id_fkey
                FOREIGN KEY (jugador1_id) REFERENCES socis(id) ON DELETE CASCADE;
        END IF;

        -- Jugador2_id
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'calendari_partides'
            AND column_name = 'jugador2_id'
            AND data_type != 'uuid'
        ) THEN
            ALTER TABLE calendari_partides DROP CONSTRAINT IF EXISTS calendari_partides_jugador2_id_fkey;

            ALTER TABLE calendari_partides ADD COLUMN jugador2_id_new uuid;

            UPDATE calendari_partides SET jugador2_id_new = s.id
            FROM socis s
            WHERE s.numero_soci::text = calendari_partides.jugador2_id::text;

            ALTER TABLE calendari_partides DROP COLUMN jugador2_id;
            ALTER TABLE calendari_partides RENAME COLUMN jugador2_id_new TO jugador2_id;
            ALTER TABLE calendari_partides ALTER COLUMN jugador2_id SET NOT NULL;

            ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_jugador2_id_fkey
                FOREIGN KEY (jugador2_id) REFERENCES socis(id) ON DELETE CASCADE;
        END IF;
    END IF;
END
$$;

COMMIT;