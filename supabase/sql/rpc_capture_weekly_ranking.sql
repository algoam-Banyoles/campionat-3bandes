drop function if exists public.capture_initial_ranking(uuid);
drop function if exists public.capture_weekly_ranking(uuid);

create or replace function public.capture_weekly_ranking(p_event uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event uuid;
  v_week integer;
begin
  if p_event is null then
    select id into v_event from events where actiu is true limit 1;
  else
    v_event := p_event;
  end if;

  select coalesce(max(setmana), 0) + 1 into v_week
    from player_weekly_positions
    where event_id = v_event;

  insert into player_weekly_positions(event_id, player_id, setmana, posicio)
  select rp.event_id, rp.player_id, v_week, rp.posicio
    from ranking_positions rp
    where rp.event_id = v_event;
end;
$$;

create or replace function public.capture_initial_ranking(p_event uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform capture_weekly_ranking(p_event);
end;
$$;
