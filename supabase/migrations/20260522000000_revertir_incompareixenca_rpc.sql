-- Revertir una incompareixença ja registrada en una partida del campionat social.
--
-- Modes admesos:
--   'pendent'  → buida caramboles/entrades/punts/data_joc i deixa la partida
--                en estat 'programada' (com si no s'hagués jugat).
--   'resultat' → aplica el resultat real passat per paràmetres i recalcula
--                punts (2-0 / 1-1 / 0-2 segons caramboles). Estat 'jugada'.
--
-- Efectes secundaris (en ambdós modes):
--   - Posa incompareixenca_jugador1 = false i incompareixenca_jugador2 = false.
--   - Per a cada jugador que tenia la incompareixença, decrementa
--     inscripcions.incompareixences_count (sense baixar de 0).
--   - Si algun d'aquests jugadors havia quedat eliminat per 2 incompareixences
--     i ara torna a tenir < 2, neteja eliminat_per_incompareixences i reactiva
--     les partides anul·lades pel motiu "Jugador eliminat per 2 incompareixences".
--
-- Validacions:
--   - La partida ha d'existir i tenir incompareixenca_jugador1 OR jugador2.
--   - En mode 'resultat' cal passar caramboles + entrades dels dos jugadors.

DROP FUNCTION IF EXISTS revertir_incompareixenca(uuid, text, smallint, smallint, smallint, smallint);

CREATE OR REPLACE FUNCTION revertir_incompareixenca(
  p_partida_id uuid,
  p_mode text,
  p_caramboles_jugador1 smallint DEFAULT NULL,
  p_caramboles_jugador2 smallint DEFAULT NULL,
  p_entrades_jugador1 smallint DEFAULT NULL,
  p_entrades_jugador2 smallint DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partida RECORD;
  v_soci_numero_j1 integer;
  v_soci_numero_j2 integer;
  v_count_j1 smallint;
  v_count_j2 smallint;
  v_was_eliminat_j1 boolean := false;
  v_was_eliminat_j2 boolean := false;
  v_reactivades integer := 0;
  v_punts_j1 smallint;
  v_punts_j2 smallint;
  v_now timestamptz := NOW();
  v_result json;
BEGIN
  -- Llegir la partida
  SELECT * INTO v_partida FROM calendari_partides WHERE id = p_partida_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partida no trobada';
  END IF;

  IF NOT (COALESCE(v_partida.incompareixenca_jugador1, false) OR COALESCE(v_partida.incompareixenca_jugador2, false)) THEN
    RAISE EXCEPTION 'La partida no té cap incompareixença registrada';
  END IF;

  IF p_mode NOT IN ('pendent', 'resultat') THEN
    RAISE EXCEPTION 'Mode invàlid: %, ha de ser ''pendent'' o ''resultat''', p_mode;
  END IF;

  IF p_mode = 'resultat' THEN
    IF p_caramboles_jugador1 IS NULL OR p_caramboles_jugador2 IS NULL
       OR p_entrades_jugador1 IS NULL OR p_entrades_jugador2 IS NULL THEN
      RAISE EXCEPTION 'En mode ''resultat'' calen caramboles i entrades dels dos jugadors';
    END IF;
  END IF;

  -- Resoldre soci_numero dels jugadors absents (via players.id → players.numero_soci)
  IF COALESCE(v_partida.incompareixenca_jugador1, false) THEN
    SELECT numero_soci INTO v_soci_numero_j1 FROM players WHERE id = v_partida.jugador1_id;
  END IF;
  IF COALESCE(v_partida.incompareixenca_jugador2, false) THEN
    SELECT numero_soci INTO v_soci_numero_j2 FROM players WHERE id = v_partida.jugador2_id;
  END IF;

  -- Decrementar comptadors (sense baixar de 0)
  IF v_soci_numero_j1 IS NOT NULL THEN
    SELECT eliminat_per_incompareixences INTO v_was_eliminat_j1
      FROM inscripcions
     WHERE soci_numero = v_soci_numero_j1 AND event_id = v_partida.event_id;
    UPDATE inscripcions
       SET incompareixences_count = GREATEST(COALESCE(incompareixences_count, 0) - 1, 0)
     WHERE soci_numero = v_soci_numero_j1 AND event_id = v_partida.event_id
    RETURNING incompareixences_count INTO v_count_j1;
  END IF;

  IF v_soci_numero_j2 IS NOT NULL THEN
    SELECT eliminat_per_incompareixences INTO v_was_eliminat_j2
      FROM inscripcions
     WHERE soci_numero = v_soci_numero_j2 AND event_id = v_partida.event_id;
    UPDATE inscripcions
       SET incompareixences_count = GREATEST(COALESCE(incompareixences_count, 0) - 1, 0)
     WHERE soci_numero = v_soci_numero_j2 AND event_id = v_partida.event_id
    RETURNING incompareixences_count INTO v_count_j2;
  END IF;

  -- Si algú estava eliminat per incompareixences i ara compta < 2, reactivar
  IF v_was_eliminat_j1 AND COALESCE(v_count_j1, 0) < 2 THEN
    UPDATE inscripcions
       SET eliminat_per_incompareixences = false,
           data_eliminacio = NULL
     WHERE soci_numero = v_soci_numero_j1 AND event_id = v_partida.event_id;

    WITH reactivades AS (
      UPDATE calendari_partides
         SET partida_anullada = false,
             motiu_anul·lacio = NULL,
             estat = 'programada'
       WHERE event_id = v_partida.event_id
         AND categoria_id = v_partida.categoria_id
         AND (jugador1_id = v_partida.jugador1_id OR jugador2_id = v_partida.jugador1_id)
         AND partida_anullada = true
         AND motiu_anul·lacio = 'Jugador eliminat per 2 incompareixences'
      RETURNING 1
    )
    SELECT v_reactivades + COUNT(*) INTO v_reactivades FROM reactivades;
  END IF;

  IF v_was_eliminat_j2 AND COALESCE(v_count_j2, 0) < 2 THEN
    UPDATE inscripcions
       SET eliminat_per_incompareixences = false,
           data_eliminacio = NULL
     WHERE soci_numero = v_soci_numero_j2 AND event_id = v_partida.event_id;

    WITH reactivades AS (
      UPDATE calendari_partides
         SET partida_anullada = false,
             motiu_anul·lacio = NULL,
             estat = 'programada'
       WHERE event_id = v_partida.event_id
         AND categoria_id = v_partida.categoria_id
         AND (jugador1_id = v_partida.jugador2_id OR jugador2_id = v_partida.jugador2_id)
         AND partida_anullada = true
         AND motiu_anul·lacio = 'Jugador eliminat per 2 incompareixences'
      RETURNING 1
    )
    SELECT v_reactivades + COUNT(*) INTO v_reactivades FROM reactivades;
  END IF;

  -- Actualitzar la partida
  IF p_mode = 'pendent' THEN
    UPDATE calendari_partides
       SET incompareixenca_jugador1 = false,
           incompareixenca_jugador2 = false,
           data_incompareixenca = NULL,
           caramboles_jugador1 = NULL,
           caramboles_jugador2 = NULL,
           entrades = NULL,
           entrades_jugador1 = NULL,
           entrades_jugador2 = NULL,
           punts_jugador1 = NULL,
           punts_jugador2 = NULL,
           data_joc = NULL,
           validat_per = NULL,
           data_validacio = NULL,
           estat = 'programada',
           observacions_junta = COALESCE(observacions_junta || E'\n', '')
             || '[' || TO_CHAR(v_now, 'DD/MM/YYYY') || '] Incompareixença revertida: partida tornada a pendent.'
     WHERE id = p_partida_id;
  ELSE
    -- mode = 'resultat': calcular punts (2/0, 1/1 segons caramboles)
    IF p_caramboles_jugador1 > p_caramboles_jugador2 THEN
      v_punts_j1 := 2; v_punts_j2 := 0;
    ELSIF p_caramboles_jugador2 > p_caramboles_jugador1 THEN
      v_punts_j1 := 0; v_punts_j2 := 2;
    ELSE
      v_punts_j1 := 1; v_punts_j2 := 1;
    END IF;

    UPDATE calendari_partides
       SET incompareixenca_jugador1 = false,
           incompareixenca_jugador2 = false,
           data_incompareixenca = NULL,
           caramboles_jugador1 = p_caramboles_jugador1,
           caramboles_jugador2 = p_caramboles_jugador2,
           entrades = GREATEST(p_entrades_jugador1, p_entrades_jugador2),
           entrades_jugador1 = p_entrades_jugador1,
           entrades_jugador2 = p_entrades_jugador2,
           punts_jugador1 = v_punts_j1,
           punts_jugador2 = v_punts_j2,
           data_joc = v_now,
           estat = 'jugada',
           observacions_junta = COALESCE(observacions_junta || E'\n', '')
             || '[' || TO_CHAR(v_now, 'DD/MM/YYYY') || '] Incompareixença revertida i substituïda per resultat real.'
     WHERE id = p_partida_id;
  END IF;

  v_result := json_build_object(
    'mode', p_mode,
    'incompareixences_j1', v_count_j1,
    'incompareixences_j2', v_count_j2,
    'reactivat_j1', v_was_eliminat_j1 AND COALESCE(v_count_j1, 0) < 2,
    'reactivat_j2', v_was_eliminat_j2 AND COALESCE(v_count_j2, 0) < 2,
    'partides_reactivades', v_reactivades
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION revertir_incompareixenca(uuid, text, smallint, smallint, smallint, smallint) TO authenticated;

COMMENT ON FUNCTION revertir_incompareixenca(uuid, text, smallint, smallint, smallint, smallint) IS
'Reverteix una incompareixença ja registrada en una partida del social.
Modes: ''pendent'' (deixa la partida sense resultat) o ''resultat'' (aplica caramboles+entrades passades i recalcula punts).
Decrementa incompareixences_count i, si cal, treu eliminat_per_incompareixences i reactiva les partides anul·lades.
SECURITY: SET search_path = public.';
