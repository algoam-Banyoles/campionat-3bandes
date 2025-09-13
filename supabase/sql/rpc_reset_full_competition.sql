create or replace function public.reset_full_competition()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_matches integer;
  v_history integer;
  v_penalties integer;
  v_challenges integer;
  v_ranking integer;
  v_waitlist integer;
  v_events integer;
  v_players integer;
  v_event_id uuid;
  v_player_id uuid;
  i integer;
begin
  select count(*) into v_matches from matches;
  select count(*) into v_history from history_position_changes;
  select count(*) into v_penalties from penalties;
  select count(*) into v_challenges from challenges;
  select count(*) into v_ranking from ranking_positions;
  select count(*) into v_waitlist from waiting_list;
  select count(*) into v_events from events;
  select count(*) into v_players from players;

  truncate table matches cascade;
  truncate table history_position_changes cascade;
  truncate table penalties cascade;
  truncate table challenges cascade;
  truncate table ranking_positions cascade;
  truncate table waiting_list cascade;
  truncate table events cascade;
  truncate table players cascade;

  insert into events(nom, temporada, actiu)
    values ('Campionat Continu 3 Bandes', to_char(now(),'YYYY-YYYY'), true)
    returning id into v_event_id;

  for i in 1..20 loop
    insert into players(nom, email, estat)
      values (format('Jugador %02s', i), null, 'actiu')
      returning id into v_player_id;
    insert into ranking_positions(event_id, posicio, player_id)
      values (v_event_id, i, v_player_id);
  end loop;

  for i in 1..5 loop
    insert into players(nom, email, estat)
      values (format('Aspirant %02s', i), null, 'actiu')
      returning id into v_player_id;
    insert into waiting_list(event_id, player_id, ordre)
      values (v_event_id, v_player_id, i);
  end loop;

  return json_build_object(
    'ok', true,
    'event_id', v_event_id,
    'deleted', json_build_object(
      'matches', v_matches,
      'history_position_changes', v_history,
      'penalties', v_penalties,
      'challenges', v_challenges,
      'ranking_positions', v_ranking,
      'waiting_list', v_waitlist,
      'events', v_events,
      'players', v_players
    ),
    'seeded', json_build_object(
      'ranking_players', 20,
      'waiting_list', 5
    )
  );
end;
$$;

grant execute on function public.reset_full_competition() to anon, authenticated, service_role;
