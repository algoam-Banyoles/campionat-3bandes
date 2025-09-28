-- Migració 012: Polítiques RLS finals per events (després d'arreglar socis)

BEGIN;

-- 1. Habilitar RLS per events
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- 2. Polítiques per events
DROP POLICY IF EXISTS "Usuaris autenticats poden veure events" ON events;
CREATE POLICY "Usuaris autenticats poden veure events"
    ON events FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Només admins poden gestionar events" ON events;
CREATE POLICY "Només admins poden gestionar events"
    ON events FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- 3. Polítiques per inscripcions (ara que socis.id existeix)
DROP POLICY IF EXISTS "Usuaris poden gestionar les seves inscripcions" ON inscripcions;
CREATE POLICY "Usuaris poden gestionar les seves inscripcions"
    ON inscripcions FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM socis
            WHERE socis.id = inscripcions.soci_id
            AND socis.email = auth.jwt() ->> 'email'
        )
    );

-- 4. Polítiques per configuració_calendari
DROP POLICY IF EXISTS "Usuaris autenticats poden veure configuració calendari" ON configuracio_calendari;
CREATE POLICY "Usuaris autenticats poden veure configuració calendari"
    ON configuracio_calendari FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Només admins poden gestionar configuració calendari" ON configuracio_calendari;
CREATE POLICY "Només admins poden gestionar configuració calendari"
    ON configuracio_calendari FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

COMMIT;