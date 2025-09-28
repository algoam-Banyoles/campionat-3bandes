-- Migració 010: Arreglar polítiques RLS per events

BEGIN;

-- Habilitar RLS per events si no està habilitat
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Polítiques per a la taula events
CREATE POLICY "Usuaris autenticats poden veure events"
    ON events FOR SELECT TO authenticated USING (true);

CREATE POLICY "Només admins poden gestionar events"
    ON events FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- Assegurar que inscripcions permet operacions d'usuaris per les seves pròpies inscripcions
CREATE POLICY "Usuaris poden gestionar les seves inscripcions"
    ON inscripcions FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM socis
            WHERE socis.id = inscripcions.soci_id
            AND socis.email = auth.jwt() ->> 'email'
        )
    );

-- Política addicional per configuració_calendari
CREATE POLICY "Usuaris autenticats poden veure configuració calendari"
    ON configuracio_calendari FOR SELECT TO authenticated USING (true);

CREATE POLICY "Només admins poden gestionar configuració calendari"
    ON configuracio_calendari FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

COMMIT;