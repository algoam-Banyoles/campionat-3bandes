-- ================================================================
-- IMPORTACIÓ PART 1: EVENTS I CATEGORIES
-- Executar primer a l'editor SQL de Supabase
-- ================================================================

-- CREAR EVENTS HISTÒRICS
INSERT INTO events (nom, temporada, modalitat, tipus_competicio, estat_competicio, data_inici, data_fi) VALUES
-- 2025
('Campionat Social 3 Bandes', '2024-2025', 'tres_bandes', 'lliga_social', 'finalitzat', '2024-09-01', '2025-07-31'),
('Campionat Social Lliure', '2024-2025', 'lliure', 'lliga_social', 'finalitzat', '2024-09-01', '2025-07-31'),
('Campionat Social Banda', '2024-2025', 'banda', 'lliga_social', 'finalitzat', '2024-09-01', '2025-07-31'),
-- 2024
('Campionat Social 3 Bandes', '2023-2024', 'tres_bandes', 'lliga_social', 'finalitzat', '2023-09-01', '2024-07-31'),
('Campionat Social Lliure', '2023-2024', 'lliure', 'lliga_social', 'finalitzat', '2023-09-01', '2024-07-31'),
('Campionat Social Banda', '2023-2024', 'banda', 'lliga_social', 'finalitzat', '2023-09-01', '2024-07-31'),
-- 2023
('Campionat Social 3 Bandes', '2022-2023', 'tres_bandes', 'lliga_social', 'finalitzat', '2022-09-01', '2023-07-31'),
('Campionat Social Lliure', '2022-2023', 'lliure', 'lliga_social', 'finalitzat', '2022-09-01', '2023-07-31'),
('Campionat Social Banda', '2022-2023', 'banda', 'lliga_social', 'finalitzat', '2022-09-01', '2023-07-31'),
-- 2022
('Campionat Social 3 Bandes', '2021-2022', 'tres_bandes', 'lliga_social', 'finalitzat', '2021-09-01', '2022-07-31');

-- CREAR CATEGORIES AUTOMÀTICAMENT
DO $$
DECLARE
    event_record RECORD;
BEGIN
    FOR event_record IN
        SELECT id, modalitat FROM events WHERE tipus_competicio = 'lliga_social'
    LOOP
        CASE event_record.modalitat
            WHEN 'tres_bandes' THEN
                INSERT INTO categories (event_id, nom, distancia_caramboles, ordre_categoria, max_entrades) VALUES
                (event_record.id, '1a Categoria', 20, 1, 50),
                (event_record.id, '2a Categoria', 15, 2, 50),
                (event_record.id, '3a Categoria', 10, 3, 50);
            WHEN 'lliure' THEN
                INSERT INTO categories (event_id, nom, distancia_caramboles, ordre_categoria, max_entrades) VALUES
                (event_record.id, '1a Categoria', 60, 1, 40),
                (event_record.id, '2a Categoria', 50, 2, 50),
                (event_record.id, '3a Categoria', 40, 3, 50);
            WHEN 'banda' THEN
                INSERT INTO categories (event_id, nom, distancia_caramboles, ordre_categoria, max_entrades) VALUES
                (event_record.id, '1a Categoria', 50, 1, 50),
                (event_record.id, '2a Categoria', 40, 2, 50),
                (event_record.id, '3a Categoria', 30, 3, 50),
                (event_record.id, '4a Categoria', 25, 4, 50);
        END CASE;
    END LOOP;
END $$;

-- VERIFICACIÓ
SELECT
    e.temporada,
    e.modalitat,
    COUNT(c.id) as categories_creades
FROM events e
LEFT JOIN categories c ON e.id = c.event_id
WHERE e.tipus_competicio = 'lliga_social'
GROUP BY e.temporada, e.modalitat
ORDER BY e.temporada DESC, e.modalitat;