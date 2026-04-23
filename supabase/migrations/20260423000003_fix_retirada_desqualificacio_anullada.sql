-- =====================================================================
-- Unifica la lògica de retirada/desqualificació:
-- - Les partides pendents del jugador s'anul·len (`partida_anullada = true`)
-- - Les ja jugades es conserven (no s'hi toca l'estat)
-- - Es registra motiu d'anul·lació per auditoria
-- Abans, el client feia UPDATE directe posant estat='cancel·lada_per_retirada'
-- sense marcar `partida_anullada=true`, provocant incoherències a les
-- classificacions i al head-to-head.
-- =====================================================================

-- 1. Sanegem dades existents: 17 partides amb estat='cancel·lada_per_retirada'
--    però partida_anullada=false (les que es van marcar via UPDATE directe).
UPDATE calendari_partides
SET partida_anullada = true,
    "motiu_anul·lacio" = COALESCE("motiu_anul·lacio", 'Jugador retirat del campionat (sanejament retroactiu)')
WHERE estat = 'cancel·lada_per_retirada'
  AND COALESCE(partida_anullada, false) = false;

-- 2. Rewrite de retire_player_from_league. La versió anterior estava trencada
-- (usava players.jugador1_id/jugador2_id, taula ja eliminada a Fase 5c).
CREATE OR REPLACE FUNCTION public.retire_player_from_league(
  p_event_id uuid,
  p_soci_numero integer,
  p_motiu_retirada text DEFAULT 'No especificat',
  p_per_incompareixences boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_player_name TEXT;
  v_pending_cancelled INTEGER;
  v_result JSON;
  v_motiu_anullacio TEXT;
BEGIN
  -- Verificar inscripció
  SELECT (s.nom || ' ' || s.cognoms) INTO v_player_name
  FROM inscripcions i
  JOIN socis s ON s.numero_soci = i.soci_numero
  WHERE i.event_id = p_event_id
    AND i.soci_numero = p_soci_numero;

  IF v_player_name IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Jugador no trobat en aquest campionat'
    );
  END IF;

  -- Si ja està retirat, no fem res
  IF EXISTS (
    SELECT 1 FROM inscripcions
    WHERE event_id = p_event_id
      AND soci_numero = p_soci_numero
      AND estat_jugador = 'retirat'
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'El jugador ja està retirat'
    );
  END IF;

  v_motiu_anullacio := CASE
    WHEN p_per_incompareixences THEN 'Jugador eliminat per 2 incompareixences'
    ELSE 'Jugador retirat del campionat: ' || p_motiu_retirada
  END;

  -- Marcar inscripció com a retirada
  UPDATE inscripcions
  SET estat_jugador = 'retirat',
      data_retirada = NOW(),
      motiu_retirada = p_motiu_retirada,
      eliminat_per_incompareixences = CASE
        WHEN p_per_incompareixences THEN true
        ELSE COALESCE(eliminat_per_incompareixences, false)
      END,
      data_eliminacio = CASE
        WHEN p_per_incompareixences THEN NOW()
        ELSE data_eliminacio
      END
  WHERE event_id = p_event_id
    AND soci_numero = p_soci_numero;

  -- Anul·lar només les partides PENDENTS (no jugades). Les jugades es conserven.
  UPDATE calendari_partides
  SET partida_anullada = true,
      "motiu_anul·lacio" = v_motiu_anullacio
  WHERE event_id = p_event_id
    AND (jugador1_soci_numero = p_soci_numero OR jugador2_soci_numero = p_soci_numero)
    AND caramboles_jugador1 IS NULL
    AND caramboles_jugador2 IS NULL
    AND COALESCE(partida_anullada, false) = false;

  GET DIAGNOSTICS v_pending_cancelled = ROW_COUNT;

  v_result := json_build_object(
    'success', true,
    'player_name', v_player_name,
    'soci_numero', p_soci_numero,
    'retirement_date', NOW(),
    'reason', p_motiu_retirada,
    'per_incompareixences', p_per_incompareixences,
    'pending_matches_cancelled', v_pending_cancelled,
    'message', format(
      'Jugador %s (%s) retirat del campionat. %s partides pendents anul·lades.',
      v_player_name, p_soci_numero, v_pending_cancelled
    )
  );

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', format('Error al retirar jugador: %s', SQLERRM)
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.retire_player_from_league(uuid, integer, text, boolean) TO authenticated;

-- 3. Rewrite de marcar_jugador_retirat perquè també anul·li partides pendents.
-- Manté la signatura antiga (p_inscripcio_id, p_motiu_retirada) per
-- compatibilitat amb cridans existents.
CREATE OR REPLACE FUNCTION public.marcar_jugador_retirat(
  p_inscripcio_id uuid,
  p_motiu_retirada text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_event_id uuid;
  v_soci_numero integer;
BEGIN
  SELECT event_id, soci_numero INTO v_event_id, v_soci_numero
  FROM inscripcions
  WHERE id = p_inscripcio_id;

  IF v_event_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'No s''ha trobat la inscripció',
      'inscripcio_id', p_inscripcio_id
    );
  END IF;

  -- Delega a la funció centralitzada
  RETURN public.retire_player_from_league(
    v_event_id,
    v_soci_numero,
    p_motiu_retirada,
    false  -- retirada voluntària, no per incompareixences
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.marcar_jugador_retirat(uuid, text) TO authenticated;
