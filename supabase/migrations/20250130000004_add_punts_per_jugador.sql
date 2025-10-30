-- Afegir camps de punts separats per cada jugador
-- Això evita haver de recalcular els punts cada vegada a les classificacions
-- Regles: guanyador = 2 punts, empat = 1 punt, perdedor = 0 punts

-- Pas 1: Afegir les noves columnes
ALTER TABLE calendari_partides
  ADD COLUMN IF NOT EXISTS punts_jugador1 smallint,
  ADD COLUMN IF NOT EXISTS punts_jugador2 smallint;

-- Pas 2: Calcular i migrar punts de TOTES les partides existents
UPDATE calendari_partides
SET
  punts_jugador1 = CASE
    WHEN caramboles_jugador1 IS NULL OR caramboles_jugador2 IS NULL THEN NULL
    WHEN caramboles_jugador1 > caramboles_jugador2 THEN 2  -- Jugador 1 guanya
    WHEN caramboles_jugador1 = caramboles_jugador2 THEN 1  -- Empat
    ELSE 0  -- Jugador 1 perd
  END,
  punts_jugador2 = CASE
    WHEN caramboles_jugador1 IS NULL OR caramboles_jugador2 IS NULL THEN NULL
    WHEN caramboles_jugador2 > caramboles_jugador1 THEN 2  -- Jugador 2 guanya
    WHEN caramboles_jugador1 = caramboles_jugador2 THEN 1  -- Empat
    ELSE 0  -- Jugador 2 perd
  END
WHERE estat = 'validat';

-- Pas 3: Comentaris
COMMENT ON COLUMN calendari_partides.punts_jugador1 IS 'Punts obtinguts pel jugador 1 (2=guanya, 1=empat, 0=perd)';
COMMENT ON COLUMN calendari_partides.punts_jugador2 IS 'Punts obtinguts pel jugador 2 (2=guanya, 1=empat, 0=perd)';
