-- Fix d'admin checks legacy + REVOKEs defense-in-depth.
--
-- Canvis:
--   1) `programar_repte`: substitueix `is_admin(p_actor_email)` (que confiava
--      en un email arbitrari del client) per `is_admin_by_email()` (JWT).
--   2) `sel_pens` (penalties): usava `is_admin()` (no-args) que no funciona
--      en Supabase (mai retorna true). Substituïm per `is_admin_by_email()`.
--   3) Drop `public.is_admin()` (no-args) i `public.is_admin(text)` —
--      ja no s'usen i la versió amb arg era un anti-patró de seguretat.
--   4) Drop `public.is_current_user_admin()` — substituït per `is_admin_by_email()`.
--   5) REVOKE EXECUTE de anon a totes les RPCs admin (les que ja tenen
--      check intern; defense-in-depth + silenciar advisor).
--   6) REVOKE EXECUTE de anon/authenticated als triggers `_audit_*` que
--      mai s'haurien de cridar directament.

----------------------------------------------------------------------
-- 1) programar_repte
----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.programar_repte(p_challenge uuid, p_data timestamp with time zone, p_actor_email text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_is_admin boolean;
  cur_reprog smallint;
  cur_estat public.challenge_state;
begin
  -- p_actor_email es manté per compatibilitat de signatura, però IGNORAT.
  -- L'admin check ara es fa amb el JWT del caller (no es pot suplantar).
  v_is_admin := public.is_admin_by_email();

  select reprogramacions, estat into cur_reprog, cur_estat
  from public.challenges where id = p_challenge;

  if cur_estat not in ('proposat','acceptat','programat') then
    return json_build_object('ok', false, 'error', 'Aquest repte no es pot programar');
  end if;

  if not v_is_admin and cur_reprog >= 1 then
    return json_build_object('ok', false, 'error', 'Ja s''ha reprogramat una vegada (cal administrador)');
  end if;

  update public.challenges
  set data_programada = p_data,
      estat = 'programat',
      reprogramacions = case when cur_estat = 'programat' then reprogramacions + 1 else reprogramacions end
  where id = p_challenge;

  return json_build_object('ok', true);
end;
$function$;

----------------------------------------------------------------------
-- 2) sel_pens — penalties
----------------------------------------------------------------------
DROP POLICY IF EXISTS "sel_pens" ON public.penalties;
CREATE POLICY "Admins poden veure penalties" ON public.penalties
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- 3-4) Drop legacy admin functions
----------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.is_admin();
DROP FUNCTION IF EXISTS public.is_admin(text);
DROP FUNCTION IF EXISTS public.is_current_user_admin();

----------------------------------------------------------------------
-- 5) REVOKE anon EXECUTE de RPCs admin (defense-in-depth)
----------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.admin_apply_disagreement(uuid, uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_apply_no_show(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_reset_championship() FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_update_challenge_state(uuid, public.challenge_state) FROM anon;
REVOKE EXECUTE ON FUNCTION public.program_challenge(uuid, timestamp with time zone) FROM anon;
REVOKE EXECUTE ON FUNCTION public.programar_repte(uuid, timestamp with time zone, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.rpc_update_event_status(uuid, text) FROM anon;

----------------------------------------------------------------------
-- 6) REVOKE de triggers _audit_*_trigger
----------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public._audit_actor_email() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._audit_events_trigger() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._audit_inscripcions_trigger() FROM PUBLIC, anon, authenticated;
