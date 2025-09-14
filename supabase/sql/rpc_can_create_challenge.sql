create or replace function public.can_create_challenge(
  p_event uuid,
  p_reptador uuid,
  p_reptat uuid
) returns table(ok boolean, reason text, warning text)
language plpgsql
security definer
as $$
declare
  v_max_gap integer;
  v_cd_min integer;
  v_cd_max integer;
  v_pos_reptador integer;
  v_pos_reptat integer;
  v_last_r timestamp with time zone;
  v_last_t timestamp with time zone;
  v_days_r integer;
  v_days_t integer;
  v_warn text;
begin
  -- Load configuration with defaults
  select coalesce(max_rank_gap, 2),
         coalesce(cooldown_min_dies, 7),
         cooldown_max_dies
    into v_max_gap, v_cd_min, v_cd_max
    from app_settings
    order by updated_at desc
    limit 1;
  if not found then
    v_max_gap := 2;
    v_cd_min := 7;
    v_cd_max := null;
  end if;

  -- Players must be active
  if not exists (select 1 from players where id = p_reptador and estat = 'actiu') then
    return query select false, 'El reptador no és un jugador actiu';
    return;
  end if;
  if not exists (select 1 from players where id = p_reptat and estat = 'actiu') then
    return query select false, 'El reptat no és un jugador actiu';
    return;
  end if;

  -- Cannot challenge oneself
  if p_reptador = p_reptat then
    return query select false, 'No es pot reptar a un mateix';
    return;
  end if;

  -- Event must be active
  if not exists (select 1 from events where id = p_event and actiu = true) then
    return query select false, 'L''event no és actiu';
    return;
  end if;

  -- Players must belong to ranking of the event
  select posicio into v_pos_reptador
    from ranking_positions
    where event_id = p_event and player_id = p_reptador;
  if v_pos_reptador is null then
    return query select false, 'El reptador no està al rànquing de l''event';
    return;
  end if;
  select posicio into v_pos_reptat
    from ranking_positions
    where event_id = p_event and player_id = p_reptat;
  if v_pos_reptat is null then
    return query select false, 'El reptat no està al rànquing de l''event';
    return;
  end if;

  -- Rank gap check: only challenge up to v_max_gap positions above
  if (v_pos_reptador - v_pos_reptat) <= 0 or (v_pos_reptador - v_pos_reptat) > v_max_gap then
    return query select false,
      'Només es pot reptar fins a ' || v_max_gap || ' posicions per sobre';
    return;
  end if;

  -- No active challenges for either player
  if exists (
      select 1
      from challenges
      where event_id = p_event
        and estat in ('proposat','acceptat','programat')
        and (reptador_id in (p_reptador, p_reptat) or reptat_id in (p_reptador, p_reptat))
  ) then
    return query select false, 'El reptador o el reptat ja té un repte actiu', null::text;
    return;
  end if;

  -- Individual cooldown for reptador
  select max(m.data_joc)
    into v_last_r
    from matches m
    join challenges c on c.id = m.challenge_id
   where c.event_id = p_event
     and (c.reptador_id = p_reptador or c.reptat_id = p_reptador);
  if v_last_r is not null then
    v_days_r := (now()::date - v_last_r::date);
    if v_days_r < v_cd_min then
      return query select false, 'Has d''esperar ' || (v_cd_min - v_days_r) || ' dies més', null::text;
      return;
    end if;
  end if;

  -- Individual cooldown for reptat
  select max(m.data_joc)
    into v_last_t
    from matches m
    join challenges c on c.id = m.challenge_id
   where c.event_id = p_event
     and (c.reptador_id = p_reptat or c.reptat_id = p_reptat);
  if v_last_t is not null then
    v_days_t := (now()::date - v_last_t::date);
    if v_days_t < v_cd_min then
      return query select false, 'Has d''esperar ' || (v_cd_min - v_days_t) || ' dies més', null::text;
      return;
    end if;
  end if;

  -- Prepare warning if cooldown max exceeded
  if v_cd_max is not null then
    if (v_days_r is not null and v_days_r > v_cd_max) or (v_days_t is not null and v_days_t > v_cd_max) then
      v_warn := 'S''ha excedit el temps màxim entre reptes jugats';
    end if;
  end if;

  return query select true, null::text, v_warn;
end;
$$;

grant execute on function public.can_create_challenge(uuid, uuid, uuid) to authenticated;
