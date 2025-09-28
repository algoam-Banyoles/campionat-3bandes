-- Migració 010 v2: Arreglar polítiques RLS per events (compatible amb estructura actual)

BEGIN;

-- Habilitar RLS per events si no està habilitat
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Polítiques per a la taula events
CREATE POLICY "Usuaris autenticats poden veure events"
    ON events FOR SELECT TO authenticated USING (true);

CREATE POLICY "Només admins poden gestionar events"
    ON events FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- Política per configuració_calendari
CREATE POLICY "Usuaris autenticats poden veure configuració calendari"
    ON configuracio_calendari FOR SELECT TO authenticated USING (true);

CREATE POLICY "Només admins poden gestionar configuració calendari"
    ON configuracio_calendari FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- Política per inscripcions - funciona tant amb id com amb numero_soci
-- Comprova primer si existeix columna id, sinó utilitza numero_soci
DO $$
BEGIN
    -- Comprova si la columna socis.id existeix
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'socis'
        AND column_name = 'id'
        AND table_schema = 'public'
    ) THEN
        -- Si existeix socis.id, utilitza aquesta referència
        EXECUTE 'CREATE POLICY "Usuaris poden gestionar les seves inscripcions"
                 ON inscripcions FOR ALL TO authenticated
                 USING (
                     EXISTS (
                         SELECT 1 FROM socis
                         WHERE socis.id = inscripcions.soci_id
                         AND socis.email = auth.jwt() ->> ''email''
                     )
                 )';
    ELSE
        -- Si no existeix socis.id, utilitza numero_soci
        EXECUTE 'CREATE POLICY "Usuaris poden gestionar les seves inscripcions"
                 ON inscripcions FOR ALL TO authenticated
                 USING (
                     EXISTS (
                         SELECT 1 FROM socis
                         WHERE socis.numero_soci = inscripcions.soci_id::text
                         AND socis.email = auth.jwt() ->> ''email''
                     )
                 )';
    END IF;
END
$$;

COMMIT;