-- Part 1: Afegir només els camps nous a les taules
-- Dividit per evitar timeout

-- Camps per incompareixences a calendari_partides
ALTER TABLE calendari_partides
  ADD COLUMN IF NOT EXISTS incompareixenca_jugador1 boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS incompareixenca_jugador2 boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS data_incompareixenca timestamptz;

-- Camps per incompareixences a inscripcions
ALTER TABLE inscripcions
  ADD COLUMN IF NOT EXISTS eliminat_per_incompareixences boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS data_eliminacio timestamptz,
  ADD COLUMN IF NOT EXISTS incompareixences_count smallint DEFAULT 0;

-- Camps per partides anul·lades
ALTER TABLE calendari_partides
  ADD COLUMN IF NOT EXISTS partida_anullada boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS motiu_anul·lacio text;
