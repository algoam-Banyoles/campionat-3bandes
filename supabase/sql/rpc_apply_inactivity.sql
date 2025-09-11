create or replace function public.apply_inactivity(p_event uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  b record;
  v_pos integer;
  v_wait uuid;
begin
  for r in (
    select rp.player_id
    from ranking_positions rp
    where rp.event_id = p_event
      and not exists (
        select 1
        from challenges c
        left join matches m on m.challenge_id = c.id
        where c.event_id = p_event
          and (c.reptador_id = rp.player_id or c.reptat_id = rp.player_id)
          and coalesce(m.data_joc, c.data_proposta) >= (now() - interval '42 days')
      )
    order by rp.posicio
  ) loop
    -- current position
    select posicio into v_pos
      from ranking_positions
      where event_id = p_event and player_id = r.player_id;
    if v_pos is null then
      continue;
    end if;

    -- mark player inactive
    update players set estat = 'inactiu' where id = r.player_id;

    -- remove from ranking
    delete from ranking_positions
      where event_id = p_event and player_id = r.player_id;

    -- history for removed player
    insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
      values (p_event, r.player_id, v_pos, null, 'inactivitat', null);

    -- shift players below
    for b in (
      select player_id, posicio
      from ranking_positions
      where event_id = p_event and posicio > v_pos
      order by posicio
    ) loop
      update ranking_positions
        set posicio = b.posicio - 1
        where event_id = p_event and player_id = b.player_id;
      insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
        values (p_event, b.player_id, b.posicio, b.posicio - 1, 'puja per inactivitat', null);
    end loop;

    -- fill 20th position from waiting list
    select player_id into v_wait
      from waiting_list
      where event_id = p_event
      order by ordre asc
      limit 1;
    if v_wait is not null then
      insert into ranking_positions(event_id, player_id, posicio)
        values (p_event, v_wait, 20);
      delete from waiting_list
        where event_id = p_event and player_id = v_wait;
      insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
        values (p_event, v_wait, null, 20, 'entra per inactivitat', null);
    end if;
  end loop;
end;
$$;

grant execute on function public.apply_inactivity(uuid) to authenticated;
