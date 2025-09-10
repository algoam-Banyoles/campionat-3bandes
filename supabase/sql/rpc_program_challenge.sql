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
begin
  select data_acceptacio, coalesce(reprogram_count,0)
    into v_old, v_reprogram
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
      set data_acceptacio = p_when,
          estat = 'programat',
          reprogram_count = v_reprogram + 1
      where id = p_challenge;
  else
    update challenges
      set data_acceptacio = p_when,
          estat = 'programat'
      where id = p_challenge;
  end if;

  return query select true, null::text;
end;
$$;

grant execute on function public.program_challenge(uuid, timestamp with time zone) to authenticated;
