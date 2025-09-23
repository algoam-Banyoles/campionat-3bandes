-- ================================================================
-- MIGRACIÓ 007: LLIGUES SOCIALS
-- Copiar i pegar a l'editor SQL de Supabase Dashboard
-- ================================================================

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

-- 2. Categories per lligues (múltiples categories per event)
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

-- 3. Inscripcions
CREATE TABLE IF NOT EXISTS inscripcions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    categoria_assignada_id uuid REFERENCES categories(id) ON DELETE SET NULL,
    data_inscripcio timestamp with time zone DEFAULT now(),
    preferencies_dies text[] DEFAULT '{}',
    preferencies_hores text[] DEFAULT '{}',
    restriccions_especials text,
    observacions text,
    pagat boolean DEFAULT false,
    confirmat boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT inscripcions_event_player_unique UNIQUE (event_id, player_id)
);

-- 4. Configuració calendari per event
CREATE TABLE IF NOT EXISTS configuracio_calendari (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    dies_setmana text[] DEFAULT array['dl','dt','dc','dj','dv'],
    hores_disponibles text[] DEFAULT array['18:00','19:00'],
    taules_per_slot integer DEFAULT 3,
    max_partides_per_setmana integer DEFAULT 3,
    max_partides_per_dia integer DEFAULT 1,
    dies_festius date[] DEFAULT array[]::date[],
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT configuracio_calendari_event_unique UNIQUE (event_id)
);

-- 5. Calendari partides generat automàticament
CREATE TABLE IF NOT EXISTS calendari_partides (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    categoria_id uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    jugador1_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    jugador2_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    data_programada timestamp with time zone,
    hora_inici time,
    taula_assignada integer,
    estat text DEFAULT 'generat' CHECK (estat IN ('generat', 'validat', 'reprogramada', 'jugada', 'cancel·lada', 'pendent_programar')),
    validat_per uuid REFERENCES auth.users(id),
    data_validacio timestamp with time zone,
    observacions_junta text,
    data_canvi_solicitada timestamp with time zone,
    motiu_canvi text,
    aprovat_canvi_per uuid REFERENCES auth.users(id),
    data_aprovacio_canvi timestamp with time zone,
    match_id uuid REFERENCES matches(id),
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT calendari_partides_jugadors_diferents CHECK (jugador1_id != jugador2_id),
    CONSTRAINT calendari_partides_event_categoria_jugadors_unique
        UNIQUE (event_id, categoria_id, jugador1_id, jugador2_id)
);

-- 6. Ampliar matches per lligues socials
ALTER TABLE matches ADD COLUMN IF NOT EXISTS jornada integer;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS categoria_id uuid REFERENCES categories(id);
ALTER TABLE matches ADD COLUMN IF NOT EXISTS tipus_partida text DEFAULT 'challenge'
    CHECK (tipus_partida IN ('challenge', 'lliga', 'eliminatoria', 'handicap'));

-- 7. Classificacions per categories
CREATE TABLE IF NOT EXISTS classificacions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    categoria_id uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
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
    CONSTRAINT classificacions_event_categoria_player_unique
        UNIQUE (event_id, categoria_id, player_id),
    CONSTRAINT classificacions_posicio_categoria_unique
        UNIQUE (categoria_id, posicio)
);

-- 8. Crear índexs
CREATE INDEX IF NOT EXISTS idx_categories_event_id ON categories(event_id);
CREATE INDEX IF NOT EXISTS idx_categories_ordre ON categories(event_id, ordre_categoria);
CREATE INDEX IF NOT EXISTS idx_inscripcions_event_id ON inscripcions(event_id);
CREATE INDEX IF NOT EXISTS idx_inscripcions_player_id ON inscripcions(player_id);
CREATE INDEX IF NOT EXISTS idx_calendari_event_categoria ON calendari_partides(event_id, categoria_id);
CREATE INDEX IF NOT EXISTS idx_calendari_data_programada ON calendari_partides(data_programada);
CREATE INDEX IF NOT EXISTS idx_calendari_estat ON calendari_partides(estat);
CREATE INDEX IF NOT EXISTS idx_calendari_jugadors ON calendari_partides(jugador1_id, jugador2_id);
CREATE INDEX IF NOT EXISTS idx_classificacions_categoria ON classificacions(categoria_id, posicio);
CREATE INDEX IF NOT EXISTS idx_classificacions_player ON classificacions(player_id);

-- 9. RLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE inscripcions ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracio_calendari ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendari_partides ENABLE ROW LEVEL SECURITY;
ALTER TABLE classificacions ENABLE ROW LEVEL SECURITY;

-- 10. Polítiques RLS bàsiques
CREATE POLICY "Usuaris autenticats poden veure categories"
    ON categories FOR SELECT TO authenticated USING (true);

CREATE POLICY "Usuaris autenticats poden veure inscripcions"
    ON inscripcions FOR SELECT TO authenticated USING (true);

CREATE POLICY "Usuaris autenticats poden veure calendari"
    ON calendari_partides FOR SELECT TO authenticated USING (true);

CREATE POLICY "Usuaris autenticats poden veure classificacions"
    ON classificacions FOR SELECT TO authenticated USING (true);

-- 11. Trigger actualitzar timestamp
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

-- 12. Vista anàlisi calendari
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

-- 13. Actualitzar events existents
UPDATE events
SET
    modalitat = 'tres_bandes',
    tipus_competicio = 'ranking_continu'
WHERE tipus_competicio IS NULL;

-- ================================================================
-- VERIFICACIÓ: Executar per comprovar que tot està OK
-- ================================================================
SELECT
    'Migration 007 completed successfully' as status,
    COUNT(*) as new_tables_created
FROM information_schema.tables
WHERE table_name IN ('categories', 'inscripcions', 'configuracio_calendari', 'calendari_partides', 'classificacions');