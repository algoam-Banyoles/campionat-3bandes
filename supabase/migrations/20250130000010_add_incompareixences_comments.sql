-- Part 2: Afegir comentaris als camps
-- Dividit per evitar timeout

COMMENT ON COLUMN calendari_partides.incompareixenca_jugador1 IS 'True si el jugador 1 no s''ha presentat a la partida';
COMMENT ON COLUMN calendari_partides.incompareixenca_jugador2 IS 'True si el jugador 2 no s''ha presentat a la partida';
COMMENT ON COLUMN calendari_partides.data_incompareixenca IS 'Data en què es va registrar la incompareixença';
COMMENT ON COLUMN inscripcions.eliminat_per_incompareixences IS 'True si el jugador ha estat eliminat del campionat per 2 incompareixences';
COMMENT ON COLUMN inscripcions.data_eliminacio IS 'Data en què el jugador va ser eliminat';
COMMENT ON COLUMN inscripcions.incompareixences_count IS 'Nombre d''incompareixences del jugador en aquest campionat';
COMMENT ON COLUMN calendari_partides.partida_anullada IS 'True si la partida ha estat anul·lada (jugador eliminat, etc.)';
COMMENT ON COLUMN calendari_partides.motiu_anul·lacio IS 'Motiu de l''anul·lació de la partida';
