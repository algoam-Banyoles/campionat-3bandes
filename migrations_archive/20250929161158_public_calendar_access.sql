-- Fix public access to calendari_partides for published events
-- The current RLS policy only allows authenticated users to see calendar matches
-- We need to allow public access when the event has calendari_publicat = true

-- Drop existing restrictive policy for SELECT
DROP POLICY IF EXISTS "Calendari visible per tots els usuaris autenticats" ON calendari_partides;

-- Create new policy that allows public access for published events
CREATE POLICY "Public access to published calendar matches" ON calendari_partides
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = calendari_partides.event_id
            AND e.calendari_publicat = true
            AND calendari_partides.estat IN ('validat', 'confirmat', 'jugat')
        )
    );

-- Keep authenticated users access for all matches (for management purposes)
CREATE POLICY "Authenticated users can view all calendar matches" ON calendari_partides
    FOR SELECT USING (auth.role() = 'authenticated');

-- Keep admin management policies as they are (should be fixed in migration 016)
-- No changes needed for INSERT/UPDATE/DELETE policies

-- Also ensure esdeveniments_club allows public read access for visible events
-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Esdeveniments visibles per tots" ON esdeveniments_club;

-- Create policy for public access to visible events
CREATE POLICY "Public access to visible events" ON esdeveniments_club
    FOR SELECT USING (visible_per_tots = true);

-- Keep authenticated users access to all events
CREATE POLICY "Authenticated users can view all events" ON esdeveniments_club
    FOR SELECT USING (auth.role() = 'authenticated');

-- For challenges, keep them restricted to authenticated users only
-- (they are player-specific and shouldn't be public)