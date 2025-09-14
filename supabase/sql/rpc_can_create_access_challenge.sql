create or replace function public.can_create_access_challenge(
  p_event uuid,
  p_reptador uuid,
  p_reptat uuid
) returns table(ok boolean, reason text)
language plpgsql
security definer
as $$
declare
  v_first uuid;
  v_pos_t integer;
  v_last_match timestamp with time zone;
begin
  -- Event actiu
  if not exists (select 1 from events where id = p_event and actiu = true) then
    return query select false, 'L''event no és actiu';
    return;
  end if;

  -- Reptador ha de ser el primer de la llista d'espera
  select player_id into v_first
    from waiting_list
    where event_id = p_event
    order by ordre
    limit 1;

  if v_first is null or v_first <> p_reptador then
    return query select false, 'No és el primer de la llista d''espera';
    return;
  end if;

  -- Reptat ha de ser el #20 del rànquing
  select posicio into v_pos_t
    from ranking_positions
    where event_id = p_event and player_id = p_reptat;
  if v_pos_t is null or v_pos_t <> 20 then
    return query select false, 'El reptat no és el jugador #20';
    return;
  end if;

  -- El reptat ha d'haver jugat almenys un repte dins del rànquing
  select max(m.data_joc) into v_last_match
    from matches m
    join challenges c on c.id = m.challenge_id
    where c.event_id = p_event
      and c.tipus = 'normal'
      and (c.reptador_id = p_reptat or c.reptat_id = p_reptat);
  if v_last_match is null then
    return query select false, 'El jugador reptat encara no ha jugat cap repte al rànquing';
    return;
  end if;

  return query select true, null::text;
end;
$$;

grant execute on function public.can_create_access_challenge(uuid, uuid, uuid) to authenticated;
