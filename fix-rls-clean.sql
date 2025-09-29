-- Fix RLS policies step by step
-- First, drop ALL existing policies for calendari_partides and esdeveniments_club

-- Drop calendari_partides policies
DROP POLICY IF EXISTS "Calendari visible per tots els usuaris autenticats" ON calendari_partides;
DROP POLICY IF EXISTS "Public access to published calendar matches" ON calendari_partides;
DROP POLICY IF EXISTS "Authenticated users can view all calendar matches" ON calendari_partides;
DROP POLICY IF EXISTS "Només admins poden gestionar calendari" ON calendari_partides;

-- Drop esdeveniments_club policies  
DROP POLICY IF EXISTS "Esdeveniments visibles per tots" ON esdeveniments_club;
DROP POLICY IF EXISTS "Public access to visible events" ON esdeveniments_club;
DROP POLICY IF EXISTS "Authenticated users can view all events" ON esdeveniments_club;

-- Now create clean, working policies

-- For calendari_partides: Allow public access for published events with validated matches
CREATE POLICY "calendari_public_access" ON calendari_partides
    FOR SELECT USING (
        estat IN ('validat', 'confirmat', 'jugat') 
        AND EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = calendari_partides.event_id
            AND e.calendari_publicat = true
        )
    );

-- For calendari_partides: Allow authenticated users to see all matches
CREATE POLICY "calendari_auth_access" ON calendari_partides
    FOR SELECT USING (auth.role() = 'authenticated');

-- For calendari_partides: Allow admins full access
CREATE POLICY "calendari_admin_manage" ON calendari_partides
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins a
            WHERE a.email = auth.email()
        )
    );

-- For esdeveniments_club: Allow public access to visible events
CREATE POLICY "events_public_access" ON esdeveniments_club
    FOR SELECT USING (visible_per_tots = true);

-- For esdeveniments_club: Allow authenticated users to see all events
CREATE POLICY "events_auth_access" ON esdeveniments_club
    FOR SELECT USING (auth.role() = 'authenticated');

-- For esdeveniments_club: Allow admins full access
CREATE POLICY "events_admin_manage" ON esdeveniments_club
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins a
            WHERE a.email = auth.email()
        )
    );