-- Afegir camps per gestionar incompareixences a calendari_partides
ALTER TABLE calendari_partides
  ADD COLUMN IF NOT EXISTS incompareixenca_jugador1 boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS incompareixenca_jugador2 boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS data_incompareixenca timestamptz;

-- Afegir comentaris
COMMENT ON COLUMN calendari_partides.incompareixenca_jugador1 IS 'True si el jugador 1 no s''ha presentat a la partida';
COMMENT ON COLUMN calendari_partides.incompareixenca_jugador2 IS 'True si el jugador 2 no s''ha presentat a la partida';
COMMENT ON COLUMN calendari_partides.data_incompareixenca IS 'Data en què es va registrar la incompareixença';

-- Afegir camp per marcar jugadors eliminats per incompareixences a inscripcions
ALTER TABLE inscripcions
  ADD COLUMN IF NOT EXISTS eliminat_per_incompareixences boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS data_eliminacio timestamptz,
  ADD COLUMN IF NOT EXISTS incompareixences_count smallint DEFAULT 0;

-- Afegir comentaris
COMMENT ON COLUMN inscripcions.eliminat_per_incompareixences IS 'True si el jugador ha estat eliminat del campionat per 2 incompareixences';
COMMENT ON COLUMN inscripcions.data_eliminacio IS 'Data en què el jugador va ser eliminat';
COMMENT ON COLUMN inscripcions.incompareixences_count IS 'Nombre d''incompareixences del jugador en aquest campionat';

-- Afegir camp per marcar partides anul·lades (quan un jugador és eliminat)
ALTER TABLE calendari_partides
  ADD COLUMN IF NOT EXISTS partida_anullada boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS motiu_anul·lacio text;

-- Afegir comentaris
COMMENT ON COLUMN calendari_partides.partida_anullada IS 'True si la partida ha estat anul·lada (jugador eliminat, etc.)';
COMMENT ON COLUMN calendari_partides.motiu_anul·lacio IS 'Motiu de l''anul·lació de la partida';

-- Funció per registrar una incompareixença
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
  v_distancia_caramboles integer;
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

  -- Obtenir la distància de caramboles de la categoria (per assignar al guanyador)
  SELECT distancia_caramboles INTO v_distancia_caramboles
  FROM categories
  WHERE id = v_categoria_id;

  IF v_distancia_caramboles IS NULL THEN
    v_distancia_caramboles := 25; -- Valor per defecte si no es troba
  END IF;

  -- Actualitzar la partida amb el resultat d'incompareixença
  -- Jugador que s'ha presentat: 2 punts (guanya amb distància de categoria), mitjana no afectada
  -- Jugador que NO s'ha presentat: 0 punts, penalització de 50 entrades (0 caramboles / 50 entrades = 0.000)
  -- NOTA: La columna 'entrades' es refereix a les entrades del jugador perdedor (per penalitzar la mitjana)
  IF p_jugador_que_falta = 1 THEN
    UPDATE calendari_partides
    SET
      incompareixenca_jugador1 = true,
      data_incompareixenca = NOW(),
      estat = 'validat',
      caramboles_jugador1 = 0,                    -- Jugador absent: 0 caramboles
      caramboles_jugador2 = v_distancia_caramboles, -- Jugador present: guanya amb distància
      entrades = 1,                                -- 1 entrada fictícia (per evitar divisió per 0 a les estadístiques)
      data_joc = NOW(),
      validat_per = NULL,                          -- Registrat automàticament
      data_validacio = NOW(),
      observacions_junta = COALESCE(observacions_junta || E'\n', '') ||
        '[' || TO_CHAR(NOW(), 'DD/MM/YYYY') || '] Incompareixença jugador 1. Resultat: 0-' || v_distancia_caramboles || '. Jugador 2: 2 punts. Jugador 1: 0 punts (penalització).'
    WHERE id = p_partida_id;
  ELSE
    UPDATE calendari_partides
    SET
      incompareixenca_jugador2 = true,
      data_incompareixenca = NOW(),
      estat = 'validat',
      caramboles_jugador1 = v_distancia_caramboles, -- Jugador present: guanya amb distància
      caramboles_jugador2 = 0,                    -- Jugador absent: 0 caramboles
      entrades = 1,                                -- 1 entrada fictícia (per evitar divisió per 0 a les estadístiques)
      data_joc = NOW(),
      validat_per = NULL,                          -- Registrat automàticament
      data_validacio = NOW(),
      observacions_junta = COALESCE(observacions_junta || E'\n', '') ||
        '[' || TO_CHAR(NOW(), 'DD/MM/YYYY') || '] Incompareixença jugador 2. Resultat: ' || v_distancia_caramboles || '-0. Jugador 1: 2 punts. Jugador 2: 0 punts (penalització).'
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
      'partides_anullades', true
    );
  ELSE
    v_result := json_build_object(
      'incompareixences', v_incompareixences_count,
      'jugador_eliminat', false,
      'partides_anullades', false
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Permisos
GRANT EXECUTE ON FUNCTION registrar_incompareixenca(uuid, smallint) TO authenticated;

-- Comentari
COMMENT ON FUNCTION registrar_incompareixenca(uuid, smallint) IS 'Registra una incompareixença d''un jugador. Si té 2 incompareixences, l''elimina del campionat i anul·la les seves partides pendents. SECURITY: Uses SET search_path = public.';
