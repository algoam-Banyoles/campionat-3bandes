create or replace function public.apply_voluntary_drop(
  p_event uuid,
  p_player uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  b record;
  v_pos integer;
  v_wait uuid;
begin
  select posicio into v_pos
    from ranking_positions
    where event_id = p_event and player_id = p_player;
  if v_pos is null then
    return;
  end if;

  delete from ranking_positions
    where event_id = p_event and player_id = p_player;

  insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
    values (p_event, p_player, v_pos, null, 'baixa', null);

  for b in
    select player_id, posicio
    from ranking_positions
    where event_id = p_event and posicio > v_pos
    order by posicio
  loop
    update ranking_positions
      set posicio = b.posicio - 1
      where event_id = p_event and player_id = b.player_id;
    insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
      values (p_event, b.player_id, b.posicio, b.posicio - 1, 'puja per baixa', null);
  end loop;

  select player_id into v_wait
    from waiting_list
    where event_id = p_event
    order by ordre
    limit 1;

  if v_wait is not null then
    insert into ranking_positions(event_id, player_id, posicio)
      values (p_event, v_wait, 20);
    delete from waiting_list
      where event_id = p_event and player_id = v_wait;
    insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
      values (p_event, v_wait, null, 20, 'entra per baixa', null);
  end if;
end;
$$;

grant execute on function public.apply_voluntary_drop(uuid, uuid) to authenticated;
