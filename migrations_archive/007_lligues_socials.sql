-- Migració 007: Extensions per Campionats Socials
-- Basat en l'esquema real de producció utilitzant socis (després de consolidació)

BEGIN;

-- 1. Ampliar events amb camps per competicions socials
ALTER TABLE events ADD COLUMN IF NOT EXISTS modalitat text
    CHECK (modalitat IN ('tres_bandes', 'lliure', 'banda'));

ALTER TABLE events ADD COLUMN IF NOT EXISTS tipus_competicio text
    CHECK (tipus_competicio IN ('ranking_continu', 'lliga_social', 'handicap', 'eliminatories'));

ALTER TABLE events ADD COLUMN IF NOT EXISTS format_joc text
    CHECK (format_joc IN ('lliga', 'eliminatoria_simple', 'eliminatoria_doble'));

ALTER TABLE events ADD COLUMN IF NOT EXISTS data_inici date;
ALTER TABLE events ADD COLUMN IF NOT EXISTS data_fi date;

ALTER TABLE events ADD COLUMN IF NOT EXISTS estat_competicio text DEFAULT 'planificacio'
    CHECK (estat_competicio IN ('planificacio', 'inscripcions', 'pendent_validacio', 'validat', 'en_curs', 'finalitzat'));

ALTER TABLE events ADD COLUMN IF NOT EXISTS max_participants integer;
ALTER TABLE events ADD COLUMN IF NOT EXISTS quota_inscripcio decimal(5,2);

-- 2. Categories per campionats (múltiples categories per event)
CREATE TABLE IF NOT EXISTS categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    nom text NOT NULL,
    distancia_caramboles integer NOT NULL,
    max_entrades integer NOT NULL DEFAULT 50,
    ordre_categoria smallint NOT NULL,
    min_jugadors integer DEFAULT 8,
    max_jugadors integer DEFAULT 12,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT categories_ordre_unique UNIQUE (event_id, ordre_categoria)
);

-- 3. Inscripcions (utilitza socis després de consolidació)
CREATE TABLE IF NOT EXISTS inscripcions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    soci_id uuid NOT NULL REFERENCES socis(id) ON DELETE CASCADE,
    categoria_assignada_id uuid REFERENCES categories(id) ON DELETE SET NULL,
    data_inscripcio timestamp with time zone DEFAULT now(),
    preferencies_dies text[] DEFAULT '{}', -- ['dl', 'dt', 'dc', 'dj', 'dv']
    preferencies_hores text[] DEFAULT '{}', -- ['18:00', '19:00']
    restriccions_especials text,
    observacions text,
    pagat boolean DEFAULT false,
    confirmat boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT inscripcions_event_soci_unique UNIQUE (event_id, soci_id)
);

-- 4. Configuració calendari per event
CREATE TABLE IF NOT EXISTS configuracio_calendari (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    dies_setmana text[] DEFAULT ARRAY['dl','dt','dc','dj','dv'],
    hores_disponibles text[] DEFAULT ARRAY['18:00','19:00'],
    taules_per_slot integer DEFAULT 3,
    max_partides_per_setmana integer DEFAULT 3,
    max_partides_per_dia integer DEFAULT 1,
    dies_festius date[] DEFAULT '{}',
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT configuracio_calendari_event_unique UNIQUE (event_id)
);

-- 5. Calendari partides generat automàticament
CREATE TABLE IF NOT EXISTS calendari_partides (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    categoria_id uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    jugador1_id uuid NOT NULL REFERENCES socis(id) ON DELETE CASCADE,
    jugador2_id uuid NOT NULL REFERENCES socis(id) ON DELETE CASCADE,
    data_programada timestamp with time zone,
    hora_inici time,
    taula_assignada integer,
    estat text DEFAULT 'generat' CHECK (estat IN ('generat', 'validat', 'reprogramada', 'jugada', 'cancel·lada', 'pendent_programar')),

    -- Validació junta
    validat_per uuid REFERENCES auth.users(id),
    data_validacio timestamp with time zone,
    observacions_junta text,

    -- Reprogramacions
    data_canvi_solicitada timestamp with time zone,
    motiu_canvi text,
    aprovat_canvi_per uuid REFERENCES auth.users(id),
    data_aprovacio_canvi timestamp with time zone,

    -- Resultat final
    match_id uuid REFERENCES matches(id),
    created_at timestamp with time zone DEFAULT now(),

    CONSTRAINT calendari_partides_jugadors_diferents CHECK (jugador1_id != jugador2_id),
    CONSTRAINT calendari_partides_event_categoria_jugadors_unique
        UNIQUE (event_id, categoria_id, jugador1_id, jugador2_id)
);

-- 6. Ampliar matches per campionats socials
ALTER TABLE matches ADD COLUMN IF NOT EXISTS jornada integer;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS categoria_id uuid REFERENCES categories(id);
ALTER TABLE matches ADD COLUMN IF NOT EXISTS tipus_partida text DEFAULT 'challenge'
    CHECK (tipus_partida IN ('challenge', 'lliga', 'eliminatoria', 'handicap'));

-- 7. Classificacions per categories (calculada dinàmicament)
CREATE TABLE IF NOT EXISTS classificacions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    categoria_id uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    soci_id uuid NOT NULL REFERENCES socis(id) ON DELETE CASCADE,
    posicio integer NOT NULL,
    partides_jugades integer DEFAULT 0,
    partides_guanyades integer DEFAULT 0,
    partides_perdudes integer DEFAULT 0,
    partides_empat integer DEFAULT 0,
    punts integer DEFAULT 0,
    caramboles_favor integer DEFAULT 0,
    caramboles_contra integer DEFAULT 0,
    mitjana_particular numeric(6,3),
    updated_at timestamp with time zone DEFAULT now(),

    CONSTRAINT classificacions_event_categoria_soci_unique
        UNIQUE (event_id, categoria_id, soci_id),
    CONSTRAINT classificacions_posicio_categoria_unique
        UNIQUE (categoria_id, posicio)
);

-- 8. Crear índexs per optimitzar consultes
CREATE INDEX IF NOT EXISTS idx_categories_event_id ON categories(event_id);
CREATE INDEX IF NOT EXISTS idx_categories_ordre ON categories(event_id, ordre_categoria);

CREATE INDEX IF NOT EXISTS idx_inscripcions_event_id ON inscripcions(event_id);
CREATE INDEX IF NOT EXISTS idx_inscripcions_soci_id ON inscripcions(soci_id);

CREATE INDEX IF NOT EXISTS idx_calendari_event_categoria ON calendari_partides(event_id, categoria_id);
CREATE INDEX IF NOT EXISTS idx_calendari_data_programada ON calendari_partides(data_programada);
CREATE INDEX IF NOT EXISTS idx_calendari_estat ON calendari_partides(estat);
CREATE INDEX IF NOT EXISTS idx_calendari_jugadors ON calendari_partides(jugador1_id, jugador2_id);

CREATE INDEX IF NOT EXISTS idx_classificacions_categoria ON classificacions(categoria_id, posicio);
CREATE INDEX IF NOT EXISTS idx_classificacions_soci ON classificacions(soci_id);

-- 9. Configurar RLS (Row Level Security)
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE inscripcions ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracio_calendari ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendari_partides ENABLE ROW LEVEL SECURITY;
ALTER TABLE classificacions ENABLE ROW LEVEL SECURITY;

-- 10. Polítiques RLS bàsiques (tot visible per usuaris autenticats per ara)
CREATE POLICY "Usuaris autenticats poden veure categories"
    ON categories FOR SELECT TO authenticated USING (true);

CREATE POLICY "Usuaris autenticats poden veure inscripcions"
    ON inscripcions FOR SELECT TO authenticated USING (true);

CREATE POLICY "Usuaris autenticats poden veure calendari"
    ON calendari_partides FOR SELECT TO authenticated USING (true);

CREATE POLICY "Usuaris autenticats poden veure classificacions"
    ON classificacions FOR SELECT TO authenticated USING (true);

-- Políticas d'inserció només per admins (de moment)
CREATE POLICY "Només admins poden gestionar campionats socials"
    ON categories FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

CREATE POLICY "Només admins poden gestionar inscripcions"
    ON inscripcions FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

CREATE POLICY "Només admins poden gestionar calendari"
    ON calendari_partides FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- 11. Funcions auxiliars
CREATE OR REPLACE FUNCTION update_classificacio_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_classificacions_updated_at
    BEFORE UPDATE ON classificacions
    FOR EACH ROW EXECUTE FUNCTION update_classificacio_timestamp();

-- 12. Vista per anàlisi calendari
CREATE OR REPLACE VIEW v_analisi_calendari AS
SELECT
    cp.event_id,
    cp.categoria_id,
    c.nom as categoria_nom,
    COUNT(*) as total_partides,
    COUNT(*) FILTER (WHERE cp.estat = 'generat') as partides_generades,
    COUNT(*) FILTER (WHERE cp.estat = 'validat') as partides_validades,
    COUNT(*) FILTER (WHERE cp.estat = 'jugada') as partides_jugades,
    COUNT(*) FILTER (WHERE cp.estat = 'pendent_programar') as partides_pendents,
    MIN(DATE(cp.data_programada)) as data_inici,
    MAX(DATE(cp.data_programada)) as data_fi,
    CASE
        WHEN MIN(DATE(cp.data_programada)) IS NOT NULL THEN
            MAX(DATE(cp.data_programada)) - MIN(DATE(cp.data_programada))
        ELSE NULL
    END as durada_dies
FROM calendari_partides cp
JOIN categories c ON cp.categoria_id = c.id
GROUP BY cp.event_id, cp.categoria_id, c.nom;

-- 13. Inserir configuració per defecte en events existents que siguin ranking continu
UPDATE events
SET
    modalitat = 'tres_bandes',
    tipus_competicio = 'ranking_continu'
WHERE tipus_competicio IS NULL;

COMMIT;