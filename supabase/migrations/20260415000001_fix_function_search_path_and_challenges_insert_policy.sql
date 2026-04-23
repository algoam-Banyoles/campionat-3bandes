-- Migration: Fix Supabase security WARN lints
-- Date: 2026-04-15
--
-- 1) function_search_path_mutable: 5 funcions sense search_path fixat.
--    Si un atacant pot crear objectes en un schema anterior al search_path
--    del caller, podria segrestar noms de taules/funcions referenciats sense
--    qualificar. Solucio: fixar search_path = public, pg_temp.
--
-- 2) rls_policy_always_true: la politica `challenges_insert_auth` tenia
--    `WITH CHECK (true)` i era redundant amb `ins_ch_user` (mateix efecte)
--    i amb "Admins can insert challenges" + "Players can insert challenges".
--    L'eliminem.
--
-- NOTA: Les funcions retire_player_from_league i reactivate_player_in_league
-- referencien la taula `players` que es va eliminar a la fase 5c. Aquest
-- migration nomes arregla el lint (search_path); la logica requereix
-- reescriptura separada.

ALTER FUNCTION public.reactivate_player_in_league(uuid, integer) SET search_path = public, pg_temp;
ALTER FUNCTION public.retire_player_from_league(uuid, integer, text) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_classifications_public(uuid, uuid[]) SET search_path = public, pg_temp;
ALTER FUNCTION public.date_trunc_immutable(timestamptz) SET search_path = public, pg_temp;
ALTER FUNCTION public.set_estat_jugada_when_result_exists() SET search_path = public, pg_temp;

DROP POLICY IF EXISTS "challenges_insert_auth" ON public.challenges;
