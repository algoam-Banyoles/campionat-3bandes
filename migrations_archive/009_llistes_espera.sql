-- Migració 009: Sistema de llistes d'espera per competicions

BEGIN;

-- 1. Afegir camp per gestionar llistes d'espera
ALTER TABLE events ADD COLUMN IF NOT EXISTS gestiona_llista_espera boolean DEFAULT false;

-- 2. Taula per llista d'espera
CREATE TABLE IF NOT EXISTS llista_espera (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    soci_id uuid NOT NULL REFERENCES socis(id) ON DELETE CASCADE,
    categoria_preferida_id uuid REFERENCES categories(id) ON DELETE SET NULL,
    data_entrada timestamp with time zone DEFAULT now(),
    prioritat smallint DEFAULT 1, -- 1 = normal, 2 = alta (ex-participant, etc.)

    -- Dades de l'usuari quan es va apuntar (per si canvien després)
    preferencies_dies text[] DEFAULT '{}',
    preferencies_hores text[] DEFAULT '{}',
    restriccions_especials text,
    observacions text,

    -- Gestió de la llista
    notificat boolean DEFAULT false, -- Si se l'ha notificat quan s'ha alliberat una plaça
    data_notificacio timestamp with time zone,
    data_resposta_limit timestamp with time zone,

    created_at timestamp with time zone DEFAULT now(),

    CONSTRAINT llista_espera_event_soci_unique UNIQUE (event_id, soci_id)
);

-- 3. Log d'accions de llista d'espera (per auditoria)
CREATE TABLE IF NOT EXISTS log_llista_espera (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    soci_id uuid NOT NULL REFERENCES socis(id) ON DELETE CASCADE,
    accio text NOT NULL CHECK (accio IN ('afegit', 'eliminat', 'promogut', 'notificat', 'expirat')),
    detalls text,
    data_accio timestamp with time zone DEFAULT now(),
    realitzat_per uuid REFERENCES auth.users(id)
);

-- 4. Crear índexs per optimitzar consultes
CREATE INDEX IF NOT EXISTS idx_llista_espera_event_prioritat ON llista_espera(event_id, prioritat DESC, data_entrada);
CREATE INDEX IF NOT EXISTS idx_llista_espera_notificacions ON llista_espera(event_id, notificat, data_resposta_limit);
CREATE INDEX IF NOT EXISTS idx_log_llista_espera_event ON log_llista_espera(event_id, data_accio DESC);

-- 5. Configurar RLS (Row Level Security)
ALTER TABLE llista_espera ENABLE ROW LEVEL SECURITY;
ALTER TABLE log_llista_espera ENABLE ROW LEVEL SECURITY;

-- 6. Polítiques RLS
CREATE POLICY "Usuaris autenticats poden veure llista d'espera"
    ON llista_espera FOR SELECT TO authenticated USING (true);

CREATE POLICY "Només admins poden gestionar llista d'espera"
    ON llista_espera FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

CREATE POLICY "Usuaris autenticats poden veure log"
    ON log_llista_espera FOR SELECT TO authenticated USING (true);

CREATE POLICY "Només admins poden escriure al log"
    ON log_llista_espera FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM admins WHERE email = auth.jwt() ->> 'email'));

-- 7. Funcions per gestionar llista d'espera

-- Funció per afegir a llista d'espera quan una inscripció es rebutja per falta de places
CREATE OR REPLACE FUNCTION afegir_a_llista_espera(
    p_event_id uuid,
    p_soci_id uuid,
    p_categoria_preferida_id uuid DEFAULT NULL,
    p_preferencies_dies text[] DEFAULT '{}',
    p_preferencies_hores text[] DEFAULT '{}',
    p_restriccions_especials text DEFAULT NULL,
    p_observacions text DEFAULT NULL,
    p_prioritat smallint DEFAULT 1
)
RETURNS uuid AS $$
DECLARE
    v_llista_id uuid;
BEGIN
    -- Inserir a llista d'espera
    INSERT INTO llista_espera (
        event_id,
        soci_id,
        categoria_preferida_id,
        preferencies_dies,
        preferencies_hores,
        restriccions_especials,
        observacions,
        prioritat
    )
    VALUES (
        p_event_id,
        p_soci_id,
        p_categoria_preferida_id,
        p_preferencies_dies,
        p_preferencies_hores,
        p_restriccions_especials,
        p_observacions,
        p_prioritat
    )
    RETURNING id INTO v_llista_id;

    -- Registrar al log
    INSERT INTO log_llista_espera (event_id, soci_id, accio, detalls)
    VALUES (p_event_id, p_soci_id, 'afegit', 'Afegit a llista d''espera amb prioritat ' || p_prioritat);

    RETURN v_llista_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funció per promoure el següent de la llista quan s'allibera una plaça
CREATE OR REPLACE FUNCTION promoure_seguent_llista_espera(
    p_event_id uuid,
    p_categoria_id uuid DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
    v_seguent_record record;
    v_inscripcio_id uuid;
BEGIN
    -- Trobar el següent candidat (per prioritat i data d'entrada)
    SELECT *
    FROM llista_espera le
    JOIN socis s ON le.soci_id = s.id
    WHERE le.event_id = p_event_id
      AND (p_categoria_id IS NULL OR le.categoria_preferida_id = p_categoria_id)
      AND NOT le.notificat
    ORDER BY le.prioritat DESC, le.data_entrada ASC
    LIMIT 1
    INTO v_seguent_record;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Crear inscripció automàticament
    INSERT INTO inscripcions (
        event_id,
        soci_id,
        categoria_assignada_id,
        preferencies_dies,
        preferencies_hores,
        restriccions_especials,
        observacions,
        confirmat,
        pagat
    )
    VALUES (
        p_event_id,
        v_seguent_record.soci_id,
        COALESCE(v_seguent_record.categoria_preferida_id, p_categoria_id),
        v_seguent_record.preferencies_dies,
        v_seguent_record.preferencies_hores,
        v_seguent_record.restriccions_especials,
        v_seguent_record.observacions || ' (Promogut des de llista d''espera)',
        false, -- requereix confirmació
        false  -- requereix pagament
    )
    RETURNING id INTO v_inscripcio_id;

    -- Eliminar de llista d'espera
    DELETE FROM llista_espera WHERE id = v_seguent_record.id;

    -- Registrar al log
    INSERT INTO log_llista_espera (event_id, soci_id, accio, detalls)
    VALUES (p_event_id, v_seguent_record.soci_id, 'promogut', 'Promogut automàticament a inscripció ID: ' || v_inscripcio_id);

    RETURN v_inscripcio_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funció per obtenir estadístiques de llista d'espera
CREATE OR REPLACE FUNCTION get_estadistiques_llista_espera(p_event_id uuid)
RETURNS TABLE (
    total_esperant integer,
    per_prioritat json,
    temps_espera_mitja interval
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::integer as total_esperant,
        json_object_agg(
            CASE prioritat
                WHEN 1 THEN 'normal'
                WHEN 2 THEN 'alta'
                ELSE 'desconeguda'
            END,
            count
        ) as per_prioritat,
        AVG(now() - data_entrada) as temps_espera_mitja
    FROM (
        SELECT
            prioritat,
            COUNT(*) as count,
            data_entrada
        FROM llista_espera
        WHERE event_id = p_event_id
        GROUP BY prioritat, data_entrada
    ) stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Trigger per promoure automàticament quan s'elimina una inscripció
CREATE OR REPLACE FUNCTION trigger_promoure_llista_espera()
RETURNS TRIGGER AS $$
DECLARE
    v_gestiona_llista boolean;
BEGIN
    -- Si s'elimina una inscripció, comprovar si l'event gestiona llista d'espera
    IF TG_OP = 'DELETE' THEN
        SELECT gestiona_llista_espera INTO v_gestiona_llista
        FROM events WHERE id = OLD.event_id;
        
        IF v_gestiona_llista = true THEN
            PERFORM promoure_seguent_llista_espera(OLD.event_id, OLD.categoria_assignada_id);
        END IF;
        
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_inscripcions_deleted_promoure
    AFTER DELETE ON inscripcions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_promoure_llista_espera();

-- 9. Vista per consultes ràpides de llista d'espera
CREATE OR REPLACE VIEW v_llista_espera_detall AS
SELECT
    le.*,
    s.nom,
    s.cognoms,
    s.email,
    s.numero_soci,
    c.nom as categoria_preferida_nom,
    e.nom as event_nom,
    e.modalitat,
    e.temporada,
    ROW_NUMBER() OVER (
        PARTITION BY le.event_id
        ORDER BY le.prioritat DESC, le.data_entrada ASC
    ) as posicio_llista
FROM llista_espera le
JOIN socis s ON le.soci_id = s.id
JOIN events e ON le.event_id = e.id
LEFT JOIN categories c ON le.categoria_preferida_id = c.id;

COMMIT;