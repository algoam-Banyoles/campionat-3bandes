-- Fix RLS policies for public calendar access
-- Migration: 20250929161644_fix_public_calendar_rls.sql

-- First, ensure RLS is enabled
ALTER TABLE calendari_partides ENABLE ROW LEVEL SECURITY;
ALTER TABLE esdeveniments_club ENABLE ROW LEVEL SECURITY;

-- Drop existing problematic policies for calendari_partides
DROP POLICY IF EXISTS "Calendari visible per tots els usuaris autenticats" ON calendari_partides;
DROP POLICY IF EXISTS "Public access to published calendar matches" ON calendari_partides;
DROP POLICY IF EXISTS "Authenticated users can view all calendar matches" ON calendari_partides;

-- Drop existing problematic policies for esdeveniments_club
DROP POLICY IF EXISTS "Esdeveniments visibles per tots" ON esdeveniments_club;
DROP POLICY IF EXISTS "Public access to visible events" ON esdeveniments_club;
DROP POLICY IF EXISTS "Authenticated users can view all events" ON esdeveniments_club;

-- Create new clean policies for calendari_partides

-- 1. Public access to calendar matches for published events
CREATE POLICY "calendari_public_access" ON calendari_partides
    FOR SELECT USING (
        estat IN ('validat', 'confirmat', 'jugat') 
        AND EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = calendari_partides.event_id
            AND e.calendari_publicat = true
        )
    );

-- 2. Authenticated users can see all calendar matches
CREATE POLICY "calendari_auth_access" ON calendari_partides
    FOR SELECT USING (auth.role() = 'authenticated');

-- Create new clean policies for esdeveniments_club

-- 1. Public access to visible events
CREATE POLICY "events_public_access" ON esdeveniments_club
    FOR SELECT USING (visible_per_tots = true);

-- 2. Authenticated users can see all events
CREATE POLICY "events_auth_access" ON esdeveniments_club
    FOR SELECT USING (auth.role() = 'authenticated');

-- Note: Admin management policies should already exist from previous migrations
-- If they don't exist, they can be added separately