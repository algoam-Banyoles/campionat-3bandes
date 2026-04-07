-- Fase 5c — Sessió 1: Foundation per al refactor `players` → `socis`
--
-- Aquest fitxer NO toca cap dada existent ni cap columna existent. Tot el
-- que fa és afegir estructura nova en paral·lel:
--   1. Nova taula `socis_jugador` (1-a-1 amb `socis`) per als camps de joc
--      que vivien a `players` (mitjana, estat, club, avatar_url,
--      data_ultim_repte, creat_el).
--   2. A cada taula amb FK cap a `players(id)`, afegeix una nova columna
--      INTEGER `*_soci_numero` (NULLABLE de moment) que apunta a
--      `socis(numero_soci)`.
--   3. Backfill: omple les noves columnes via JOIN amb `players`.
--   4. Crea índexs als nous camps.
--
-- Després d'aquesta migració, el codi encara llegeix les columnes UUID
-- antigues — tot continua funcionant igual. La Sessió 2 (migració de codi)
-- canvia gradualment les lectures, i la Sessió 3 esborra les columnes
-- antigues i la taula `players`.

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Nova taula `socis_jugador` (1-a-1 amb `socis`)
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS socis_jugador (
  numero_soci integer PRIMARY KEY REFERENCES socis(numero_soci) ON DELETE CASCADE,
  mitjana numeric,
  estat player_state DEFAULT 'actiu' NOT NULL,
  club text,
  avatar_url text,
  data_ultim_repte date,
  creat_el timestamptz DEFAULT now() NOT NULL
);

-- Backfill des de players (118 files esperades)
INSERT INTO socis_jugador (numero_soci, mitjana, estat, club, avatar_url, data_ultim_repte, creat_el)
SELECT
  numero_soci,
  mitjana,
  COALESCE(estat, 'actiu'),
  club,
  avatar_url,
  data_ultim_repte,
  COALESCE(creat_el, now())
FROM players
WHERE numero_soci IS NOT NULL
ON CONFLICT (numero_soci) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
-- 2. Noves columnes INTEGER referenciant socis(numero_soci)
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE calendari_partides
  ADD COLUMN IF NOT EXISTS jugador1_soci_numero integer REFERENCES socis(numero_soci),
  ADD COLUMN IF NOT EXISTS jugador2_soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE challenges
  ADD COLUMN IF NOT EXISTS reptador_soci_numero integer REFERENCES socis(numero_soci),
  ADD COLUMN IF NOT EXISTS reptat_soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE classificacions
  ADD COLUMN IF NOT EXISTS soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE handicap_participants
  ADD COLUMN IF NOT EXISTS soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE history_position_changes
  ADD COLUMN IF NOT EXISTS soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE initial_ranking
  ADD COLUMN IF NOT EXISTS soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE penalties
  ADD COLUMN IF NOT EXISTS soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE player_weekly_positions
  ADD COLUMN IF NOT EXISTS soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE ranking_positions
  ADD COLUMN IF NOT EXISTS soci_numero integer REFERENCES socis(numero_soci);

ALTER TABLE waiting_list
  ADD COLUMN IF NOT EXISTS soci_numero integer REFERENCES socis(numero_soci);

-- ────────────────────────────────────────────────────────────────────────────
-- 3. Backfill: per cada taula, omple `*_soci_numero` via JOIN amb players
-- ────────────────────────────────────────────────────────────────────────────
UPDATE calendari_partides cp
   SET jugador1_soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = cp.jugador1_id
   AND cp.jugador1_soci_numero IS NULL;

UPDATE calendari_partides cp
   SET jugador2_soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = cp.jugador2_id
   AND cp.jugador2_soci_numero IS NULL;

UPDATE challenges c
   SET reptador_soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = c.reptador_id
   AND c.reptador_soci_numero IS NULL;

UPDATE challenges c
   SET reptat_soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = c.reptat_id
   AND c.reptat_soci_numero IS NULL;

UPDATE classificacions x
   SET soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = x.player_id
   AND x.soci_numero IS NULL;

UPDATE handicap_participants x
   SET soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = x.player_id
   AND x.soci_numero IS NULL;

UPDATE history_position_changes x
   SET soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = x.player_id
   AND x.soci_numero IS NULL;

UPDATE initial_ranking x
   SET soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = x.player_id
   AND x.soci_numero IS NULL;

UPDATE penalties x
   SET soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = x.player_id
   AND x.soci_numero IS NULL;

UPDATE player_weekly_positions x
   SET soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = x.player_id
   AND x.soci_numero IS NULL;

UPDATE ranking_positions x
   SET soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = x.player_id
   AND x.soci_numero IS NULL;

UPDATE waiting_list x
   SET soci_numero = p.numero_soci
  FROM players p
 WHERE p.id = x.player_id
   AND x.soci_numero IS NULL;

-- ────────────────────────────────────────────────────────────────────────────
-- 4. Índexs als nous camps
-- ────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_calendari_partides_jugador1_soci ON calendari_partides(jugador1_soci_numero);
CREATE INDEX IF NOT EXISTS idx_calendari_partides_jugador2_soci ON calendari_partides(jugador2_soci_numero);
CREATE INDEX IF NOT EXISTS idx_challenges_reptador_soci ON challenges(reptador_soci_numero);
CREATE INDEX IF NOT EXISTS idx_challenges_reptat_soci ON challenges(reptat_soci_numero);
CREATE INDEX IF NOT EXISTS idx_classificacions_soci ON classificacions(soci_numero);
CREATE INDEX IF NOT EXISTS idx_handicap_participants_soci ON handicap_participants(soci_numero);
CREATE INDEX IF NOT EXISTS idx_history_position_changes_soci ON history_position_changes(soci_numero);
CREATE INDEX IF NOT EXISTS idx_initial_ranking_soci ON initial_ranking(soci_numero);
CREATE INDEX IF NOT EXISTS idx_penalties_soci ON penalties(soci_numero);
CREATE INDEX IF NOT EXISTS idx_player_weekly_positions_soci ON player_weekly_positions(soci_numero);
CREATE INDEX IF NOT EXISTS idx_ranking_positions_soci ON ranking_positions(soci_numero);
CREATE INDEX IF NOT EXISTS idx_waiting_list_soci ON waiting_list(soci_numero);
