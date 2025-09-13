create or replace function public.program_challenge(
  p_challenge uuid,
  p_when timestamp with time zone
) returns table(ok boolean, reason text)
language plpgsql
security definer
as $$
declare
  v_old timestamptz;
  v_reprogram integer;
  v_is_admin boolean;
  v_estat text;
begin
  select data_programada, coalesce(reprogram_count,0), estat
    into v_old, v_reprogram, v_estat
    from challenges
    where id = p_challenge;
  if not found then
    return query select false, 'Repte no trobat';
    return;
  end if;

  select exists(select 1 from admins where email = auth.jwt() ->> 'email')
    into v_is_admin;

  if v_old is not null and v_old <> p_when then
    if not v_is_admin and v_reprogram >= 1 then
      return query select false, 'Només un canvi de data; contacta un administrador';
      return;
    end if;
    update challenges
      set data_programada = p_when,
          estat = 'programat',
          reprogram_count = v_reprogram + 1,
          data_acceptacio = case when v_estat = 'proposat' then now() else data_acceptacio end
      where id = p_challenge;
  else
    update challenges
      set data_programada = p_when,
          estat = 'programat',
          data_acceptacio = case when v_estat = 'proposat' then now() else data_acceptacio end
      where id = p_challenge;
  end if;

  return query select true, null::text;
end;
$$;

grant execute on function public.program_challenge(uuid, timestamp with time zone) to authenticated;

