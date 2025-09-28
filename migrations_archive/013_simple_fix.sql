-- Migració 013: Arregla events i inscripcions utilitzant numero_soci

BEGIN;

-- 1. Habilitar RLS per events
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- 2. Polítiques per events
CREATE POLICY IF NOT EXISTS "Usuaris autenticats poden veure events"
    ON events FOR SELECT TO authenticated USING (true);

CREATE POLICY IF NOT EXISTS "Només admins poden gestionar events"
    ON events FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- 3. Modificar inscripcions per utilitzar numero_soci en lloc d'id
-- Primer eliminem la taula inscripcions i la recreem correctament
DROP TABLE IF EXISTS inscripcions CASCADE;

CREATE TABLE inscripcions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    soci_numero integer NOT NULL REFERENCES socis(numero_soci) ON DELETE CASCADE,
    categoria_assignada_id uuid REFERENCES categories(id) ON DELETE SET NULL,
    data_inscripcio timestamp with time zone DEFAULT now(),
    preferencies_dies text[] DEFAULT '{}',
    preferencies_hores text[] DEFAULT '{}',
    restriccions_especials text,
    observacions text,
    pagat boolean DEFAULT false,
    confirmat boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT inscripcions_event_soci_unique UNIQUE (event_id, soci_numero)
);

-- 4. Habilitar RLS per inscripcions
ALTER TABLE inscripcions ENABLE ROW LEVEL SECURITY;

-- 5. Polítiques per inscripcions
CREATE POLICY "Usuaris autenticats poden veure inscripcions"
    ON inscripcions FOR SELECT TO authenticated USING (true);

CREATE POLICY "Usuaris poden gestionar les seves inscripcions"
    ON inscripcions FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM socis
            WHERE socis.numero_soci = inscripcions.soci_numero
            AND socis.email = auth.jwt() ->> 'email'
        )
    );

CREATE POLICY "Només admins poden gestionar totes les inscripcions"
    ON inscripcions FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- 6. Crear índexs
CREATE INDEX IF NOT EXISTS idx_inscripcions_event_id ON inscripcions(event_id);
CREATE INDEX IF NOT EXISTS idx_inscripcions_soci_numero ON inscripcions(soci_numero);

-- 7. Polítiques per configuració_calendari
ALTER TABLE configuracio_calendari ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Usuaris autenticats poden veure configuració calendari"
    ON configuracio_calendari FOR SELECT TO authenticated USING (true);

CREATE POLICY IF NOT EXISTS "Només admins poden gestionar configuració calendari"
    ON configuracio_calendari FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

COMMIT;