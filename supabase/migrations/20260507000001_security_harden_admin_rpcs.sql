-- Hardening de funcions SECURITY DEFINER exposades a `anon`/`authenticated`.
--
-- Objectius:
--   1) Tancar el vector d'execució anònima per a TOTES les RPCs destructives.
--      `is_admin_by_email()` retorna false per a anon, però volem defense-in-depth
--      via REVOKE.
--   2) Afegir un check d'admin (`is_admin_by_email()`) a les RPCs cridades pel
--      front-end com a admin (operacions destructives o que muten estat global).
--   3) Per a funcions admin-only que ja no es criden des del front, REVOKE EXECUTE
--      de `authenticated` també (queden disponibles per a service_role internament).
--
-- Cap canvi a la signatura (mantenim els bodies originals + check al principi).

----------------------------------------------------------------------
-- GRUP A · Afegim check d'admin + REVOKE anon
-- (USED des del front-end o des d'endpoints server amb token d'usuari)
----------------------------------------------------------------------

-- 1) reset_full_competition: TRUNCATE catastròfic. Crític.
CREATE OR REPLACE FUNCTION public.reset_full_competition()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_matches   INTEGER;
  v_history   INTEGER;
  v_penalties INTEGER;
  v_challenges INTEGER;
  v_ranking   INTEGER;
  v_waitlist  INTEGER;
  v_events    INTEGER;
  v_players   INTEGER;
  v_event_id  uuid;
  v_current_year text;
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden fer reset' USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*) INTO v_matches   FROM matches;
  SELECT COUNT(*) INTO v_history   FROM history_position_changes;
  SELECT COUNT(*) INTO v_penalties FROM penalties;
  SELECT COUNT(*) INTO v_challenges FROM challenges;
  SELECT COUNT(*) INTO v_ranking   FROM ranking_positions;
  SELECT COUNT(*) INTO v_waitlist  FROM waiting_list;
  SELECT COUNT(*) INTO v_events    FROM events;
  SELECT COUNT(*) INTO v_players   FROM socis_jugador;

  TRUNCATE TABLE matches CASCADE;
  TRUNCATE TABLE history_position_changes CASCADE;
  TRUNCATE TABLE penalties CASCADE;
  TRUNCATE TABLE challenges CASCADE;
  TRUNCATE TABLE ranking_positions CASCADE;
  TRUNCATE TABLE waiting_list CASCADE;
  TRUNCATE TABLE events CASCADE;

  UPDATE socis_jugador
  SET estat = 'actiu',
      data_ultim_repte = NULL;

  v_current_year := EXTRACT(YEAR FROM NOW())::text;

  INSERT INTO events(nom, temporada, actiu)
  VALUES (
    'Campionat Continu 3 Bandes',
    v_current_year || '-' || (EXTRACT(YEAR FROM NOW()) + 1)::text,
    TRUE
  )
  RETURNING id INTO v_event_id;

  RETURN json_build_object(
    'ok', TRUE,
    'event_id', v_event_id,
    'deleted', json_build_object(
      'matches',   v_matches,
      'history_position_changes', v_history,
      'penalties', v_penalties,
      'challenges', v_challenges,
      'ranking_positions', v_ranking,
      'waiting_list', v_waitlist,
      'events', v_events,
      'players', v_players
    ),
    'message', 'Reset completat. Base de dades buida i preparada. No s''han generat jugadors automàticament.'
  );
END;
$function$;

-- 2) admin_update_settings: actualitza app_settings.
CREATE OR REPLACE FUNCTION public.admin_update_settings(
  p_dies_acceptar smallint,
  p_dies_jugar smallint,
  p_pre_inact smallint,
  p_inact smallint
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden modificar settings' USING ERRCODE = '42501';
  END IF;

  UPDATE public.app_settings
     SET dies_acceptar_repte         = p_dies_acceptar,
         dies_jugar_despres_acceptar = p_dies_jugar,
         pre_inactiu_setmanes        = p_pre_inact,
         inactiu_setmanes            = p_inact,
         updated_at                  = now()
   WHERE id = (
     SELECT id FROM public.app_settings
     ORDER BY updated_at DESC
     LIMIT 1
   );
END;
$function$;

-- 3) capture_initial_ranking: wrapper. Add admin check.
CREATE OR REPLACE FUNCTION public.capture_initial_ranking(p_event uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden capturar el rànquing' USING ERRCODE = '42501';
  END IF;

  PERFORM capture_weekly_ranking(p_event);
END;
$function$;

-- 4) admin_run_maintenance: sweeps de manteniment.
CREATE OR REPLACE FUNCTION public.admin_run_maintenance()
 RETURNS TABLE(kind text, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden executar manteniment' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT 'challenges_overdue',
         coalesce(json_agg(row_to_json(t)), '[]'::json)::jsonb
  FROM public.sweep_overdue_challenges_from_settings_mvp2() AS t;

  RETURN QUERY
  SELECT 'inactivity',
         coalesce(json_agg(row_to_json(t)), '[]'::json)::jsonb
  FROM public.sweep_inactivity_from_settings() AS t;
END;
$function$;

-- 5) admin_run_maintenance_and_log: wrapper amb log.
CREATE OR REPLACE FUNCTION public.admin_run_maintenance_and_log(p_triggered_by text DEFAULT 'auto'::text)
 RETURNS TABLE(kind text, payload jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_run_id uuid;
  v_any_rows boolean := false;
  r record;
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden executar manteniment' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.maintenance_runs(triggered_by)
  VALUES (coalesce(p_triggered_by,'auto'))
  RETURNING id INTO v_run_id;

  FOR r IN
    SELECT * FROM public.admin_run_maintenance()
  LOOP
    v_any_rows := true;
    INSERT INTO public.maintenance_run_items(run_id, kind, payload)
    VALUES (v_run_id, r.kind, r.payload);
    kind := r.kind;
    payload := r.payload;
    RETURN NEXT;
  END LOOP;

  UPDATE public.maintenance_runs
     SET finished_at = now(),
         ok = true,
         notes = CASE WHEN v_any_rows THEN NULL ELSE 'Sense canvis' END
   WHERE id = v_run_id;

EXCEPTION WHEN others THEN
  UPDATE public.maintenance_runs
     SET finished_at = now(),
         ok = false,
         notes = coalesce(notes,'') || CASE WHEN coalesce(notes,'')<>'' THEN E'\n' END
                 || 'ERROR: ' || sqlstate || ' - ' || sqlerrm
   WHERE id = v_run_id;
  RAISE;
END;
$function$;

-- 6) apply_challenge_penalty: aplica penalitzacions.
CREATE OR REPLACE FUNCTION public.apply_challenge_penalty(p_challenge uuid, p_tipus text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event   uuid;
  v_reptador uuid;
  v_reptat  uuid;
  v_pos_r   INTEGER;
  v_pos_t   INTEGER;
  v_swap    uuid;
  v_next    uuid;
  v_pos     INTEGER;
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden aplicar penalitzacions' USING ERRCODE = '42501';
  END IF;

  SELECT event_id, reptador_id, reptat_id, pos_reptador, pos_reptat
    INTO v_event, v_reptador, v_reptat, v_pos_r, v_pos_t
    FROM challenges
   WHERE id = p_challenge;

  IF v_event IS NULL THEN
    RETURN json_build_object('ok', FALSE, 'error', 'challenge_not_found');
  END IF;

  IF p_tipus = 'incompareixenca' THEN
    UPDATE challenges SET estat = 'refusat' WHERE id = p_challenge;

    INSERT INTO penalties(event_id, challenge_id, player_id, tipus)
    VALUES (v_event, p_challenge, v_reptat, p_tipus);

    IF v_pos_r IS NOT NULL
       AND v_pos_t IS NOT NULL
       AND v_pos_r <> v_pos_t THEN
      UPDATE ranking_positions
         SET posicio = CASE
            WHEN player_id = v_reptador THEN v_pos_t
            WHEN player_id = v_reptat   THEN v_pos_r
            ELSE posicio
         END
       WHERE event_id = v_event
         AND player_id IN (v_reptador, v_reptat);

      INSERT INTO history_position_changes(
        event_id, player_id, posicio_anterior, posicio_nova,
        motiu, ref_challenge
      )
      VALUES
        (v_event, v_reptador, v_pos_r, v_pos_t,
         'victoria per incompareixença', p_challenge),
        (v_event, v_reptat,   v_pos_t, v_pos_r,
         'derrota per incompareixença', p_challenge);
    END IF;

    RETURN json_build_object('ok', TRUE);

  ELSIF p_tipus = 'desacord_dates' THEN
    FOR v_swap IN
      SELECT player_id
        FROM ranking_positions
       WHERE event_id = v_event
         AND player_id IN (v_reptador, v_reptat)
       ORDER BY posicio
    LOOP
      SELECT posicio INTO v_pos
        FROM ranking_positions
       WHERE event_id = v_event AND player_id = v_swap;

      SELECT player_id INTO v_next
        FROM ranking_positions
       WHERE event_id = v_event AND posicio = v_pos + 1;

      IF v_next IS NOT NULL THEN
        UPDATE ranking_positions
           SET posicio = v_pos + 1
         WHERE event_id = v_event AND player_id = v_swap;

        UPDATE ranking_positions
           SET posicio = v_pos
         WHERE event_id = v_event AND player_id = v_next;

        INSERT INTO history_position_changes(
          event_id, player_id, posicio_anterior, posicio_nova,
          motiu, ref_challenge
        )
        VALUES
          (v_event, v_swap, v_pos, v_pos + 1,
           'penalització desacord dates', p_challenge),
          (v_event, v_next, v_pos + 1, v_pos,
           'puja per penalització', p_challenge);
      END IF;

      INSERT INTO penalties(event_id, challenge_id, player_id, tipus)
      VALUES (v_event, p_challenge, v_swap, p_tipus);
    END LOOP;

    UPDATE challenges SET estat = 'anullat' WHERE id = p_challenge;
    RETURN json_build_object('ok', TRUE);

  ELSE
    RETURN json_build_object('ok', FALSE, 'error', 'tipus_not_supported');
  END IF;
END;
$function$;

-- 7) apply_voluntary_drop: drops player from ranking.
CREATE OR REPLACE FUNCTION public.apply_voluntary_drop(p_event uuid, p_player uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  b RECORD;
  v_pos  INTEGER;
  v_wait uuid;
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden donar de baixa jugadors' USING ERRCODE = '42501';
  END IF;

  SELECT posicio INTO v_pos
    FROM ranking_positions
   WHERE event_id = p_event AND player_id = p_player;

  IF v_pos IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM ranking_positions
   WHERE event_id = p_event AND player_id = p_player;

  INSERT INTO history_position_changes(
    event_id, player_id, posicio_anterior, posicio_nova,
    motiu, ref_challenge
  )
  VALUES (p_event, p_player, v_pos, NULL, 'baixa', NULL);

  FOR b IN
    SELECT player_id, posicio
      FROM ranking_positions
     WHERE event_id = p_event AND posicio > v_pos
     ORDER BY posicio
  LOOP
    UPDATE ranking_positions
       SET posicio = b.posicio - 1
     WHERE event_id = p_event AND player_id = b.player_id;

    INSERT INTO history_position_changes(
      event_id, player_id, posicio_anterior, posicio_nova,
      motiu, ref_challenge
    )
    VALUES (
      p_event,
      b.player_id,
      b.posicio,
      b.posicio - 1,
      'puja per baixa',
      NULL
    );
  END LOOP;

  SELECT player_id INTO v_wait
    FROM waiting_list
   WHERE event_id = p_event
   ORDER BY ordre
   LIMIT 1;

  IF v_wait IS NOT NULL THEN
    INSERT INTO ranking_positions(event_id, player_id, posicio)
    VALUES (p_event, v_wait, 20);

    DELETE FROM waiting_list
      WHERE event_id = p_event AND player_id = v_wait;

    INSERT INTO history_position_changes(
      event_id, player_id, posicio_anterior, posicio_nova,
      motiu, ref_challenge
    )
    VALUES (p_event, v_wait, NULL, 20, 'entra per baixa', NULL);
  END IF;
END;
$function$;

-- 8) retire_player_from_league
CREATE OR REPLACE FUNCTION public.retire_player_from_league(
  p_event_id uuid,
  p_soci_numero integer,
  p_motiu_retirada text DEFAULT 'No especificat'::text,
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
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden retirar jugadors' USING ERRCODE = '42501';
  END IF;

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
    -- No volem amagar el 42501 si ve d'aquí: si és l'auth, deixar-lo propagar.
    IF SQLSTATE = '42501' THEN
      RAISE;
    END IF;
    RETURN json_build_object(
      'success', false,
      'error', format('Error al retirar jugador: %s', SQLERRM)
    );
END;
$function$;

-- 9) generate_final_classifications
CREATE OR REPLACE FUNCTION public.generate_final_classifications(p_event_id uuid)
 RETURNS TABLE(success boolean, message text, classifications_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count INTEGER := 0;
  v_event_record RECORD;
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden generar classificacions finals' USING ERRCODE = '42501';
  END IF;

  SELECT id, nom, estat_competicio INTO v_event_record
  FROM events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Event no trobat', 0;
    RETURN;
  END IF;

  DELETE FROM classificacions WHERE event_id = p_event_id;

  INSERT INTO classificacions (
    event_id, categoria_id, player_id, posicio,
    partides_jugades, partides_guanyades, partides_perdudes, partides_empat,
    punts, caramboles_favor, caramboles_contra, mitjana_particular, updated_at
  )
  SELECT
    p_event_id, cl.categoria_id, cl.player_id, cl.posicio,
    cl.partides_jugades, cl.partides_guanyades, cl.partides_perdudes, cl.partides_empat,
    cl.punts, cl.caramboles_totals AS caramboles_favor, cl.entrades_totals AS caramboles_contra,
    cl.millor_mitjana AS mitjana_particular, NOW()
  FROM get_social_league_classifications(p_event_id) cl;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN QUERY SELECT TRUE,
    format('Classificacions generades correctament: %s jugadors classificats', v_count),
    v_count;
END;
$function$;

-- 10) registrar_incompareixenca
CREATE OR REPLACE FUNCTION public.registrar_incompareixenca(p_partida_id uuid, p_jugador_que_falta smallint)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_partida RECORD;
  v_soci_numero integer;
  v_event_id uuid;
  v_categoria_id uuid;
  v_max_entrades integer;
  v_incompareixences_count smallint;
  v_result json;
BEGIN
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden registrar incompareixences' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_partida FROM calendari_partides WHERE id = p_partida_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partida no trobada';
  END IF;

  IF p_jugador_que_falta = 1 THEN
    v_soci_numero := v_partida.jugador1_soci_numero;
  ELSIF p_jugador_que_falta = 2 THEN
    v_soci_numero := v_partida.jugador2_soci_numero;
  ELSE
    RAISE EXCEPTION 'Jugador invàlid: ha de ser 1 o 2';
  END IF;

  v_event_id := v_partida.event_id;
  v_categoria_id := v_partida.categoria_id;

  IF v_soci_numero IS NULL THEN
    RAISE EXCEPTION 'No s''ha trobat el numero de soci del jugador';
  END IF;

  SELECT max_entrades INTO v_max_entrades FROM categories WHERE id = v_categoria_id;
  IF v_max_entrades IS NULL THEN
    v_max_entrades := 50;
  END IF;

  IF p_jugador_que_falta = 1 THEN
    UPDATE calendari_partides
    SET incompareixenca_jugador1 = true,
      data_incompareixenca = NOW(),
      estat = 'validat',
      caramboles_jugador1 = 0, caramboles_jugador2 = 0,
      entrades_jugador1 = v_max_entrades, entrades_jugador2 = 0,
      entrades = v_max_entrades,
      punts_jugador1 = 0, punts_jugador2 = 2,
      data_joc = NOW(),
      validat_per = NULL, data_validacio = NOW(),
      observacions_junta = COALESCE(observacions_junta || E'\n', '') ||
        '[' || TO_CHAR(NOW(), 'DD/MM/YYYY') || '] Incompareixença jugador 1. Jugador 2: 2 punts, 0 caramboles, 0 entrades. Jugador 1: 0 punts, 0 caramboles, ' || v_max_entrades || ' entrades penalització.'
    WHERE id = p_partida_id;
  ELSE
    UPDATE calendari_partides
    SET incompareixenca_jugador2 = true,
      data_incompareixenca = NOW(),
      estat = 'validat',
      caramboles_jugador1 = 0, caramboles_jugador2 = 0,
      entrades_jugador1 = 0, entrades_jugador2 = v_max_entrades,
      entrades = v_max_entrades,
      punts_jugador1 = 2, punts_jugador2 = 0,
      data_joc = NOW(),
      validat_per = NULL, data_validacio = NOW(),
      observacions_junta = COALESCE(observacions_junta || E'\n', '') ||
        '[' || TO_CHAR(NOW(), 'DD/MM/YYYY') || '] Incompareixença jugador 2. Jugador 1: 2 punts, 0 caramboles, 0 entrades. Jugador 2: 0 punts, 0 caramboles, ' || v_max_entrades || ' entrades penalització.'
    WHERE id = p_partida_id;
  END IF;

  UPDATE inscripcions
  SET incompareixences_count = incompareixences_count + 1
  WHERE soci_numero = v_soci_numero AND event_id = v_event_id
  RETURNING incompareixences_count INTO v_incompareixences_count;

  IF v_incompareixences_count >= 2 THEN
    UPDATE inscripcions
    SET eliminat_per_incompareixences = true,
      data_eliminacio = NOW(),
      estat_jugador = 'retirat',
      data_retirada = NOW(),
      motiu_retirada = 'Desqualificat per 2 incompareixences'
    WHERE soci_numero = v_soci_numero AND event_id = v_event_id;

    UPDATE calendari_partides
    SET partida_anullada = true,
      "motiu_anul·lacio" = 'Jugador eliminat per 2 incompareixences'
    WHERE event_id = v_event_id
      AND (jugador1_soci_numero = v_soci_numero OR jugador2_soci_numero = v_soci_numero)
      AND COALESCE(partida_anullada, false) = false;

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
$function$;

----------------------------------------------------------------------
-- GRUP B · REVOKE EXECUTE de les funcions admin no usades pel front-end.
-- Continuen disponibles per a service_role internament o si es restauren.
----------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.create_initial_ranking_from_ordered_socis(uuid, integer[]) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rotate_waiting_list(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.penalitza_incompareixenca(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.run_inactivity_sweep() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reactivate_player_in_league(uuid, integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_challenge(uuid, uuid, public.challenge_type) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.accept_challenge(uuid, timestamp with time zone) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.marcar_jugador_retirat(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.penalitza_no_acord_dates(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.capture_weekly_ranking(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.apply_disagreement_drop(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;

----------------------------------------------------------------------
-- GRUP C · REVOKE EXECUTE de `anon` per a les RPCs admin de Grup A.
-- Garanteix defense-in-depth: encara que algun ganxo bypassi
-- `is_admin_by_email()`, `anon` no podrà ni cridar la funció.
----------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.reset_full_competition() FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_update_settings(smallint, smallint, smallint, smallint) FROM anon;
REVOKE EXECUTE ON FUNCTION public.capture_initial_ranking(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_run_maintenance() FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_run_maintenance_and_log(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.apply_challenge_penalty(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.apply_voluntary_drop(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.retire_player_from_league(uuid, integer, text, boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.generate_final_classifications(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.registrar_incompareixenca(uuid, smallint) FROM anon;

COMMENT ON FUNCTION public.reset_full_competition() IS 'Reset complet — només admins. Audit: 2026-05-07 hardening.';
COMMENT ON FUNCTION public.admin_update_settings(smallint, smallint, smallint, smallint) IS 'Update app_settings — només admins. Audit: 2026-05-07 hardening.';
