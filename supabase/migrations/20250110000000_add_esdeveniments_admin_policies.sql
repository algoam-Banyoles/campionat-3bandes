-- Add admin policies for esdeveniments_club table
-- Migration: 20250110000000_add_esdeveniments_admin_policies.sql

-- Drop existing insert/update/delete policies if they exist
DROP POLICY IF EXISTS "esdeveniments_insert_auth" ON esdeveniments_club;
DROP POLICY IF EXISTS "esdeveniments_update_auth" ON esdeveniments_club;
DROP POLICY IF EXISTS "esdeveniments_delete_auth" ON esdeveniments_club;
DROP POLICY IF EXISTS "events_insert_admin" ON esdeveniments_club;
DROP POLICY IF EXISTS "events_update_admin" ON esdeveniments_club;
DROP POLICY IF EXISTS "events_delete_admin" ON esdeveniments_club;

-- Create INSERT policy: authenticated users can insert events
CREATE POLICY "esdeveniments_insert_auth" ON esdeveniments_club
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Create UPDATE policy: authenticated users can update events
CREATE POLICY "esdeveniments_update_auth" ON esdeveniments_club
  FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- Create DELETE policy: authenticated users can delete events
CREATE POLICY "esdeveniments_delete_auth" ON esdeveniments_club
  FOR DELETE
  USING (auth.uid() IS NOT NULL);
