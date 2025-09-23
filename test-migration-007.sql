-- Test Migration 007: Extensions per Lligues Socials
-- Versió simplificada per testing

-- 1. Verificar connexió
SELECT 'Connexió OK' as status;

-- 2. Ampliar events amb camps bàsics
ALTER TABLE events ADD COLUMN IF NOT EXISTS modalitat text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS tipus_competicio text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS data_inici date;
ALTER TABLE events ADD COLUMN IF NOT EXISTS data_fi date;

-- 3. Crear taula categories (la més important)
CREATE TABLE IF NOT EXISTS categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    nom text NOT NULL,
    distancia_caramboles integer NOT NULL,
    ordre_categoria smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- 4. Verificar que s'ha creat
SELECT 'Taula categories creada' as result
WHERE EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'categories'
);