-- Enforce rule: any match with recorded result must have estat = 'jugada'

-- 1) Backfill existing rows
UPDATE calendari_partides
SET estat = 'jugada'
WHERE caramboles_jugador1 IS NOT NULL
  AND caramboles_jugador2 IS NOT NULL
  AND estat IS DISTINCT FROM 'jugada';

-- 2) Trigger function to keep this invariant on future writes
CREATE OR REPLACE FUNCTION set_estat_jugada_when_result_exists()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.caramboles_jugador1 IS NOT NULL
     AND NEW.caramboles_jugador2 IS NOT NULL THEN
    NEW.estat := 'jugada';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_estat_jugada_when_result_exists ON calendari_partides;

CREATE TRIGGER trg_set_estat_jugada_when_result_exists
BEFORE INSERT OR UPDATE ON calendari_partides
FOR EACH ROW
EXECUTE FUNCTION set_estat_jugada_when_result_exists();

