-- ================================================================
-- MAPPING MANUAL DE JUGADORS EXCEL -> SOCIS REALS
-- ================================================================

-- PASO 1: Veure jugadors Excel de les classificacions
-- Aquests són els noms que apareixen a les classificacions Excel:

/*
JUGADORS 3 BANDES 2025:
- A. GÓMEZ
- J.F. SANTOS
- R. CERVANTES
- J.M. CAMPOS
- L. CHUECOS
- J. COMAS
- A. BOIX
- J. RODRÍGUEZ
- A. MELGAREJO
- P. ÁLVAREZ
- M. SÁNCHEZ
- J. VILA
- P. CASANOVA
- etc...
*/

-- PASO 2: Mapping manual (editar amb els noms reals i números de soci)
-- Format: ('NOM_EXCEL', numero_soci, 'NOTES')

CREATE TEMP TABLE jugador_mapping AS
SELECT * FROM (VALUES
    -- Exemples - EDITAR AMB DADES REALS:
    ('A. GÓMEZ', 101, 'Antoni Gómez - soci 101'),
    ('J.F. SANTOS', 205, 'Joan Francesc Santos - soci 205'),
    ('R. CERVANTES', 89, 'Ramon Cervantes - soci 89'),
    ('J.M. CAMPOS', 156, 'Josep Maria Campos - soci 156')

    -- AFEGIR TOTS ELS ALTRES JUGADORS AQUÍ...
    -- Format: ('NOM_EXCEL', numero_soci, 'notes_opcionals')

) AS mapping(nom_excel, numero_soci, notes);

-- PASO 3: Verificar el mapping
SELECT
    m.nom_excel,
    m.numero_soci,
    p.nom as nom_real,
    p.email,
    p.mitjana,
    p.estat,
    m.notes
FROM jugador_mapping m
LEFT JOIN players p ON p.numero_soci = m.numero_soci
ORDER BY m.numero_soci;

-- PASO 4: Importar classificacions (executar només quan el mapping estigui complet)
/*
DO $$
DECLARE
    event_2025_3b UUID;
    cat_1a_3b UUID;
    cat_2a_3b UUID;
    -- etc per altres categories...
BEGIN
    -- Obtenir IDs dels events i categories
    SELECT id INTO event_2025_3b FROM events
    WHERE temporada = '2024-2025' AND modalitat = 'tres_bandes';

    SELECT id INTO cat_1a_3b FROM categories
    WHERE event_id = event_2025_3b AND nom = '1a Categoria';

    -- Inserir classificacions 3 BANDES 2025 - 1a Categoria
    INSERT INTO classificacions (event_id, categoria_id, player_id, posicio, punts, caramboles_favor, caramboles_contra, mitjana_particular)
    SELECT
        event_2025_3b,
        cat_1a_3b,
        p.id,
        data.posicio,
        data.punts,
        data.caramboles,
        data.entrades - data.caramboles,
        data.mitjana_particular
    FROM (VALUES
        ('A. GÓMEZ', 1, 22, 236, 475, 0.8),
        ('J.F. SANTOS', 2, 18, 218, 480, 0.769),
        ('R. CERVANTES', 3, 18, 213, 546, 0.588),
        ('J.M. CAMPOS', 4, 17, 217, 506, 0.741)
        -- AFEGIR TOTS ELS ALTRES...
    ) AS data(nom_excel, posicio, punts, caramboles, entrades, mitjana_particular)
    JOIN jugador_mapping m ON m.nom_excel = data.nom_excel
    JOIN players p ON p.numero_soci = m.numero_soci;

END $$;
*/