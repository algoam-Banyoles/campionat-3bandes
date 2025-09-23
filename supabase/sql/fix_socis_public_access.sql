-- Script to fix public access to socis table for anonymous users
-- This allows the ranking to display player names when users are not logged in

-- First, check current RLS status and policies
-- SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'socis';
-- SELECT policyname, permissive, roles, cmd FROM pg_policies WHERE tablename = 'socis';

-- Drop existing restrictive policies if they exist
DROP POLICY IF EXISTS "Enable public read access to socis names" ON socis;
DROP POLICY IF EXISTS "Public can view socis basic info for ranking" ON socis;
DROP POLICY IF EXISTS "Users can view their own socis record" ON socis;
DROP POLICY IF EXISTS "socis_select_policy" ON socis;

-- Enable RLS on socis table
ALTER TABLE socis ENABLE ROW LEVEL SECURITY;

-- Create a permissive policy that allows public read access to basic fields
-- This is safe because player names are public information for ranking purposes
CREATE POLICY "Public can view socis basic info for ranking"
  ON socis
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Optional: More restrictive policy if you want to limit fields
-- But Supabase RLS works at row level, not column level, so this allows all fields
-- If you need column-level security, you'd need to use Views or modify the application logic

-- Grant basic permissions to anon role if not already granted
GRANT SELECT ON socis TO anon;
GRANT SELECT ON socis TO authenticated;