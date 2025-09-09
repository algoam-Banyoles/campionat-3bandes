-- 1) Afegir valors a l'ENUM (si no existeixen)
do $$
begin
  if not exists (select 1 from pg_enum e
                 join pg_type t on t.oid = e.enumtypid
                 where t.typname = 'match_result' and e.enumlabel = 'walkover_reptador') then
    alter type public.match_result add value 'walkover_reptador';
  end if;
  if not exists (select 1 from pg_enum e
                 join pg_type t on t.oid = e.enumtypid
                 where t.typname = 'match_result' and e.enumlabel = 'walkover_reptat') then
    alter type public.match_result add value 'walkover_reptat';
  end if;
end$$;

-- 2) Reemplaça la RPC d'aplicar resultat (inclou walkovers)
create or replace function public.apply_match_result(p_challenge uuid)
returns table(swapped boolean, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event       uuid;
  v_reptador    uuid;
  v_reptat      uuid;
  v_pos_r       smallint;
  v_pos_t       smallint;
  v_result      match_result;
begin
  select c.event_id, c.reptador_id, c.reptat_id, c.pos_reptador, c.pos_reptat
    into v_event,   v_reptador,    v_reptat,    v_pos_r,        v_pos_t
  from public.challenges c
  where c.id = p_challenge;

  if v_event is null then
    return query select false, 'challenge_not_found';
    return;
  end if;

  select m.resultat
    into v_result
  from public.matches m
  where m.challenge_id = p_challenge
  order by m.creat_el desc
  limit 1;

  if v_result is null then
    return query select false, 'match_not_found';
    return;
  end if;

  -- swap només si "guanya reptador" (inclou empat_tiebreak_reptador i walkover_reptador)
  if v_result not in ('guanya_reptador','empat_tiebreak_reptador','walkover_reptador') then
    return query select false, 'no_swap';
  end if;

  if v_pos_r is null or v_pos_t is null or v_pos_r = v_pos_t then
    return query select false, 'positions_missing_or_equal';
  end if;

  update public.ranking_positions rp
  set posicio = case
    when rp.player_id = v_reptador then v_pos_t
    when rp.player_id = v_reptat   then v_pos_r
    else rp.posicio
  end
  where rp.event_id = v_event
    and rp.player_id in (v_reptador, v_reptat);

  insert into public.history_position_changes(
    event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge
  )
  values
    (v_event, v_reptador, v_pos_r, v_pos_t, 'victoria reptador', p_challenge),
    (v_event, v_reptat,   v_pos_t, v_pos_r, 'derrota reptat',    p_challenge);

  return query select true, null;
end;
$$;

grant execute on function public.apply_match_result(uuid) to authenticated;
