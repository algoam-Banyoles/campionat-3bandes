-- Migration: Fix Supabase linter security errors
-- Date: 2026-04-15
--
-- 1) security_definer_view: Les 5 vistes s'executaven amb els permisos del
--    propietari (postgres) enlloc del caller. Postgres 15+ suporta l'opcio
--    `security_invoker` que fa que la vista respecti RLS i permisos del
--    rol que hi consulta. La migracio anterior (20251212000001) va recrear
--    les vistes sense SECURITY DEFINER pero sense activar explicitament
--    security_invoker, i el linter segueix marcant-les.
--
-- 2) rls_disabled_in_public: La taula `socis_jugador` (creada a la fase 5c)
--    esta exposada via PostgREST pero no te RLS activada.

-- ============================================================================
-- 1) Forca security_invoker a les 5 vistes publiques
-- ============================================================================
ALTER VIEW public.v_player_timeline        SET (security_invoker = true);
ALTER VIEW public.v_player_badges          SET (security_invoker = true);
ALTER VIEW public.v_challenges_pending     SET (security_invoker = true);
ALTER VIEW public.v_analisi_calendari      SET (security_invoker = true);
ALTER VIEW public.v_promocions_candidates  SET (security_invoker = true);

-- ============================================================================
-- 2) RLS a socis_jugador
-- Patro igual que handicap_*: SELECT public, CUD per autenticats.
-- ============================================================================
ALTER TABLE public.socis_jugador ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "socis_jugador_select_all" ON public.socis_jugador;
CREATE POLICY "socis_jugador_select_all" ON public.socis_jugador
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "socis_jugador_insert_auth" ON public.socis_jugador;
CREATE POLICY "socis_jugador_insert_auth" ON public.socis_jugador
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "socis_jugador_update_auth" ON public.socis_jugador;
CREATE POLICY "socis_jugador_update_auth" ON public.socis_jugador
  FOR UPDATE USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "socis_jugador_delete_auth" ON public.socis_jugador;
CREATE POLICY "socis_jugador_delete_auth" ON public.socis_jugador
  FOR DELETE USING (auth.uid() IS NOT NULL);
