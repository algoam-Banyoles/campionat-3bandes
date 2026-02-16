-- Make challenge_id nullable in matches table to support social league matches
-- Social league matches don't have an associated challenge

ALTER TABLE matches
  ALTER COLUMN challenge_id DROP NOT NULL;

-- Add a check constraint to ensure that either challenge_id is provided (for ranking matches)
-- or tipus_partida is 'social_league' (for social league matches)
ALTER TABLE matches
  ADD CONSTRAINT matches_challenge_or_social CHECK (
    (challenge_id IS NOT NULL AND tipus_partida = 'challenge') OR
    (challenge_id IS NULL AND tipus_partida = 'social_league')
  );
