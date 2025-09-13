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
  v_tipus       text;
  v_max         integer;
begin
  select c.event_id, c.reptador_id, c.reptat_id, c.pos_reptador, c.pos_reptat, c.tipus
    into v_event,   v_reptador,    v_reptat,    v_pos_r,        v_pos_t,     v_tipus
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

  if v_tipus = 'access' then
    -- Repte d'accés
    if v_result in ('guanya_reptador','empat_tiebreak_reptador','walkover_reptador') then
      -- reptador entra al rànquing i reptat passa a la llista d'espera
      select coalesce(max(ordre),0) + 1 into v_max
        from waiting_list where event_id = v_event;

      -- treu reptador de la llista d'espera
      delete from waiting_list where event_id = v_event and player_id = v_reptador;

      -- canvia jugador a posició 20
      update ranking_positions
        set player_id = v_reptador
        where event_id = v_event and player_id = v_reptat;

      -- envia reptat al final de la llista
      insert into waiting_list(event_id, player_id, ordre)
        values (v_event, v_reptat, v_max);

      -- registre historial
      insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
        values
          (v_event, v_reptador, null, 20, 'entra per repte d\'accés', p_challenge),
          (v_event, v_reptat,   20,  null, 'baixa per repte d\'accés', p_challenge);

      return query select true, null;
    else
      -- reptador perd: passa a final de la llista d'espera
      select coalesce(max(ordre),0) + 1 into v_max
        from waiting_list where event_id = v_event;
      update waiting_list
        set ordre = v_max, data_inscripcio = now()
        where event_id = v_event and player_id = v_reptador;
      return query select false, 'reptador_loses';
    end if;
  else
    -- Repte normal: intercanvi de posicions si guanya reptador
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
  end if;
end;
$$;

grant execute on function public.apply_match_result(uuid) to authenticated;
