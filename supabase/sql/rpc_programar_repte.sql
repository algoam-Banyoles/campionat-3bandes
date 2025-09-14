create or replace function public.programar_repte(
  p_challenge uuid,
  p_data timestamp with time zone,
  p_actor_email text
) returns table(ok boolean, error text)
language plpgsql
security definer
as $$
declare
  v_old timestamptz;
  v_reprogram integer;
  v_estat text;
  v_is_admin boolean;
begin
  select data_programada, coalesce(reprogram_count,0), estat
    into v_old, v_reprogram, v_estat
    from challenges
    where id = p_challenge;
  if not found then
    return query select false, 'Repte no trobat';
    return;
  end if;

  select exists(select 1 from admins where email = p_actor_email)
    into v_is_admin;

  if v_old is not null and v_old <> p_data then
    if not v_is_admin and v_reprogram >= 1 then
      return query select false, 'Només una reprogramació; contacta un administrador';
      return;
    end if;
    update challenges
      set data_programada = p_data,
          estat = 'programat',
          reprogram_count = v_reprogram + 1,
          data_acceptacio = case when v_estat = 'proposat' then now() else data_acceptacio end
      where id = p_challenge;
  else
    update challenges
      set data_programada = p_data,
          estat = 'programat',
          data_acceptacio = case when v_estat = 'proposat' then now() else data_acceptacio end
      where id = p_challenge;
  end if;

  return query select true, null::text;
end;
$$;

grant execute on function public.programar_repte(uuid, timestamp with time zone, text) to authenticated;
