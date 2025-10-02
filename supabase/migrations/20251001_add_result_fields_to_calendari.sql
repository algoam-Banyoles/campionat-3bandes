-- Add result fields directly to calendari_partides table
-- This allows storing match results without requiring a separate matches record
-- Useful for social league matches

ALTER TABLE calendari_partides
  ADD COLUMN IF NOT EXISTS caramboles_jugador1 smallint,
  ADD COLUMN IF NOT EXISTS caramboles_jugador2 smallint,
  ADD COLUMN IF NOT EXISTS entrades smallint,
  ADD COLUMN IF NOT EXISTS data_joc timestamptz;

-- Add a comment to explain the purpose
COMMENT ON COLUMN calendari_partides.caramboles_jugador1 IS 'Caramboles scored by jugador1 (for social league matches)';
COMMENT ON COLUMN calendari_partides.caramboles_jugador2 IS 'Caramboles scored by jugador2 (for social league matches)';
COMMENT ON COLUMN calendari_partides.entrades IS 'Number of innings (for social league matches)';
COMMENT ON COLUMN calendari_partides.data_joc IS 'Actual date when the match was played';
