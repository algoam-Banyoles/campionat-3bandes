create or replace function public.rotate_waiting_list(p_event uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_first record;
  v_max integer;
begin
  select player_id, ordre, data_inscripcio into v_first
    from waiting_list
    where event_id = p_event
    order by ordre
    limit 1;
  if v_first.player_id is null then
    return;
  end if;
  if v_first.data_inscripcio < now() - interval '15 days' then
    select coalesce(max(ordre),0) + 1 into v_max
      from waiting_list
      where event_id = p_event;
    update waiting_list
      set ordre = v_max,
          data_inscripcio = now()
      where event_id = p_event and player_id = v_first.player_id;
  end if;
end;
$$;

grant execute on function public.rotate_waiting_list(uuid) to authenticated;
