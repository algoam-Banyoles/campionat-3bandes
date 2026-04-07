-- Fase 5c — Sessió 2a: Triggers de dual-write
--
-- Garanteix que qualsevol nou INSERT/UPDATE que escrigui `player_id` (UUID
-- legacy) també ompli automàticament la nova columna `*_soci_numero` (INT).
-- Així el codi pot migrar-se gradualment a llegir per `soci_numero` sense
-- por que escriptures fetes per pàgines no migrades deixin files
-- inconsistents.
--
-- Estratègia: una funció genèrica per cada parell (taula, columna_player,
-- columna_soci) i un trigger per taula. Idempotent (DROP IF EXISTS abans
-- de CREATE).

-- ────────────────────────────────────────────────────────────────────────────
-- Funció genèrica per a taules amb una sola columna `player_id`
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_soci_numero_from_player_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.player_id IS NOT NULL AND NEW.soci_numero IS NULL THEN
    SELECT numero_soci INTO NEW.soci_numero
      FROM players
     WHERE id = NEW.player_id;
  END IF;
  RETURN NEW;
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- Funció especialitzada per `calendari_partides` (dues columnes)
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_calendari_partides_soci_numero()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.jugador1_id IS NOT NULL AND NEW.jugador1_soci_numero IS NULL THEN
    SELECT numero_soci INTO NEW.jugador1_soci_numero
      FROM players WHERE id = NEW.jugador1_id;
  END IF;
  IF NEW.jugador2_id IS NOT NULL AND NEW.jugador2_soci_numero IS NULL THEN
    SELECT numero_soci INTO NEW.jugador2_soci_numero
      FROM players WHERE id = NEW.jugador2_id;
  END IF;
  RETURN NEW;
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- Funció especialitzada per `challenges` (reptador_id / reptat_id)
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_challenges_soci_numero()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.reptador_id IS NOT NULL AND NEW.reptador_soci_numero IS NULL THEN
    SELECT numero_soci INTO NEW.reptador_soci_numero
      FROM players WHERE id = NEW.reptador_id;
  END IF;
  IF NEW.reptat_id IS NOT NULL AND NEW.reptat_soci_numero IS NULL THEN
    SELECT numero_soci INTO NEW.reptat_soci_numero
      FROM players WHERE id = NEW.reptat_id;
  END IF;
  RETURN NEW;
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- Triggers per a cada taula
-- ────────────────────────────────────────────────────────────────────────────

-- calendari_partides
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON calendari_partides;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF jugador1_id, jugador2_id ON calendari_partides
  FOR EACH ROW EXECUTE FUNCTION sync_calendari_partides_soci_numero();

-- challenges
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON challenges;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF reptador_id, reptat_id ON challenges
  FOR EACH ROW EXECUTE FUNCTION sync_challenges_soci_numero();

-- classificacions
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON classificacions;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF player_id ON classificacions
  FOR EACH ROW EXECUTE FUNCTION sync_soci_numero_from_player_id();

-- handicap_participants
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON handicap_participants;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF player_id ON handicap_participants
  FOR EACH ROW EXECUTE FUNCTION sync_soci_numero_from_player_id();

-- history_position_changes
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON history_position_changes;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF player_id ON history_position_changes
  FOR EACH ROW EXECUTE FUNCTION sync_soci_numero_from_player_id();

-- initial_ranking
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON initial_ranking;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF player_id ON initial_ranking
  FOR EACH ROW EXECUTE FUNCTION sync_soci_numero_from_player_id();

-- penalties
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON penalties;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF player_id ON penalties
  FOR EACH ROW EXECUTE FUNCTION sync_soci_numero_from_player_id();

-- player_weekly_positions
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON player_weekly_positions;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF player_id ON player_weekly_positions
  FOR EACH ROW EXECUTE FUNCTION sync_soci_numero_from_player_id();

-- ranking_positions
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON ranking_positions;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF player_id ON ranking_positions
  FOR EACH ROW EXECUTE FUNCTION sync_soci_numero_from_player_id();

-- waiting_list
DROP TRIGGER IF EXISTS trg_sync_soci_numero ON waiting_list;
CREATE TRIGGER trg_sync_soci_numero
  BEFORE INSERT OR UPDATE OF player_id ON waiting_list
  FOR EACH ROW EXECUTE FUNCTION sync_soci_numero_from_player_id();
