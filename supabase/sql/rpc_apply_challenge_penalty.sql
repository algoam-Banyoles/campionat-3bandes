create or replace function public.apply_challenge_penalty(
  p_challenge uuid,
  p_tipus text
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event uuid;
  v_reptador uuid;
  v_reptat uuid;
  v_pos_r integer;
  v_pos_t integer;
  v_swap uuid;
  v_next uuid;
  v_pos integer;
begin
  select event_id, reptador_id, reptat_id, pos_reptador, pos_reptat
    into v_event, v_reptador, v_reptat, v_pos_r, v_pos_t
    from challenges
   where id = p_challenge;
  if v_event is null then
    return json_build_object('ok', false, 'error', 'challenge_not_found');
  end if;

  if p_tipus = 'incompareixenca' then
    -- mark challenge as refused and give victory to reptador
    update challenges set estat = 'refusat' where id = p_challenge;
    insert into penalties(event_id, challenge_id, player_id, tipus)
      values (v_event, p_challenge, v_reptat, p_tipus);

    if v_pos_r is not null and v_pos_t is not null and v_pos_r <> v_pos_t then
      update ranking_positions
        set posicio = case
          when player_id = v_reptador then v_pos_t
          when player_id = v_reptat   then v_pos_r
          else posicio end
        where event_id = v_event and player_id in (v_reptador, v_reptat);

      insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
        values
          (v_event, v_reptador, v_pos_r, v_pos_t, 'victoria per incompareixença', p_challenge),
          (v_event, v_reptat,   v_pos_t, v_pos_r, 'derrota per incompareixença', p_challenge);
    end if;
    return json_build_object('ok', true);
  elsif p_tipus = 'desacord_dates' then
    -- both players drop one position
    for v_swap in select player_id from ranking_positions
                   where event_id = v_event and player_id in (v_reptador, v_reptat)
                   order by posicio asc
    loop
      select posicio into v_pos from ranking_positions
        where event_id = v_event and player_id = v_swap;
      select player_id into v_next from ranking_positions
        where event_id = v_event and posicio = v_pos + 1;
      if v_next is not null then
        update ranking_positions set posicio = v_pos + 1
          where event_id = v_event and player_id = v_swap;
        update ranking_positions set posicio = v_pos
          where event_id = v_event and player_id = v_next;
        insert into history_position_changes(event_id, player_id, posicio_anterior, posicio_nova, motiu, ref_challenge)
          values
            (v_event, v_swap, v_pos, v_pos + 1, 'penalització desacord dates', p_challenge),
            (v_event, v_next, v_pos + 1, v_pos, 'puja per penalització', p_challenge);
      end if;
      insert into penalties(event_id, challenge_id, player_id, tipus)
        values (v_event, p_challenge, v_swap, p_tipus);
    end loop;
    update challenges set estat = 'anullat' where id = p_challenge;
    return json_build_object('ok', true);
  else
    return json_build_object('ok', false, 'error', 'tipus_not_supported');
  end if;
end;
$$;

grant execute on function public.apply_challenge_penalty(uuid, text) to authenticated, service_role;
