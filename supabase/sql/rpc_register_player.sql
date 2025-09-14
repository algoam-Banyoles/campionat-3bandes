create or replace function public.register_player(
  p_event uuid,
  p_player uuid
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_challenge boolean;
  v_rank_count integer;
  v_pos integer;
  v_wait integer;
begin
  -- already in ranking?
  if exists(select 1 from ranking_positions where event_id = p_event and player_id = p_player) then
    return json_build_object('ok', false, 'error', 'Jugador ja inscrit al r\u00e0nquing');
  end if;
  if exists(select 1 from waiting_list where event_id = p_event and player_id = p_player) then
    return json_build_object('ok', false, 'error', 'Jugador ja en llista d\u2019espera');
  end if;

  select count(*) > 0 into v_has_challenge from challenges where event_id = p_event;
  select count(*) into v_rank_count from ranking_positions where event_id = p_event;

  if not v_has_challenge then
    -- initial phase: order by average
    if v_rank_count >= 20 then
      return json_build_object('ok', false, 'error', 'R\u00e0nquing complet');
    end if;
    insert into ranking_positions(event_id, posicio, player_id)
      values (p_event, v_rank_count + 1, p_player);
    with ranks as (
      select rp.id,
             row_number() over(order by p.mitjana desc nulls last, rp.posicio) as new_pos
      from ranking_positions rp
      join players p on p.id = rp.player_id
      where rp.event_id = p_event
    )
    update ranking_positions rp
      set posicio = r.new_pos
      from ranks r
      where rp.id = r.id;
    select posicio into v_pos from ranking_positions where event_id = p_event and player_id = p_player;
    return json_build_object('ok', true, 'posicio', v_pos, 'waiting', false);
  else
    -- competition already started
    if v_rank_count < 20 then
      select min(pos) into v_pos from (
        select generate_series(1,20) as pos
        except
        select posicio from ranking_positions where event_id = p_event
      ) s;
      if v_pos is null then v_pos := v_rank_count + 1; end if;
      insert into ranking_positions(event_id, posicio, player_id)
        values (p_event, v_pos, p_player);
      return json_build_object('ok', true, 'posicio', v_pos, 'waiting', false);
    else
      select coalesce(max(ordre),0) + 1 into v_wait from waiting_list where event_id = p_event;
      insert into waiting_list(event_id, player_id, ordre)
        values (p_event, p_player, v_wait);
      return json_build_object('ok', true, 'ordre', v_wait, 'waiting', true);
    end if;
  end if;
end;
$$;

grant execute on function public.register_player(uuid, uuid) to authenticated;
