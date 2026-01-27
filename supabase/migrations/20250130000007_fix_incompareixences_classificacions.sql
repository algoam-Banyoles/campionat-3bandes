-- Fix registrar_incompareixenca to correctly handle max_entrades per category
-- and ensure 0 caramboles for present player
-- 
-- REGLES CORRECTES per incompareixences:
-- - Jugador PRESENT: 2 punts, 0 caramboles, 0 entrades
-- - Jugador ABSENT: 0 punts, 0 caramboles, max_entrades de la categoria (50 general, 40 per lliure 1a)
--
-- Això garanteix que les classificacions es calculin correctament amb entrades i caramboles

DROP FUNCTION IF EXISTS registrar_incompareixenca(uuid, smallint);

CREATE OR REPLACE FUNCTION registrar_incompareixenca(
  p_partida_id uuid,
  p_jugador_que_falta smallint  -- 1 o 2
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partida RECORD;
  v_jugador_id uuid;
  v_altre_jugador_id uuid;
  v_soci_numero integer;
  v_event_id uuid;
  v_categoria_id uuid;
  v_max_entrades integer;
  v_incompareixences_count smallint;
  v_result json;
BEGIN
  -- Obtenir informació de la partida
  SELECT * INTO v_partida
  FROM calendari_partides
  WHERE id = p_partida_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partida no trobada';
  END IF;

  -- Determinar quin jugador falta i quin ha vingut
  IF p_jugador_que_falta = 1 THEN
    v_jugador_id := v_partida.jugador1_id;
    v_altre_jugador_id := v_partida.jugador2_id;
  ELSIF p_jugador_que_falta = 2 THEN
    v_jugador_id := v_partida.jugador2_id;
    v_altre_jugador_id := v_partida.jugador1_id;
  ELSE
    RAISE EXCEPTION 'Jugador invàlid: ha de ser 1 o 2';
  END IF;

  v_event_id := v_partida.event_id;
  v_categoria_id := v_partida.categoria_id;

  -- Obtenir el numero_soci del jugador que falta
  SELECT numero_soci INTO v_soci_numero
  FROM players
  WHERE id = v_jugador_id;

  IF v_soci_numero IS NULL THEN
    RAISE EXCEPTION 'No s''ha trobat el numero de soci del jugador';
  END IF;

  -- Obtenir el max_entrades de la categoria (50 general, 40 per lliure 1a categoria)
  SELECT max_entrades INTO v_max_entrades
  FROM categories
  WHERE id = v_categoria_id;

  IF v_max_entrades IS NULL THEN
    v_max_entrades := 50; -- Valor per defecte si no es troba
  END IF;

  -- Actualitzar la partida amb el resultat d'incompareixença
  -- REGLES CORRECTES:
  -- Jugador PRESENT: 2 punts, 0 caramboles, 0 entrades (no afecta la mitjana)
  -- Jugador ABSENT: 0 punts, 0 caramboles, max_entrades (penalització forta en mitjana)
  IF p_jugador_que_falta = 1 THEN
    UPDATE calendari_partides
    SET
      incompareixenca_jugador1 = true,
      data_incompareixenca = NOW(),
      estat = 'validat',
      caramboles_jugador1 = 0,                    -- Jugador 1 (absent): 0 caramboles
      caramboles_jugador2 = 0,                    -- Jugador 2 (present): 0 caramboles
      entrades_jugador1 = v_max_entrades,         -- Jugador 1 (absent): max_entrades penalització
      entrades_jugador2 = 0,                      -- Jugador 2 (present): 0 entrades (no afecta mitjana)
      entrades = v_max_entrades,                  -- Deprecated: per compatibilitat
      punts_jugador1 = 0,                         -- Jugador 1 (absent): 0 punts
      punts_jugador2 = 2,                         -- Jugador 2 (present): 2 punts (victòria)
      data_joc = NOW(),
      validat_per = NULL,                         -- Registrat automàticament
      data_validacio = NOW(),
      observacions_junta = COALESCE(observacions_junta || E'\n', '') ||
        '[' || TO_CHAR(NOW(), 'DD/MM/YYYY') || '] Incompareixença jugador 1. Jugador 2: 2 punts, 0 caramboles, 0 entrades. Jugador 1: 0 punts, 0 caramboles, ' || v_max_entrades || ' entrades penalització.'
    WHERE id = p_partida_id;
  ELSE
    UPDATE calendari_partides
    SET
      incompareixenca_jugador2 = true,
      data_incompareixenca = NOW(),
      estat = 'validat',
      caramboles_jugador1 = 0,                    -- Jugador 1 (present): 0 caramboles
      caramboles_jugador2 = 0,                    -- Jugador 2 (absent): 0 caramboles
      entrades_jugador1 = 0,                      -- Jugador 1 (present): 0 entrades (no afecta mitjana)
      entrades_jugador2 = v_max_entrades,         -- Jugador 2 (absent): max_entrades penalització
      entrades = v_max_entrades,                  -- Deprecated: per compatibilitat
      punts_jugador1 = 2,                         -- Jugador 1 (present): 2 punts (victòria)
      punts_jugador2 = 0,                         -- Jugador 2 (absent): 0 punts
      data_joc = NOW(),
      validat_per = NULL,                         -- Registrat automàticament
      data_validacio = NOW(),
      observacions_junta = COALESCE(observacions_junta || E'\n', '') ||
        '[' || TO_CHAR(NOW(), 'DD/MM/YYYY') || '] Incompareixença jugador 2. Jugador 1: 2 punts, 0 caramboles, 0 entrades. Jugador 2: 0 punts, 0 caramboles, ' || v_max_entrades || ' entrades penalització.'
    WHERE id = p_partida_id;
  END IF;

  -- Actualitzar comptador d'incompareixences del jugador
  UPDATE inscripcions
  SET incompareixences_count = incompareixences_count + 1
  WHERE soci_numero = v_soci_numero
    AND event_id = v_event_id
  RETURNING incompareixences_count INTO v_incompareixences_count;

  -- Si té 2 incompareixences, eliminar el jugador i anul·lar les seves partides
  IF v_incompareixences_count >= 2 THEN
    -- Marcar jugador com eliminat
    UPDATE inscripcions
    SET
      eliminat_per_incompareixences = true,
      data_eliminacio = NOW()
    WHERE soci_numero = v_soci_numero
      AND event_id = v_event_id;

    -- Anul·lar totes les partides pendents del jugador
    UPDATE calendari_partides
    SET
      partida_anullada = true,
      motiu_anul·lacio = 'Jugador eliminat per 2 incompareixences',
      estat = 'pendent_programar'
    WHERE event_id = v_event_id
      AND categoria_id = v_categoria_id
      AND (jugador1_id = v_jugador_id OR jugador2_id = v_jugador_id)
      AND estat NOT IN ('validat', 'publicat')
      AND partida_anullada = false;

    v_result := json_build_object(
      'incompareixences', v_incompareixences_count,
      'jugador_eliminat', true,
      'partides_anullades', true,
      'max_entrades_utilitzat', v_max_entrades
    );
  ELSE
    v_result := json_build_object(
      'incompareixences', v_incompareixences_count,
      'jugador_eliminat', false,
      'partides_anullades', false,
      'max_entrades_utilitzat', v_max_entrades
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Permisos
GRANT EXECUTE ON FUNCTION registrar_incompareixenca(uuid, smallint) TO authenticated;

-- Comentari
COMMENT ON FUNCTION registrar_incompareixenca(uuid, smallint) IS 
'Registra una incompareixença d''un jugador segons les regles correctes:
- Jugador PRESENT: 2 punts, 0 caramboles, 0 entrades (no afecta mitjana)
- Jugador ABSENT: 0 punts, 0 caramboles, max_entrades de categoria (penalització en mitjana)
Si té 2 incompareixences, l''elimina del campionat i anul·la les seves partides pendents.
SECURITY: Uses SET search_path = public.';
