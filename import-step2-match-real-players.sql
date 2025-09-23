-- ================================================================
-- IMPORTACIÓ CLASSIFICACIONS AMB MATCHING DE JUGADORS REALS
-- Executar després de import-step1-events-categories-FIXED.sql
-- ================================================================

-- PRIMER: Veure quins jugadors reals tenim a la base de dades
SELECT
    numero_soci,
    nom,
    email,
    mitjana,
    estat,
    club,
    UPPER(TRIM(nom)) as nom_upper
FROM players
ORDER BY numero_soci;

-- ================================================================
-- FUNCIONS AUXILIARS PER MATCHING
-- ================================================================

-- Habilitar l'extensió de similitud si no ho està
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Funció per obtenir l'ID d'un event
CREATE OR REPLACE FUNCTION get_event_id(temporada_param text, modalitat_param text)
RETURNS uuid AS $$
DECLARE
    event_uuid uuid;
BEGIN
    SELECT id INTO event_uuid
    FROM events
    WHERE temporada = temporada_param
      AND modalitat = modalitat_param
      AND tipus_competicio = 'lliga_social';

    IF event_uuid IS NULL THEN
        RAISE EXCEPTION 'Event no trobat: % - %', temporada_param, modalitat_param;
    END IF;

    RETURN event_uuid;
END;
$$ LANGUAGE plpgsql;

-- Funció per obtenir l'ID d'una categoria
CREATE OR REPLACE FUNCTION get_categoria_id(event_uuid uuid, categoria_nom text)
RETURNS uuid AS $$
DECLARE
    categoria_uuid uuid;
BEGIN
    SELECT id INTO categoria_uuid
    FROM categories
    WHERE event_id = event_uuid
      AND nom = categoria_nom;

    IF categoria_uuid IS NULL THEN
        RAISE EXCEPTION 'Categoria no trobada: %', categoria_nom;
    END IF;

    RETURN categoria_uuid;
END;
$$ LANGUAGE plpgsql;

-- Funció per buscar jugador per nom amb fuzzy matching (sense camp cognom)
CREATE OR REPLACE FUNCTION find_player_by_name(nom_excel text)
RETURNS TABLE(player_id uuid, nom text, numero_soci integer, similarity_score float) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id as player_id,
        p.nom,
        p.numero_soci,
        similarity(UPPER(TRIM(nom_excel)), UPPER(TRIM(p.nom))) as similarity_score
    FROM players p
    WHERE similarity(UPPER(TRIM(nom_excel)), UPPER(TRIM(p.nom))) > 0.3  -- Threshold mínim de similitud
    ORDER BY similarity_score DESC
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- TAULA TEMPORAL AMB DADES EXCEL REALS
-- ================================================================

-- Crear taula temporal amb les classificacions Excel originals
CREATE TEMP TABLE temp_excel_classificacions AS
WITH excel_data AS (
    -- Aquí posarem les dades Excel reals que tens
    SELECT * FROM (VALUES
        -- 3 BANDES 2025 - 1a Categoria
        (2025, 'tres_bandes', '1a Categoria', 1, 'A. GÓMEZ', 22, 236, 475, 0.4968421053, 0.8),
        (2025, 'tres_bandes', '1a Categoria', 2, 'J.F. SANTOS', 18, 218, 480, 0.4541666667, 0.7692307692),
        (2025, 'tres_bandes', '1a Categoria', 3, 'R. CERVANTES', 18, 213, 546, 0.3901098901, 0.5882352941),
        (2025, 'tres_bandes', '1a Categoria', 4, 'J.M. CAMPOS', 17, 217, 506, 0.4288537549, 0.7407407407),
        (2025, 'tres_bandes', '1a Categoria', 5, 'L. CHUECOS', 16, 199, 512, 0.388671875, 0.6896551724),
        (2025, 'tres_bandes', '1a Categoria', 6, 'J. COMAS', 13, 177, 582, 0.3041237113, 0.4651162791),
        (2025, 'tres_bandes', '1a Categoria', 7, 'A. BOIX', 10, 184, 555, 0.3315315315, 0.5555555556),
        (2025, 'tres_bandes', '1a Categoria', 8, 'J. RODRÍGUEZ', 9, 144, 565, 0.2548672566, 0.5128205128),
        (2025, 'tres_bandes', '1a Categoria', 9, 'A. MELGAREJO', 8, 156, 520, 0.3, 0.5),
        (2025, 'tres_bandes', '1a Categoria', 10, 'P. ÁLVAREZ', 7, 151, 537, 0.2811918063, 0.38),
        -- Afegir més dades aquí...

        -- NOTA: Aquí hauries d'afegir tots els jugadors de les classificacions Excel
        -- Per ara pose només alguns exemples per mostrar el procés

        -- 3 BANDES 2025 - 2a Categoria (exemples)
        (2025, 'tres_bandes', '2a Categoria', 1, 'M. FERRER', 20, 189, 378, 0.5, 0.75),
        (2025, 'tres_bandes', '2a Categoria', 2, 'P. MARTÍN', 18, 175, 390, 0.4487179487, 0.72),

        -- LLIURE 2025 - 1a Categoria (exemples)
        (2025, 'lliure', '1a Categoria', 1, 'A. GÓMEZ', 24, 720, 1200, 0.6, 0.85),
        (2025, 'lliure', '1a Categoria', 2, 'J.F. SANTOS', 22, 680, 1180, 0.5762711864, 0.78)

    ) AS data(any, modalitat, categoria, posicio, jugador_excel, punts, caramboles, entrades, mitjana_general, mitjana_particular)
)
SELECT
    any,
    modalitat,
    categoria,
    posicio,
    jugador_excel,
    punts,
    caramboles,
    entrades,
    mitjana_general,
    mitjana_particular
FROM excel_data;

-- ================================================================
-- ANÀLISI DE MATCHING
-- ================================================================

-- Veure quins jugadors Excel es poden assignar a socis reals
SELECT
    e.jugador_excel,
    e.modalitat,
    e.categoria,
    e.posicio,
    p.player_id,
    p.nom as nom_real,
    p.numero_soci,
    ROUND(p.similarity_score::numeric, 3) as similitud
FROM temp_excel_classificacions e
CROSS JOIN LATERAL find_player_by_name(e.jugador_excel) p
WHERE p.similarity_score > 0.5  -- Només mostrar matches amb bona similitud
ORDER BY e.jugador_excel, p.similarity_score DESC;

-- ================================================================
-- MAPPING MANUAL (EDITAR SEGONS RESULTAT DE L'ANÀLISI)
-- ================================================================

-- Taula per mapping manual dels jugadors que no tenen match automàtic
CREATE TEMP TABLE manual_player_mapping (
    jugador_excel TEXT,
    player_id UUID,
    numero_soci INTEGER,
    notes TEXT
);

-- Aquí hauries d'inserir els mappings manuals
-- Exemple:
-- INSERT INTO manual_player_mapping VALUES
-- ('A. GÓMEZ', '12345678-1234-1234-1234-123456789012', 101, 'Match confirmat manualment'),
-- ('J.F. SANTOS', '87654321-4321-4321-4321-210987654321', 205, 'Nom complet: Juan Francisco Santos');

-- ================================================================
-- IMPORTACIÓ FINAL DE CLASSIFICACIONS
-- ================================================================

-- Aquesta part s'executaria només després d'haver fet els mappings manuals
/*
DO $$
DECLARE
    excel_record RECORD;
    event_uuid UUID;
    categoria_uuid UUID;
    mapped_player_id UUID;
    temporada_text TEXT;
BEGIN
    FOR excel_record IN
        SELECT * FROM temp_excel_classificacions
    LOOP
        -- Convertir any a temporada
        temporada_text := (excel_record.any - 1)::text || '-' || excel_record.any::text;

        -- Obtenir event i categoria IDs
        event_uuid := get_event_id(temporada_text, excel_record.modalitat);
        categoria_uuid := get_categoria_id(event_uuid, excel_record.categoria);

        -- Buscar player_id (primer manual, després automàtic)
        SELECT player_id INTO mapped_player_id
        FROM manual_player_mapping
        WHERE jugador_excel = excel_record.jugador_excel;

        IF mapped_player_id IS NULL THEN
            -- Buscar automàticament amb threshold alt
            SELECT player_id INTO mapped_player_id
            FROM find_player_by_name(excel_record.jugador_excel)
            WHERE similarity_score > 0.8
            LIMIT 1;
        END IF;

        -- Inserir classificació només si hem trobat un match
        IF mapped_player_id IS NOT NULL THEN
            INSERT INTO classificacions (
                event_id,
                categoria_id,
                player_id,
                posicio,
                punts,
                caramboles_favor,
                caramboles_contra,
                mitjana_particular,
                partides_jugades,
                partides_guanyades,
                partides_perdudes
            ) VALUES (
                event_uuid,
                categoria_uuid,
                mapped_player_id,
                excel_record.posicio,
                excel_record.punts,
                excel_record.caramboles,
                excel_record.entrades - excel_record.caramboles, -- Aproximació
                excel_record.mitjana_particular,
                excel_record.punts + 10, -- Aproximació partides jugades
                excel_record.punts, -- Aproximació partides guanyades = punts
                10 - excel_record.punts -- Aproximació partides perdudes
            );

            RAISE NOTICE 'Importat: % (%) -> %',
                excel_record.jugador_excel,
                excel_record.posicio,
                (SELECT nom FROM players WHERE id = mapped_player_id);
        ELSE
            RAISE WARNING 'No s''ha trobat match per: %', excel_record.jugador_excel;
        END IF;
    END LOOP;
END $$;
*/

-- ================================================================
-- NETEJA
-- ================================================================

-- Comentat per ara per no esborrar les funcions mentre fem l'anàlisi
/*
DROP FUNCTION IF EXISTS get_event_id(text, text);
DROP FUNCTION IF EXISTS get_categoria_id(uuid, text);
DROP FUNCTION IF EXISTS find_player_by_name(text);
*/

-- ================================================================
-- INSTRUCCIONS D'ÚS
-- ================================================================

-- 1. Executa aquest script per veure l'anàlisi de matching
-- 2. Revisa els resultats de la consulta "ANÀLISI DE MATCHING"
-- 3. Afegeix mappings manuals a la taula manual_player_mapping per jugadors que no tenen match automàtic
-- 4. Descomenta i executa la secció "IMPORTACIÓ FINAL DE CLASSIFICACIONS"
-- 5. Descomenta la secció "NETEJA" quan hagis acabat