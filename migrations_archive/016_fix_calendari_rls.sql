-- Fix RLS policies for calendari_partides and configuracio_calendari
-- The issue is that the policies reference user_roles table which doesn't exist
-- We need to use the admins table instead

-- Drop existing incorrect policies
DROP POLICY IF EXISTS "Només admins poden gestionar calendari" ON calendari_partides;
DROP POLICY IF EXISTS "Només admins poden gestionar configuració calendari" ON configuracio_calendari;

-- Create correct admin policies using the admins table
CREATE POLICY "Només admins poden gestionar calendari" ON calendari_partides
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins a
            WHERE a.email = auth.email()
        )
    );

CREATE POLICY "Només admins poden gestionar configuració calendari" ON configuracio_calendari
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins a
            WHERE a.email = auth.email()
        )
    );

-- Also fix the schema issue - jugador1_id and jugador2_id should reference players(id) not socis(numero)
-- First, let's check if the table has the wrong foreign keys and fix them

-- Drop the incorrect foreign key constraints if they exist
ALTER TABLE calendari_partides
DROP CONSTRAINT IF EXISTS calendari_partides_jugador1_id_fkey,
DROP CONSTRAINT IF EXISTS calendari_partides_jugador2_id_fkey;

-- Modify the columns to be UUID instead of INTEGER and reference players(id)
ALTER TABLE calendari_partides
ALTER COLUMN jugador1_id TYPE uuid USING jugador1_id::uuid,
ALTER COLUMN jugador2_id TYPE uuid USING jugador2_id::uuid;

-- Add correct foreign key constraints
ALTER TABLE calendari_partides
ADD CONSTRAINT calendari_partides_jugador1_id_fkey
    FOREIGN KEY (jugador1_id) REFERENCES players(id),
ADD CONSTRAINT calendari_partides_jugador2_id_fkey
    FOREIGN KEY (jugador2_id) REFERENCES players(id);

-- Also fix guanyador_id field
ALTER TABLE calendari_partides
DROP CONSTRAINT IF EXISTS calendari_partides_guanyador_id_fkey;

ALTER TABLE calendari_partides
ALTER COLUMN guanyador_id TYPE uuid USING guanyador_id::uuid;

ALTER TABLE calendari_partides
ADD CONSTRAINT calendari_partides_guanyador_id_fkey
    FOREIGN KEY (guanyador_id) REFERENCES players(id);