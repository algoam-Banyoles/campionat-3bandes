-- Migració 018: Implementar sistema de Festes de Primavera
-- Segons les normes: participació gratuïta, jornada de portes obertes, sense límit de participants

BEGIN;

-- 1. Assegurar que el tipus_competicio inclou 'festes_primavera'
DO $$
BEGIN
    -- Comprovar si el constraint existeix i l'actualitzem
    IF EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name LIKE '%tipus_competicio%'
        AND table_name = 'events'
    ) THEN
        -- Eliminar constraint anterior
        ALTER TABLE events DROP CONSTRAINT IF EXISTS events_tipus_competicio_check;
    END IF;

    -- Afegir nou constraint amb festes_primavera
    ALTER TABLE events ADD CONSTRAINT events_tipus_competicio_check
        CHECK (tipus_competicio IN ('ranking_continu', 'lliga_social', 'handicap', 'eliminatories', 'festes_primavera'));

    RAISE NOTICE 'Constraint tipus_competicio actualitzat amb festes_primavera';
END
$$;

-- 2. Crear funció per validar events de Festes de Primavera
CREATE OR REPLACE FUNCTION validate_festes_primavera()
RETURNS TRIGGER AS $$
BEGIN
    -- Si és un event de Festes de Primavera, aplicar restriccions específiques
    IF NEW.tipus_competicio = 'festes_primavera' THEN
        -- Quota d'inscripció ha de ser 0 (gratuït)
        IF NEW.quota_inscripcio IS NOT NULL AND NEW.quota_inscripcio != 0 THEN
            RAISE EXCEPTION 'Els events de Festes de Primavera han de ser gratuïts (quota_inscripcio = 0)';
        END IF;

        -- Forçar quota a 0
        NEW.quota_inscripcio := 0;

        -- No hi ha límit de participants
        NEW.max_participants := NULL;

        -- Format ha de ser eliminatoria_simple per defecte
        IF NEW.format_joc IS NULL THEN
            NEW.format_joc := 'eliminatoria_simple';
        END IF;

        RAISE NOTICE 'Event de Festes de Primavera validat: quota=0, sense límit participants';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Crear trigger per validar events de Festes de Primavera
DROP TRIGGER IF EXISTS validate_festes_primavera_trigger ON events;
CREATE TRIGGER validate_festes_primavera_trigger
    BEFORE INSERT OR UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION validate_festes_primavera();

-- 4. Crear taula específica per configuració de Festes de Primavera
CREATE TABLE IF NOT EXISTS configuracio_festes_primavera (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE UNIQUE,

    -- Configuració específica de portes obertes
    jornada_portes_obertes BOOLEAN DEFAULT true,
    hora_inici_portes_obertes TIME DEFAULT '10:00',
    hora_fi_portes_obertes TIME DEFAULT '20:00',

    -- Configuració del torneig
    modalitat_principal TEXT NOT NULL DEFAULT 'tres_bandes'
        CHECK (modalitat_principal IN ('tres_bandes', 'lliure', 'banda')),
    distancia_caramboles INTEGER NOT NULL DEFAULT 20,
    max_entrades INTEGER NOT NULL DEFAULT 50,

    -- Premiació
    trofeus_previstos INTEGER DEFAULT 3,
    premis_especials TEXT[],

    -- Logística
    taules_reservades INTEGER DEFAULT 0, -- 0 = utilitzar totes les disponibles
    organitzadors TEXT[],
    observacions_especials TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Crear taula per eliminatòries de Festes de Primavera
CREATE TABLE IF NOT EXISTS eliminatories_festes_primavera (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    ronda TEXT NOT NULL, -- '1/32', '1/16', '1/8', 'quarts', 'semifinals', 'final'
    posicio_bracket INTEGER NOT NULL,
    jugador_id UUID REFERENCES socis(id) ON DELETE SET NULL,

    -- Estat de l'eliminatòria
    estat TEXT DEFAULT 'pendent' CHECK (estat IN ('pendent', 'actiu', 'eliminat', 'classificat', 'campió')),

    -- Partida associada
    match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
    adversari_id UUID REFERENCES socis(id) ON DELETE SET NULL,
    resultat TEXT, -- 'guanyador' | 'perdedor' | null

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT eliminatories_festes_primavera_unique
        UNIQUE (event_id, ronda, posicio_bracket)
);

-- 6. Crear índexs per optimitzar consultes
CREATE INDEX IF NOT EXISTS idx_configuracio_festes_primavera_event_id
    ON configuracio_festes_primavera(event_id);

CREATE INDEX IF NOT EXISTS idx_eliminatories_festes_primavera_event_id
    ON eliminatories_festes_primavera(event_id);

CREATE INDEX IF NOT EXISTS idx_eliminatories_festes_primavera_ronda
    ON eliminatories_festes_primavera(event_id, ronda);

-- 7. RLS per les noves taules
ALTER TABLE configuracio_festes_primavera ENABLE ROW LEVEL SECURITY;
ALTER TABLE eliminatories_festes_primavera ENABLE ROW LEVEL SECURITY;

-- Polítiques de lectura (tothom pot veure)
CREATE POLICY "Configuració Festes Primavera visible per tots"
    ON configuracio_festes_primavera FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Eliminatòries Festes Primavera visibles per tots"
    ON eliminatories_festes_primavera FOR SELECT
    USING (auth.role() = 'authenticated');

-- Polítiques d'escriptura (només admins)
CREATE POLICY "Només admins poden gestionar configuració Festes Primavera"
    ON configuracio_festes_primavera FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.admins a
            WHERE a.email = auth.email()
        )
    );

CREATE POLICY "Només admins poden gestionar eliminatòries Festes Primavera"
    ON eliminatories_festes_primavera FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.admins a
            WHERE a.email = auth.email()
        )
    );

-- 8. Triggers per actualitzar timestamps
CREATE TRIGGER update_configuracio_festes_primavera_timestamp
    BEFORE UPDATE ON configuracio_festes_primavera
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- 9. Funció auxiliar per crear event de Festes de Primavera
CREATE OR REPLACE FUNCTION create_festes_primavera_event(
    p_nom TEXT,
    p_temporada TEXT,
    p_modalitat TEXT DEFAULT 'tres_bandes',
    p_data_inici DATE DEFAULT NULL,
    p_data_fi DATE DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    new_event_id UUID;
BEGIN
    -- Crear l'event principal
    INSERT INTO events (
        nom,
        temporada,
        modalitat,
        tipus_competicio,
        format_joc,
        estat_competicio,
        data_inici,
        data_fi,
        quota_inscripcio,
        max_participants,
        actiu
    ) VALUES (
        p_nom,
        p_temporada,
        p_modalitat::TEXT,
        'festes_primavera',
        'eliminatoria_simple',
        'planificacio',
        p_data_inici,
        p_data_fi,
        0, -- Sempre gratuït
        NULL, -- Sense límit
        true
    ) RETURNING id INTO new_event_id;

    -- Crear configuració específica
    INSERT INTO configuracio_festes_primavera (
        event_id,
        modalitat_principal,
        distancia_caramboles
    ) VALUES (
        new_event_id,
        p_modalitat,
        CASE
            WHEN p_modalitat = 'tres_bandes' THEN 20
            WHEN p_modalitat = 'lliure' THEN 60
            WHEN p_modalitat = 'banda' THEN 50
            ELSE 20
        END
    );

    RAISE NOTICE 'Event de Festes de Primavera creat: %', new_event_id;
    RETURN new_event_id;
END;
$$ LANGUAGE plpgsql;

-- 10. Comentaris de documentació
COMMENT ON TABLE configuracio_festes_primavera IS
    'Configuració específica per events de Festes de Primavera del Foment Martinenc';

COMMENT ON TABLE eliminatories_festes_primavera IS
    'Sistema d''eliminatòries per al torneig de Festes de Primavera';

COMMENT ON FUNCTION create_festes_primavera_event IS
    'Funció auxiliar per crear events de Festes de Primavera amb configuració correcta';

COMMIT;