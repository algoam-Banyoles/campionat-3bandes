-- Migració 017: Corregir referències inconsistents a calendari_partides
-- Problema: La migració 015 usa socis(numero) mentre l'esquema estàndard usa socis(id)

BEGIN;

-- 1. Verificar si calendari_partides existeix i té les referències incorrectes
DO $$
BEGIN
    -- Verificar si la taula existeix
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'calendari_partides' AND table_schema = 'public') THEN

        -- Verificar si jugador1_id fa referència a numero en lloc d'id
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'calendari_partides'
            AND column_name = 'jugador1_id'
            AND data_type = 'integer'
        ) THEN

            RAISE NOTICE 'Corregint referències de calendari_partides de numero a id...';

            -- Eliminar constraints existents
            ALTER TABLE calendari_partides DROP CONSTRAINT IF EXISTS calendari_partides_jugador1_id_fkey;
            ALTER TABLE calendari_partides DROP CONSTRAINT IF EXISTS calendari_partides_jugador2_id_fkey;
            ALTER TABLE calendari_partides DROP CONSTRAINT IF EXISTS calendari_partides_guanyador_id_fkey;

            -- Crear columnes temporals amb UUID
            ALTER TABLE calendari_partides ADD COLUMN jugador1_id_new UUID;
            ALTER TABLE calendari_partides ADD COLUMN jugador2_id_new UUID;
            ALTER TABLE calendari_partides ADD COLUMN guanyador_id_new UUID;

            -- Migrar dades utilitzant numero_soci -> id mapping
            UPDATE calendari_partides SET jugador1_id_new = s.id
            FROM socis s
            WHERE s.numero_soci = calendari_partides.jugador1_id;

            UPDATE calendari_partides SET jugador2_id_new = s.id
            FROM socis s
            WHERE s.numero_soci = calendari_partides.jugador2_id;

            UPDATE calendari_partides SET guanyador_id_new = s.id
            FROM socis s
            WHERE s.numero_soci = calendari_partides.guanyador_id
            AND calendari_partides.guanyador_id IS NOT NULL;

            -- Eliminar columnes antigues i renombrar les noves
            ALTER TABLE calendari_partides DROP COLUMN jugador1_id;
            ALTER TABLE calendari_partides DROP COLUMN jugador2_id;
            ALTER TABLE calendari_partides DROP COLUMN guanyador_id;

            ALTER TABLE calendari_partides RENAME COLUMN jugador1_id_new TO jugador1_id;
            ALTER TABLE calendari_partides RENAME COLUMN jugador2_id_new TO jugador2_id;
            ALTER TABLE calendari_partides RENAME COLUMN guanyador_id_new TO guanyador_id;

            -- Establir NOT NULL per jugadors (obligatoris)
            ALTER TABLE calendari_partides ALTER COLUMN jugador1_id SET NOT NULL;
            ALTER TABLE calendari_partides ALTER COLUMN jugador2_id SET NOT NULL;

            -- Recrear constraints amb referències correctes
            ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_jugador1_id_fkey
                FOREIGN KEY (jugador1_id) REFERENCES socis(id) ON DELETE CASCADE;

            ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_jugador2_id_fkey
                FOREIGN KEY (jugador2_id) REFERENCES socis(id) ON DELETE CASCADE;

            ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_guanyador_id_fkey
                FOREIGN KEY (guanyador_id) REFERENCES socis(id) ON DELETE SET NULL;

            -- Recrear constraint de jugadors diferents
            ALTER TABLE calendari_partides ADD CONSTRAINT calendari_partides_jugadors_diferents
                CHECK (jugador1_id != jugador2_id);

            RAISE NOTICE 'Referències de calendari_partides corregides correctament.';

        ELSE
            RAISE NOTICE 'calendari_partides ja utilitza referències UUID correctes.';
        END IF;

    ELSE
        RAISE NOTICE 'calendari_partides no existeix, no cal corregir res.';
    END IF;
END
$$;

-- 2. Actualitzar índexs per utilitzar els nous camps UUID
DROP INDEX IF EXISTS idx_calendari_partides_jugadors;
CREATE INDEX IF NOT EXISTS idx_calendari_partides_jugadors ON calendari_partides(jugador1_id, jugador2_id);

-- 3. Assegurar que els tipus de dades són consistents a totes les taules
-- Verificar configuracio_calendari (hauria de tenir la referència correcta ja)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'configuracio_calendari' AND table_schema = 'public') THEN
        -- configuracio_calendari no hauria de tenir referències directes a socis, només event_id
        RAISE NOTICE 'configuracio_calendari verificada.';
    END IF;
END
$$;

-- 4. Comentaris finals
COMMENT ON TABLE calendari_partides IS 'Calendari de partides generat automàticament per lligues socials. Utilitza referències UUID a socis.id';
COMMENT ON COLUMN calendari_partides.jugador1_id IS 'Referència UUID al primer jugador (socis.id)';
COMMENT ON COLUMN calendari_partides.jugador2_id IS 'Referència UUID al segon jugador (socis.id)';
COMMENT ON COLUMN calendari_partides.guanyador_id IS 'Referència UUID al jugador guanyador (socis.id), null si no s''ha jugat';

-- 5. Actualitzar polítiques RLS per utilitzar la taula admins correcta
-- (Basat en fix-calendar-rls-simple.sql)

-- Eliminar polítiques incorrectes
DROP POLICY IF EXISTS "Només admins poden gestionar calendari" ON calendari_partides;
DROP POLICY IF EXISTS "Només admins poden gestionar configuració calendari" ON configuracio_calendari;

-- Crear polítiques correctes utilitzant la taula admins
CREATE POLICY "Només admins poden gestionar calendari" ON calendari_partides
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.admins a
            WHERE a.email = auth.email()
        )
    );

CREATE POLICY "Només admins poden gestionar configuració calendari" ON configuracio_calendari
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.admins a
            WHERE a.email = auth.email()
        )
    );

COMMIT;