-- Migració: Funció per reset del campionat amb preservació de dades
-- Preserva: socis, mitjanes_historiques
-- Esborra: totes les altres dades del campionat
-- Crea: nou esdeveniment de campionat

-- Funció per fer reset del campionat preservant socis i mitjanes històriques
CREATE OR REPLACE FUNCTION public.admin_reset_championship()
RETURNS json
LANGUAGE plpgsql
SECURITY definer
SET search_path = public
AS $$
DECLARE
  v_matches integer;
  v_history integer;
  v_penalties integer;
  v_challenges integer;
  v_ranking integer;
  v_waitlist integer;
  v_events integer;
  v_weekly_pos integer;
  v_notifications_history integer;
  v_scheduled_notifications integer;
  v_club_events integer;
  v_players_reset integer;
  v_event_id uuid;
  v_current_year text;
BEGIN
  -- Verificar que qui crida la funció és admin
  IF NOT is_admin_by_email() THEN
    RAISE EXCEPTION 'No tens permisos d''administrador per executar aquesta funció';
  END IF;

  -- Comptar registres abans del reset
  SELECT count(*) INTO v_matches FROM matches;
  SELECT count(*) INTO v_history FROM history_position_changes;
  SELECT count(*) INTO v_penalties FROM penalties;
  SELECT count(*) INTO v_challenges FROM challenges;
  SELECT count(*) INTO v_ranking FROM ranking_positions;
  SELECT count(*) INTO v_waitlist FROM waiting_list;
  SELECT count(*) INTO v_events FROM events;
  SELECT count(*) INTO v_weekly_pos FROM player_weekly_positions;
  
  -- Comptar notificacions si les taules existeixen
  SELECT count(*) INTO v_notifications_history 
  FROM notification_history WHERE 1=1;
  SELECT count(*) INTO v_scheduled_notifications 
  FROM scheduled_notifications WHERE 1=1;
  
  -- Comptar esdeveniments del club si la taula existeix
  SELECT count(*) INTO v_club_events 
  FROM esdeveniments_club WHERE 1=1;
  
  SELECT count(*) INTO v_players_reset FROM players;

  -- ESBORRAR DADES DEL CAMPIONAT (preservant socis i mitjanes_historiques)
  TRUNCATE TABLE matches CASCADE;
  TRUNCATE TABLE history_position_changes CASCADE;
  TRUNCATE TABLE penalties CASCADE;
  TRUNCATE TABLE challenges CASCADE;
  TRUNCATE TABLE ranking_positions CASCADE;
  TRUNCATE TABLE waiting_list CASCADE;
  TRUNCATE TABLE events CASCADE;
  TRUNCATE TABLE player_weekly_positions CASCADE;
  
  -- Esborrar sistema de notificacions (si existeix)
  TRUNCATE TABLE notification_history CASCADE;
  TRUNCATE TABLE scheduled_notifications CASCADE;
  
  -- Esborrar esdeveniments del club (si existeix)
  TRUNCATE TABLE esdeveniments_club CASCADE;
  
  -- Reiniciar jugadors (mantenir jugadors però reiniciar estat)
  UPDATE players 
  SET estat = 'actiu',
      data_ultim_repte = NULL;

  -- CREAR NOU CAMPIONAT
  v_current_year := EXTRACT(YEAR FROM NOW())::text;
  
  INSERT INTO events(nom, temporada, actiu)
  VALUES (
    'Campionat Continu 3 Bandes', 
    v_current_year || '-' || (EXTRACT(YEAR FROM NOW()) + 1)::text, 
    true
  )
  RETURNING id INTO v_event_id;

  -- Inserir configuració d'app si no existeix
  IF NOT EXISTS (SELECT 1 FROM app_settings LIMIT 1) THEN
    INSERT INTO app_settings DEFAULT VALUES;
  END IF;

  RETURN json_build_object(
    'ok', true,
    'timestamp', NOW(),
    'new_event_id', v_event_id,
    'new_event_name', 'Campionat Continu 3 Bandes',
    'new_season', v_current_year || '-' || (EXTRACT(YEAR FROM NOW()) + 1)::text,
    'deleted_records', json_build_object(
      'matches', v_matches,
      'history_position_changes', v_history,
      'penalties', v_penalties,
      'challenges', v_challenges,
      'ranking_positions', v_ranking,
      'waiting_list', v_waitlist,
      'events', v_events,
      'player_weekly_positions', v_weekly_pos,
      'notification_history', v_notifications_history,
      'scheduled_notifications', v_scheduled_notifications,
      'esdeveniments_club', v_club_events
    ),
    'preserved_tables', json_build_array('socis', 'mitjanes_historiques'),
    'players_reset_count', v_players_reset,
    'message', 'Reset del campionat completat. S''han preservat les dades dels socis i mitjanes històriques.'
  );
END;
$$;

-- Donar permisos només als rols necessaris (no anon per seguretat)
GRANT EXECUTE ON FUNCTION public.admin_reset_championship() TO authenticated, service_role;