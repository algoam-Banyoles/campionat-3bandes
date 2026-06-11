-- ============================================================================
-- Migració: Restringir escriptura a taules handicap_* només a admins
-- Data: 2026-06-10
-- Motivació: Les policies originals (20260317000000_create_handicap_tables.sql)
--   permetien INSERT/UPDATE/DELETE a qualsevol usuari autenticat.
--
-- Investigació de fluxos no-admin:
--   - handicap_config     → escrit NOMÉS per /handicap/configuracio ($effectiveIsAdmin)
--   - handicap_participants→ escrit NOMÉS per /handicap/inscripcions ($effectiveIsAdmin)
--   - handicap_bracket_slots→ escrit per handicap-bracket-db.ts, handicap-propagation.ts,
--                              handicap-schedule-persist.ts — tots invocats des de pàgines
--                              admin-gated (/handicap/sorteig, /handicap/partides, etc.)
--   - handicap_matches    → igual que bracket_slots
--
--   NO existeix cap taula "handicap_availability": la disponibilitat es guarda
--   a handicap_participants.preferencies_dies / preferencies_hores.
--   La HandicapAvailabilityGrid.svelte NO fa cap escriptura directa a Supabase.
--
-- Taules canviades (write → admin-only):
--   1. handicap_config
--   2. handicap_participants
--   3. handicap_bracket_slots
--   4. handicap_matches
--
-- Taules deliberadament NO canviades: cap (no hi ha taules amb escriptura
--   legítima de socis normals; la disponibilitat és part de handicap_participants,
--   que és admin-only).
-- ============================================================================

-- ─── handicap_config ────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "handicap_config_insert_auth" ON public.handicap_config;
DROP POLICY IF EXISTS "handicap_config_update_auth" ON public.handicap_config;
DROP POLICY IF EXISTS "handicap_config_delete_auth" ON public.handicap_config;

CREATE POLICY "handicap_config_insert_admin" ON public.handicap_config
  FOR INSERT
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "handicap_config_update_admin" ON public.handicap_config
  FOR UPDATE
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "handicap_config_delete_admin" ON public.handicap_config
  FOR DELETE
  USING ((SELECT public.is_admin_by_email()));


-- ─── handicap_participants ───────────────────────────────────────────────────

DROP POLICY IF EXISTS "handicap_participants_insert_auth" ON public.handicap_participants;
DROP POLICY IF EXISTS "handicap_participants_update_auth" ON public.handicap_participants;
DROP POLICY IF EXISTS "handicap_participants_delete_auth" ON public.handicap_participants;

CREATE POLICY "handicap_participants_insert_admin" ON public.handicap_participants
  FOR INSERT
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "handicap_participants_update_admin" ON public.handicap_participants
  FOR UPDATE
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "handicap_participants_delete_admin" ON public.handicap_participants
  FOR DELETE
  USING ((SELECT public.is_admin_by_email()));


-- ─── handicap_bracket_slots ──────────────────────────────────────────────────

DROP POLICY IF EXISTS "handicap_bracket_slots_insert_auth" ON public.handicap_bracket_slots;
DROP POLICY IF EXISTS "handicap_bracket_slots_update_auth" ON public.handicap_bracket_slots;
DROP POLICY IF EXISTS "handicap_bracket_slots_delete_auth" ON public.handicap_bracket_slots;

CREATE POLICY "handicap_bracket_slots_insert_admin" ON public.handicap_bracket_slots
  FOR INSERT
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "handicap_bracket_slots_update_admin" ON public.handicap_bracket_slots
  FOR UPDATE
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "handicap_bracket_slots_delete_admin" ON public.handicap_bracket_slots
  FOR DELETE
  USING ((SELECT public.is_admin_by_email()));


-- ─── handicap_matches ────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "handicap_matches_insert_auth" ON public.handicap_matches;
DROP POLICY IF EXISTS "handicap_matches_update_auth" ON public.handicap_matches;
DROP POLICY IF EXISTS "handicap_matches_delete_auth" ON public.handicap_matches;

CREATE POLICY "handicap_matches_insert_admin" ON public.handicap_matches
  FOR INSERT
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "handicap_matches_update_admin" ON public.handicap_matches
  FOR UPDATE
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "handicap_matches_delete_admin" ON public.handicap_matches
  FOR DELETE
  USING ((SELECT public.is_admin_by_email()));
