create or replace function public.apply_pre_inactivity(
  p_event uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_old_pos integer;
  v_new_pos integer;
  v_waiting uuid;
  v_new_order integer;
  v_moved record;
begin
  for r in
    select rp.player_id
    from ranking_positions rp
    where rp.event_id = p_event
      and not exists (
        select 1
        from challenges c
        left join matches m on m.challenge_id = c.id
        where c.event_id = p_event
          and (c.reptador_id = rp.player_id or c.reptat_id = rp.player_id)
          and (
            (c.estat = 'programat' and c.data_programada >= now() - interval '21 days') or
            (c.estat = 'jugat' and m.data_joc >= now() - interval '21 days')
          )
      )
    order by rp.posicio
  loop
    select posicio into v_old_pos
      from ranking_positions
      where event_id = p_event and player_id = r.player_id;
    if v_old_pos is null then
      continue;
    end if;
    v_new_pos := v_old_pos + 5;

    for v_moved in
      select player_id, posicio
      from ranking_positions
      where event_id = p_event
        and posicio > v_old_pos
        and posicio <= v_old_pos + 5
      order by posicio
    loop
      update ranking_positions
        set posicio = v_moved.posicio - 1
        where event_id = p_event and player_id = v_moved.player_id;
      insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
        values (p_event, v_moved.player_id, v_moved.posicio, v_moved.posicio - 1, 'puja per pre-inactivitat', null);
    end loop;

    if v_new_pos > 20 then
      select player_id into v_waiting
        from waiting_list
        where event_id = p_event
        order by ordre
        limit 1;

      select coalesce(max(ordre),0)+1 into v_new_order
        from waiting_list
        where event_id = p_event;

      insert into waiting_list(event_id, player_id, ordre)
        values (p_event, r.player_id, v_new_order);

      delete from ranking_positions
        where event_id = p_event and player_id = r.player_id;

      insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
        values (p_event, r.player_id, v_old_pos, null, 'baixa per pre-inactivitat', null);

      if v_waiting is not null then
        insert into ranking_positions(event_id, player_id, posicio)
          values (p_event, v_waiting, 20);
        delete from waiting_list
          where event_id = p_event and player_id = v_waiting;
        insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
          values (p_event, v_waiting, null, 20, 'entra per pre-inactivitat', null);
      end if;
    else
      update ranking_positions
        set posicio = v_new_pos
        where event_id = p_event and player_id = r.player_id;
      insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
        values (p_event, r.player_id, v_old_pos, v_new_pos, 'baixa per pre-inactivitat', null);
    end if;
  end loop;
end;
$$;

grant execute on function public.apply_pre_inactivity(uuid) to authenticated;
