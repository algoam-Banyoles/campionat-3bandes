create or replace function public.can_create_challenge(
  p_event uuid,
  p_reptador uuid,
  p_reptat uuid
) returns table(ok boolean, reason text)
language plpgsql
security definer
as $$
declare
  v_max_gap integer;
  v_cd_min integer;
  v_cd_max integer;
  v_pos_reptador integer;
  v_pos_reptat integer;
  v_last timestamp with time zone;
  v_days integer;
begin
  -- Load configuration with defaults
  select coalesce(max_rank_gap, 2),
         coalesce(cooldown_days_min, 7),
         cooldown_days_max
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

  -- Rank gap check
  if abs(v_pos_reptador - v_pos_reptat) > v_max_gap then
    return query select false, 'Diferència de posicions massa gran';
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
    return query select false, 'El reptador o el reptat ja té un repte actiu';
    return;
  end if;

  -- Cooldown between the same players
  select max(coalesce(data_joc, data_acceptacio, data_proposta))
    into v_last
    from challenges
    where event_id = p_event
      and ((reptador_id = p_reptador and reptat_id = p_reptat)
           or (reptador_id = p_reptat and reptat_id = p_reptador))
      and estat not in ('proposat','acceptat','programat');
  if v_last is not null then
    v_days := (now()::date - v_last::date);
    if v_days < v_cd_min then
      return query select false, 'No s''ha respectat el temps mínim entre reptes';
      return;
    end if;
    if v_cd_max is not null and v_days > v_cd_max then
      return query select false, 'S''ha excedit el temps màxim entre reptes';
      return;
    end if;
  end if;

  return query select true, null::text;
end;
$$;

grant execute on function public.can_create_challenge(uuid, uuid, uuid) to authenticated;
