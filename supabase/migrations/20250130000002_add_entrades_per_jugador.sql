-- Afegir camps d'entrades separats per cada jugador
-- Això permet gestionar correctament les incompareixences on:
-- - Jugador present: 0 entrades (no afecta mitjana)
-- - Jugador absent: 50 entrades (mitjana 0.000, penalització forta)

-- Pas 1: Afegir les noves columnes
ALTER TABLE calendari_partides
  ADD COLUMN IF NOT EXISTS entrades_jugador1 smallint,
  ADD COLUMN IF NOT EXISTS entrades_jugador2 smallint;

-- Pas 2: Migrar TOTES les dades existents (entrades actuals → entrades_jugador1 i entrades_jugador2)
-- Per partides normals, ambdós jugadors tenen les mateixes entrades
-- Per incompareixences, es reassignaran després
UPDATE calendari_partides
SET
  entrades_jugador1 = COALESCE(entrades, 0),
  entrades_jugador2 = COALESCE(entrades, 0);

-- Nota: Després d'aplicar aquesta migració, les partides noves guardaran
-- entrades_jugador1 i entrades_jugador2 directament des del formulari

-- Pas 3: Comentaris
COMMENT ON COLUMN calendari_partides.entrades_jugador1 IS 'Entrades del jugador 1 (per calcular mitjana individual)';
COMMENT ON COLUMN calendari_partides.entrades_jugador2 IS 'Entrades del jugador 2 (per calcular mitjana individual)';
COMMENT ON COLUMN calendari_partides.entrades IS 'DEPRECATED: Utilitzar entrades_jugador1 i entrades_jugador2. Mantingut per compatibilitat.';
