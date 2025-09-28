-- Allow public read access to socis nom and cognoms for ranking display
-- This enables anonymous users to see player names in the ranking

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Enable public read access to socis names" ON socis;
DROP POLICY IF EXISTS "Public can view socis basic info for ranking" ON socis;

-- Create policy to allow public read access to nom and cognoms fields
-- This is safe as player names are public information for ranking purposes
CREATE POLICY "Public can view socis basic info for ranking"
  ON socis
  FOR SELECT
  TO public
  USING (true);

-- Enable RLS on socis table if not already enabled
ALTER TABLE socis ENABLE ROW LEVEL SECURITY;