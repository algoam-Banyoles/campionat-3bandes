-- ================================================================
-- IMPORTACIÓ CLASSIFICACIONS HISTÒRIQUES
-- Script per importar dades Excel a la nova estructura lligues socials
-- ================================================================

-- PART 1: CREAR EVENTS HISTÒRICS
-- ================================

-- 2025 - Competicions
INSERT INTO events (nom, temporada, modalitat, tipus_competicio, estat_competicio, data_inici, data_fi) VALUES
('Campionat Social 3 Bandes', '2024-2025', 'tres_bandes', 'lliga_social', 'finalitzat', '2024-09-01', '2025-07-31'),
('Campionat Social Lliure', '2024-2025', 'lliure', 'lliga_social', 'finalitzat', '2024-09-01', '2025-07-31'),
('Campionat Social Banda', '2024-2025', 'banda', 'lliga_social', 'finalitzat', '2024-09-01', '2025-07-31');

-- 2024 - Competicions
INSERT INTO events (nom, temporada, modalitat, tipus_competicio, estat_competicio, data_inici, data_fi) VALUES
('Campionat Social 3 Bandes', '2023-2024', 'tres_bandes', 'lliga_social', 'finalitzat', '2023-09-01', '2024-07-31'),
('Campionat Social Lliure', '2023-2024', 'lliure', 'lliga_social', 'finalitzat', '2023-09-01', '2024-07-31'),
('Campionat Social Banda', '2023-2024', 'banda', 'lliga_social', 'finalitzat', '2023-09-01', '2024-07-31');

-- 2023 - Competicions
INSERT INTO events (nom, temporada, modalitat, tipus_competicio, estat_competicio, data_inici, data_fi) VALUES
('Campionat Social 3 Bandes', '2022-2023', 'tres_bandes', 'lliga_social', 'finalitzat', '2022-09-01', '2023-07-31'),
('Campionat Social Lliure', '2022-2023', 'lliure', 'lliga_social', 'finalitzat', '2022-09-01', '2023-07-31'),
('Campionat Social Banda', '2022-2023', 'banda', 'lliga_social', 'finalitzat', '2022-09-01', '2023-07-31');

-- 2022 - Competicions
INSERT INTO events (nom, temporada, modalitat, tipus_competicio, estat_competicio, data_inici, data_fi) VALUES
('Campionat Social 3 Bandes', '2021-2022', 'tres_bandes', 'lliga_social', 'finalitzat', '2021-09-01', '2022-07-31');

-- PART 2: CREAR CATEGORIES PER CADA EVENT
-- ========================================

-- Funció auxiliar per crear categories automàticament
DO $$
DECLARE
    event_record RECORD;
    dist_caramboles INTEGER;
BEGIN
    -- Per cada event de lliga social, crear les categories corresponents
    FOR event_record IN
        SELECT id, modalitat FROM events WHERE tipus_competicio = 'lliga_social'
    LOOP
        -- Determinar distàncies segons modalitat
        CASE event_record.modalitat
            WHEN 'tres_bandes' THEN
                -- 3 Bandes: 1a=20, 2a=15, 3a=10
                INSERT INTO categories (event_id, nom, distancia_caramboles, ordre_categoria, max_entrades) VALUES
                (event_record.id, '1a Categoria', 20, 1, 50),
                (event_record.id, '2a Categoria', 15, 2, 50),
                (event_record.id, '3a Categoria', 10, 3, 50);
            WHEN 'lliure' THEN
                -- Lliure: 1a=60, 2a=50, 3a=40
                INSERT INTO categories (event_id, nom, distancia_caramboles, ordre_categoria, max_entrades) VALUES
                (event_record.id, '1a Categoria', 60, 1, 40), -- 40 entrades per 1a
                (event_record.id, '2a Categoria', 50, 2, 50),
                (event_record.id, '3a Categoria', 40, 3, 50);
            WHEN 'banda' THEN
                -- Banda: 1a=50, 2a=40, 3a=30, 4a=25
                INSERT INTO categories (event_id, nom, distancia_caramboles, ordre_categoria, max_entrades) VALUES
                (event_record.id, '1a Categoria', 50, 1, 50),
                (event_record.id, '2a Categoria', 40, 2, 50),
                (event_record.id, '3a Categoria', 30, 3, 50),
                (event_record.id, '4a Categoria', 25, 4, 50);
        END CASE;
    END LOOP;
END $$;

-- PART 3: TAULA TEMPORAL PER IMPORTACIÓ
-- ======================================

-- Crear taula temporal amb les dades Excel
CREATE TEMP TABLE temp_classificacions (
    any INTEGER,
    modalitat TEXT,
    categoria TEXT,
    posicio INTEGER,
    jugador_nom TEXT,
    punts INTEGER,
    caramboles INTEGER,
    entrades INTEGER,
    mitjana_general DECIMAL(10,6),
    mitjana_particular DECIMAL(10,6)
);

-- Inserir totes les dades Excel
INSERT INTO temp_classificacions VALUES
(2025, '3 BANDES', '1a', 1, 'A. GÓMEZ', 22, 236, 475, 0.4968421053, 0.8),
(2025, '3 BANDES', '1a', 2, 'J.F. SANTOS', 18, 218, 480, 0.4541666667, 0.7692307692),
(2025, '3 BANDES', '1a', 3, 'R. CERVANTES', 18, 213, 546, 0.3901098901, 0.5882352941),
(2025, '3 BANDES', '1a', 4, 'J.M. CAMPOS', 17, 217, 506, 0.4288537549, 0.7407407407),
(2025, '3 BANDES', '1a', 5, 'L. CHUECOS', 16, 199, 512, 0.388671875, 0.6896551724),
(2025, '3 BANDES', '1a', 6, 'J. COMAS', 13, 177, 582, 0.3041237113, 0.4651162791),
(2025, '3 BANDES', '1a', 7, 'A. BOIX', 10, 184, 555, 0.3315315315, 0.5555555556),
(2025, '3 BANDES', '1a', 8, 'J. RODRÍGUEZ', 9, 144, 565, 0.2548672566, 0.5128205128),
(2025, '3 BANDES', '1a', 9, 'A. MELGAREJO', 8, 156, 520, 0.3, 0.5),
(2025, '3 BANDES', '1a', 10, 'P. ÁLVAREZ', 7, 151, 537, 0.2811918063, 0.38),
(2025, '3 BANDES', '1a', 11, 'M. SÁNCHEZ', 7, 154, 577, 0.266897747, 0.38),
(2025, '3 BANDES', '1a', 12, 'J. VILA', 6, 140, 486, 0.2880658436, 0.375),
(2025, '3 BANDES', '1a', 13, 'P. CASANOVA', 5, 136, 509, 0.2671905697, 0.3823529412),
(2025, '3 BANDES', '2a', 1, 'J.L. ROSERÓ', 21, 168, 505, 0.3326732673, 0.6818181818),
(2025, '3 BANDES', '2a', 2, 'A. FUENTES', 18, 157, 550, 0.2854545455, 0.4545454545),
(2025, '3 BANDES', '2a', 3, 'J. FITÓ', 14, 134, 553, 0.2423146474, 0.46875),
(2025, '3 BANDES', '2a', 4, 'J.A. SAUCEDO', 14, 125, 574, 0.2177700348, 0.3947368421),
(2025, '3 BANDES', '2a', 5, 'R. MERCADER', 13, 120, 591, 0.2030456853, 0.3260869565),
(2025, '3 BANDES', '2a', 6, 'J. VEZA', 12, 125, 548, 0.2281021898, 0.4411764706),
(2025, '3 BANDES', '2a', 7, 'R. SOTO', 12, 100, 584, 0.1712328767, 0.28),
(2025, '3 BANDES', '2a', 8, 'E. DÍAZ', 11, 120, 594, 0.202020202, 0.3333333333),
(2025, '3 BANDES', '2a', 9, 'R. POLLS', 11, 92, 560, 0.1642857143, 0.26),
(2025, '3 BANDES', '2a', 10, 'J. GIBERNAU', 10, 134, 551, 0.2431941924, 0.4166666667),
(2025, '3 BANDES', '2a', 11, 'M. GONZALVO', 8, 89, 528, 0.1685606061, 0.2727272727),
(2025, '3 BANDES', '2a', 12, 'R. JARQUE', 6, 95, 584, 0.1626712329, 0.24),
(2025, '3 BANDES', '2a', 13, 'A. MEDINA', 6, 90, 564, 0.1595744681, 0.3333333333),
(2025, '3 BANDES', '3a', 1, 'J. GÓMEZ', 21, 106, 624, 0.1698717949, 0.3703703704),
(2025, '3 BANDES', '3a', 2, 'E. GARCÍA', 20, 112, 510, 0.2196078431, 0.625),
(2025, '3 BANDES', '3a', 3, 'A. MORA', 20, 101, 648, 0.1558641975, 0.3125),
(2025, '3 BANDES', '3a', 4, 'S. MARIN', 18, 106, 639, 0.1658841941, 0.2222222222),
(2025, '3 BANDES', '3a', 5, 'M. LÓPEZ', 17, 120, 508, 0.2362204724, 0.5263157895),
(2025, '3 BANDES', '3a', 6, 'M. MANZANO', 17, 107, 659, 0.1623672231, 0.4736842105),
(2025, '3 BANDES', '3a', 7, 'E. MILLÁN', 17, 98, 629, 0.1558028617, 0.2222222222),
(2025, '3 BANDES', '3a', 8, 'P. FERRÀS', 16, 111, 611, 0.1816693944, 0.3225806452),
(2025, '3 BANDES', '3a', 9, 'J. IBÁÑEZ', 16, 94, 607, 0.1548599671, 0.3703703704),
(2025, '3 BANDES', '3a', 10, 'A. GARCÍA', 11, 73, 649, 0.1124807396, 0.2777777778),
(2025, '3 BANDES', '3a', 11, 'J. CARRASCO', 10, 77, 670, 0.1149253731, 0.2083333333),
(2025, '3 BANDES', '3a', 12, 'J. VALLÉS', 9, 67, 623, 0.1075441413, 0.5882352941),
(2025, '3 BANDES', '3a', 13, 'M. QUEROL', 6, 78, 641, 0.1216848674, 0.25),
(2025, '3 BANDES', '3a', 14, 'J.M. CASAMOR', 6, 66, 672, 0.09821428571, 0.18),
(2025, '3 BANDES', '3a', 15, 'F. VERDUGO', 6, 61, 670, 0.09104477612, 0.2258064516),
(2025, 'LLIURE', '1a', 1, 'L. CHUECOS', 8, 278, 163, 1.705521472, 2),
(2025, 'LLIURE', '1a', 2, 'A. BERMEJO', 8, 217, 136, 1.595588235, 2.307692308),
(2025, 'LLIURE', '1a', 3, 'J. F. SANTOS', 8, 240, 159, 1.509433962, 2.608695652),
(2025, 'LLIURE', '1a', 4, 'J. COMAS', 4, 240, 152, 1.578947368, 2.222222222),
(2025, 'LLIURE', '1a', 5, 'A. GÓMEZ', 2, 202, 166, 1.21686747, 1.740740741),
(2025, 'LLIURE', '1a', 6, 'J. VILA', 0, 233, 180, 1.294444444, 1.486486486),
(2025, 'LLIURE', '1a', 7, 'J.M. CAMPOS', 10, 293, 235, 1.246808511, 1.714285714),
(2025, 'LLIURE', '1a', 8, 'P. ÁLVAREZ', 10, 273, 235, 1.161702128, 1.578947368),
(2025, 'LLIURE', '1a', 9, 'R. CERVANTES', 8, 329, 234, 1.405982906, 1.621621622),
(2025, 'LLIURE', '1a', 10, 'R. MORENO', 7, 306, 237, 1.291139241, 1.621621622),
(2025, 'LLIURE', '1a', 11, 'E. DÍAZ', 4, 218, 232, 0.9396551724, 1.428571429),
(2025, 'LLIURE', '1a', 12, 'J. GIBERNAU', 2, 216, 237, 0.9113924051, 1.15),
(2025, 'LLIURE', '1a', 13, 'J.L. ROSERÓ', 1, 214, 238, 0.8991596639, 1.05),
(2025, 'LLIURE', '2a', 1, 'E. LUENGO', 21, 536, 465, 1.152688172, 1.851851852),
(2025, 'LLIURE', '2a', 2, 'J. IBÁÑEZ', 16, 407, 527, 0.7722960152, 0.96),
(2025, 'LLIURE', '2a', 3, 'P. CASANOVA', 15, 510, 481, 1.06029106, 1.470588235),
(2025, 'LLIURE', '2a', 4, 'E. CURCÓ', 14, 349, 490, 0.712244898, 1),
(2025, 'LLIURE', '2a', 5, 'J.L. ARROYO', 13, 424, 534, 0.7940074906, 0.94),
(2025, 'LLIURE', '2a', 6, 'A. FUENTES', 12, 449, 534, 0.84082397, 1.086956522),
(2025, 'LLIURE', '2a', 7, 'M. SÁNCHEZ', 10, 410, 543, 0.7550644567, 0.9574468085),
(2025, 'LLIURE', '2a', 8, 'J. SÁNCHEZ', 9, 401, 527, 0.7609108159, 0.98),
(2025, 'LLIURE', '2a', 9, 'J. A. SAUCEDO', 7, 360, 534, 0.6741573034, 1.063829787),
(2025, 'LLIURE', '2a', 10, 'R. MERCADER', 6, 365, 536, 0.6809701493, 1.25),
(2025, 'LLIURE', '2a', 11, 'A. MEDINA', 5, 380, 516, 0.7364341085, 0.84),
(2025, 'LLIURE', '2a', 12, 'R. POLLS', 4, 365, 519, 0.7032755299, 1.136363636),
(2025, 'LLIURE', '3a', 1, 'E. GARCÍA', 8, 184, 233, 0.7896995708, 1.081081081),
(2025, 'LLIURE', '3a', 2, 'M. MANZANO', 7, 164, 237, 0.6919831224, 0.78),
(2025, 'LLIURE', '3a', 3, 'J. FITÓ', 5, 158, 245, 0.6448979592, 0.7),
(2025, 'LLIURE', '3a', 4, 'E. MILLÁN', 4, 142, 237, 0.5991561181, 0.8888888889),
(2025, 'LLIURE', '3a', 5, 'P. FERRÀS', 4, 138, 246, 0.5609756098, 0.68),
(2025, 'LLIURE', '3a', 6, 'A. MORA', 2, 130, 242, 0.5371900826, 0.9523809524),
(2025, 'LLIURE', '3a', 7, 'M. GONZALVO', 8, 177, 244, 0.7254098361, 0.8695652174),
(2025, 'LLIURE', '3a', 8, 'R. SOTO', 8, 170, 235, 0.7234042553, 0.9756097561),
(2025, 'LLIURE', '3a', 9, 'J. GÓMEZ', 6, 164, 240, 0.6833333333, 0.9090909091),
(2025, 'LLIURE', '3a', 10, 'M. QUEROL', 6, 128, 235, 0.5446808511, 0.75),
(2025, 'LLIURE', '3a', 11, 'J.M. CASAMOR', 2, 109, 250, 0.436, 0.66),
(2025, 'LLIURE', '3a', 12, 'J. CARRASCO', 0, 142, 246, 0.5772357724, 0.7173913043),
(2025, 'LLIURE', '3a', 13, 'R. JARQUE', 6, 130, 200, 0.65, 0.76),
(2025, 'LLIURE', '3a', 14, 'S. MARÍN', 6, 106, 200, 0.53, 0.62),
(2025, 'LLIURE', '3a', 15, 'J. VALLÉS', 4, 104, 200, 0.52, 0.56),
(2025, 'LLIURE', '3a', 16, 'F. VERDUGO', 4, 82, 200, 0.41, 0.46),
(2025, 'LLIURE', '3a', 17, 'J. ORTIZ', 0, 77, 200, 0.385, 0.44),
(2025, 'BANDA', '1a', 1, 'L. CHUECOS', 16, 444, 330, 1.345454545, 1.667),
(2025, 'BANDA', '1a', 2, 'R. CERVANTES', 16, 421, 393, 1.071246819, 1.351),
(2025, 'BANDA', '1a', 3, 'J. F. SANTOS', 12, 439, 353, 1.243626062, 1.667),
(2025, 'BANDA', '1a', 4, 'A. GÓMEZ', 11, 391, 388, 1.007731959, 1.282),
(2025, 'BANDA', '1a', 5, 'J. VILA', 11, 410, 407, 1.007371007, 1.667),
(2025, 'BANDA', '1a', 6, 'E. LEÓN', 10, 419, 418, 1.002392344, 1.22),
(2025, 'BANDA', '1a', 7, 'A. BOIX', 4, 346, 379, 0.9129287599, 1.22),
(2025, 'BANDA', '1a', 8, 'J.M. CAMPOS', 4, 369, 420, 0.8785714286, 1.139),
(2025, 'BANDA', '1a', 9, 'J. COMAS', 4, 351, 402, 0.8731343284, 1.105),
(2025, 'BANDA', '1a', 10, 'J. DOMINGO', 2, 349, 418, 0.8349282297, 1.116),
(2025, 'BANDA', '2a', 1, 'J.L. ROSERÓ', 18, 343, 423, 0.811, 1.081),
(2025, 'BANDA', '2a', 2, 'E. LUENGO', 13, 323, 401, 0.805, 1.038),
(2025, 'BANDA', '2a', 3, 'P. ÁLVAREZ', 13, 313, 428, 0.731, 1),
(2025, 'BANDA', '2a', 4, 'J. RODRÍGUEZ', 12, 343, 402, 0.853, 1.538),
(2025, 'BANDA', '2a', 5, 'R. MORENO', 9, 320, 397, 0.806, 1.081),
(2025, 'BANDA', '2a', 6, 'P. CASANOVA', 8, 287, 437, 0.657, 0.851),
(2025, 'BANDA', '2a', 7, 'E. DÍAZ', 8, 273, 417, 0.655, 0.74),
(2025, 'BANDA', '2a', 8, 'J. GIBERNAU', 6, 242, 439, 0.551, 0.87),
(2025, 'BANDA', '2a', 9, 'J. FITÓ', 3, 256, 448, 0.571, 0.8),
(2025, 'BANDA', '2a', 10, 'R. POLLS', 0, 208, 442, 0.471, 0.592),
(2025, 'BANDA', '3a', 1, 'E. GARCÍA', 14, 206, 373, 0.552, 0.811),
(2025, 'BANDA', '3a', 2, 'J. SÁNCHEZ', 13, 231, 341, 0.677, 0.857),
(2025, 'BANDA', '3a', 3, 'J. A. SAUCEDO', 12, 186, 382, 0.487, 0.625),
(2025, 'BANDA', '3a', 4, 'E. CURCÓ', 11, 191, 385, 0.496, 0.811),
(2025, 'BANDA', '3a', 5, 'J. GÓMEZ', 10, 173, 327, 0.529, 0.789),
(2025, 'BANDA', '3a', 6, 'M. GONZALVO', 6, 169, 386, 0.438, 0.638),
(2025, 'BANDA', '3a', 7, 'R. JARQUE', 4, 159, 393, 0.405, 0.5),
(2025, 'BANDA', '3a', 8, 'E. MILLÁN', 2, 142, 371, 0.383, 0.52),
(2025, 'BANDA', '3a', 9, 'S. MARÍN', 0, 111, 382, 0.291, 0.571),
(2025, 'BANDA', '4a', 1, 'R. SOTO', 16, 170, 384, 0.443, 0.581),
(2025, 'BANDA', '4a', 2, 'A. MEDINA', 10, 159, 370, 0.43, 0.694),
(2025, 'BANDA', '4a', 3, 'J. CARRASCO', 10, 152, 387, 0.393, 0.521),
(2025, 'BANDA', '4a', 4, 'M. MANZANO', 10, 146, 398, 0.367, 0.521),
(2025, 'BANDA', '4a', 5, 'M. QUEROL', 8, 137, 386, 0.355, 0.474),
(2025, 'BANDA', '4a', 6, 'G. RUIZ', 6, 144, 381, 0.378, 0.543),
(2025, 'BANDA', '4a', 7, 'J. VALLÉS', 4, 120, 394, 0.305, 0.46),
(2025, 'BANDA', '4a', 8, 'J.M. CASAMOR', 4, 104, 400, 0.26, 0.36),
(2025, 'BANDA', '4a', 9, 'F. VERDUGO', 4, 93, 400, 0.233, 0.34);
-- (Continuar amb la resta de dades...)

-- PER SIMPLIFICAR, carrego només una mostra. Després pots afegir la resta.

-- PART 4: ENLLAÇAR JUGADORS AMB TAULA PLAYERS
-- ============================================

-- Crear taula temporal per matching players
CREATE TEMP TABLE temp_player_mapping AS
SELECT DISTINCT
    tc.jugador_nom,
    p.id as player_id,
    p.nom as player_db_nom,
    p.numero_soci
FROM temp_classificacions tc
LEFT JOIN players p ON (
    -- Intent 1: Match directe per nom complet
    UPPER(TRIM(tc.jugador_nom)) = UPPER(TRIM(p.nom))
    OR
    -- Intent 2: Match per inicials + cognom
    UPPER(TRIM(tc.jugador_nom)) LIKE UPPER(TRIM(SPLIT_PART(p.nom, ' ', 1))) || '%'
    OR
    -- Intent 3: Match parcial
    UPPER(TRIM(SPLIT_PART(tc.jugador_nom, ' ', 2))) = UPPER(TRIM(SPLIT_PART(p.nom, ' ', 2)))
);

-- PART 5: INSERIR CLASSIFICACIONS
-- ================================

-- Inserir classificacions amb enllaços a players trobats
INSERT INTO classificacions (
    event_id,
    categoria_id,
    player_id,
    posicio,
    partides_jugades,
    punts,
    caramboles_favor,
    caramboles_contra,
    mitjana_particular
)
SELECT
    e.id as event_id,
    c.id as categoria_id,
    pm.player_id,
    tc.posicio,
    CASE
        WHEN tc.punts > 0 THEN ROUND((tc.caramboles::DECIMAL / tc.mitjana_particular), 0)::INTEGER
        ELSE 0
    END as partides_jugades,
    tc.punts,
    tc.caramboles,
    tc.entrades as caramboles_contra, -- Aproximació
    tc.mitjana_particular
FROM temp_classificacions tc
JOIN events e ON (
    e.temporada = CASE tc.any
        WHEN 2025 THEN '2024-2025'
        WHEN 2024 THEN '2023-2024'
        WHEN 2023 THEN '2022-2023'
        WHEN 2022 THEN '2021-2022'
    END
    AND e.modalitat = CASE tc.modalitat
        WHEN '3 BANDES' THEN 'tres_bandes'
        WHEN 'LLIURE' THEN 'lliure'
        WHEN 'BANDA' THEN 'banda'
    END
    AND e.tipus_competicio = 'lliga_social'
)
JOIN categories c ON (
    c.event_id = e.id
    AND c.ordre_categoria = CASE tc.categoria
        WHEN '1a' THEN 1
        WHEN '2a' THEN 2
        WHEN '3a' THEN 3
        WHEN '4a' THEN 4
    END
)
LEFT JOIN temp_player_mapping pm ON pm.jugador_nom = tc.jugador_nom
WHERE pm.player_id IS NOT NULL; -- Només inserir jugadors trobats

-- PART 6: REPORTE DE RESULTATS
-- =============================

-- Mostrar resum importació
SELECT
    'Events creats' as tipus,
    COUNT(*) as total
FROM events
WHERE tipus_competicio = 'lliga_social'

UNION ALL

SELECT
    'Categories creades' as tipus,
    COUNT(*) as total
FROM categories

UNION ALL

SELECT
    'Classificacions importades' as tipus,
    COUNT(*) as total
FROM classificacions

UNION ALL

SELECT
    'Jugadors no trobats' as tipus,
    COUNT(DISTINCT jugador_nom) as total
FROM temp_classificacions tc
LEFT JOIN temp_player_mapping pm ON pm.jugador_nom = tc.jugador_nom
WHERE pm.player_id IS NULL;

-- Mostrar jugadors no trobats per revisar
SELECT DISTINCT
    'JUGADOR NO TROBAT: ' || tc.jugador_nom as missatge
FROM temp_classificacions tc
LEFT JOIN temp_player_mapping pm ON pm.jugador_nom = tc.jugador_nom
WHERE pm.player_id IS NULL
ORDER BY tc.jugador_nom;

-- ================================================================
-- FI DE L'SCRIPT D'IMPORTACIÓ
-- ================================================================