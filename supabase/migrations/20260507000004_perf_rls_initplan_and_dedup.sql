-- Performance: refactor RLS policies per evitar re-avaluació per fila de
-- `auth.uid()`/`auth.jwt()`/`auth.email()`/`auth.role()`.
--
-- Patrons aplicats:
--   * `auth.xxx()` → `(SELECT auth.xxx())` — el planner cacheja l'expressió.
--   * Patrons admin barrejats (EXISTS lookup, LOWER+TRIM, hardcoded ARRAY)
--     → `(SELECT public.is_admin_by_email())` — font única de veritat.
--   * Es consolida policies admin duplicades a challenges/matches/history.
--
-- Cap canvi de comportament funcional: les checks són equivalents.

----------------------------------------------------------------------
-- admins
----------------------------------------------------------------------
DROP POLICY IF EXISTS "un usuari pot veure si és admin" ON public.admins;
CREATE POLICY "un usuari pot veure si és admin" ON public.admins
  FOR SELECT TO authenticated
  USING (lower(email) = lower(((SELECT auth.jwt()) ->> 'email'::text)));

----------------------------------------------------------------------
-- app_settings
----------------------------------------------------------------------
DROP POLICY IF EXISTS "nomes admins poden update config" ON public.app_settings;
CREATE POLICY "nomes admins poden update config" ON public.app_settings
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- audit_log_socials
----------------------------------------------------------------------
DROP POLICY IF EXISTS "audit_log_socials_admin_select" ON public.audit_log_socials;
CREATE POLICY "audit_log_socials_admin_select" ON public.audit_log_socials
  FOR SELECT
  USING ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- calendari_partides
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can update match results" ON public.calendari_partides;
CREATE POLICY "Admins can update match results" ON public.calendari_partides
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "Authenticated users can view all calendar matches" ON public.calendari_partides;
CREATE POLICY "Authenticated users can view all calendar matches" ON public.calendari_partides
  FOR SELECT
  USING ((SELECT auth.role()) = 'authenticated'::text);

DROP POLICY IF EXISTS "Només admins poden gestionar calendari" ON public.calendari_partides;
CREATE POLICY "Només admins poden gestionar calendari" ON public.calendari_partides
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- categories
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can delete categories" ON public.categories;
CREATE POLICY "Admins can delete categories" ON public.categories
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "Admins can insert categories" ON public.categories;
CREATE POLICY "Admins can insert categories" ON public.categories
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "Admins can update categories" ON public.categories;
CREATE POLICY "Admins can update categories" ON public.categories
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- challenges (consolidem 4 policies update admin → 1)
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can insert challenges" ON public.challenges;
CREATE POLICY "Admins can insert challenges" ON public.challenges
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "Admins can update challenges" ON public.challenges;
DROP POLICY IF EXISTS "admin update challenges" ON public.challenges;
DROP POLICY IF EXISTS "admins poden UPDATE challenges" ON public.challenges;
DROP POLICY IF EXISTS "admins_update_challenges" ON public.challenges;
CREATE POLICY "admins_update_challenges" ON public.challenges
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "ins_ch_user" ON public.challenges;
CREATE POLICY "ins_ch_user" ON public.challenges
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "upd_challenges_by_reptat" ON public.challenges;
CREATE POLICY "upd_challenges_by_reptat" ON public.challenges
  FOR UPDATE
  USING (
    (estat = 'proposat'::challenge_state)
    AND (reptat_soci_numero = (
      SELECT s.numero_soci FROM public.socis s WHERE s.email = (SELECT auth.email())
    ))
  )
  WITH CHECK (estat = ANY (ARRAY['acceptat'::challenge_state, 'refusat'::challenge_state]));

----------------------------------------------------------------------
-- configuracio_calendari
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Només admins poden gestionar configuració calendari" ON public.configuracio_calendari;
CREATE POLICY "Només admins poden gestionar configuració calendari" ON public.configuracio_calendari
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- esdeveniments_club
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated users can view all events" ON public.esdeveniments_club;
CREATE POLICY "Authenticated users can view all events" ON public.esdeveniments_club
  FOR SELECT
  USING ((SELECT auth.role()) = 'authenticated'::text);

DROP POLICY IF EXISTS "Creadors poden actualitzar els seus esdeveniments" ON public.esdeveniments_club;
CREATE POLICY "Creadors poden actualitzar els seus esdeveniments" ON public.esdeveniments_club
  FOR UPDATE TO authenticated
  USING (creat_per = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Creadors poden eliminar els seus esdeveniments" ON public.esdeveniments_club;
CREATE POLICY "Creadors poden eliminar els seus esdeveniments" ON public.esdeveniments_club
  FOR DELETE TO authenticated
  USING (creat_per = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Creadors poden veure els seus esdeveniments" ON public.esdeveniments_club;
CREATE POLICY "Creadors poden veure els seus esdeveniments" ON public.esdeveniments_club
  FOR SELECT TO authenticated
  USING (creat_per = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Usuaris autenticats poden crear esdeveniments" ON public.esdeveniments_club;
CREATE POLICY "Usuaris autenticats poden crear esdeveniments" ON public.esdeveniments_club
  FOR INSERT TO authenticated
  WITH CHECK (creat_per = (SELECT auth.uid()));

DROP POLICY IF EXISTS "esdeveniments_delete_auth" ON public.esdeveniments_club;
CREATE POLICY "esdeveniments_delete_auth" ON public.esdeveniments_club
  FOR DELETE
  USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "esdeveniments_insert_auth" ON public.esdeveniments_club;
CREATE POLICY "esdeveniments_insert_auth" ON public.esdeveniments_club
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "esdeveniments_update_auth" ON public.esdeveniments_club;
CREATE POLICY "esdeveniments_update_auth" ON public.esdeveniments_club
  FOR UPDATE
  USING ((SELECT auth.uid()) IS NOT NULL)
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can delete events" ON public.events;
CREATE POLICY "Admins can delete events" ON public.events
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "Admins can insert events" ON public.events;
CREATE POLICY "Admins can insert events" ON public.events
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "Admins can update events" ON public.events;
CREATE POLICY "Admins can update events" ON public.events
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- handicap_bracket_slots
----------------------------------------------------------------------
DROP POLICY IF EXISTS "handicap_bracket_slots_delete_auth" ON public.handicap_bracket_slots;
CREATE POLICY "handicap_bracket_slots_delete_auth" ON public.handicap_bracket_slots
  FOR DELETE USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "handicap_bracket_slots_insert_auth" ON public.handicap_bracket_slots;
CREATE POLICY "handicap_bracket_slots_insert_auth" ON public.handicap_bracket_slots
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "handicap_bracket_slots_update_auth" ON public.handicap_bracket_slots;
CREATE POLICY "handicap_bracket_slots_update_auth" ON public.handicap_bracket_slots
  FOR UPDATE USING ((SELECT auth.uid()) IS NOT NULL);

----------------------------------------------------------------------
-- handicap_config
----------------------------------------------------------------------
DROP POLICY IF EXISTS "handicap_config_delete_auth" ON public.handicap_config;
CREATE POLICY "handicap_config_delete_auth" ON public.handicap_config
  FOR DELETE USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "handicap_config_insert_auth" ON public.handicap_config;
CREATE POLICY "handicap_config_insert_auth" ON public.handicap_config
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "handicap_config_update_auth" ON public.handicap_config;
CREATE POLICY "handicap_config_update_auth" ON public.handicap_config
  FOR UPDATE USING ((SELECT auth.uid()) IS NOT NULL);

----------------------------------------------------------------------
-- handicap_matches
----------------------------------------------------------------------
DROP POLICY IF EXISTS "handicap_matches_delete_auth" ON public.handicap_matches;
CREATE POLICY "handicap_matches_delete_auth" ON public.handicap_matches
  FOR DELETE USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "handicap_matches_insert_auth" ON public.handicap_matches;
CREATE POLICY "handicap_matches_insert_auth" ON public.handicap_matches
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "handicap_matches_update_auth" ON public.handicap_matches;
CREATE POLICY "handicap_matches_update_auth" ON public.handicap_matches
  FOR UPDATE USING ((SELECT auth.uid()) IS NOT NULL);

----------------------------------------------------------------------
-- handicap_participants
----------------------------------------------------------------------
DROP POLICY IF EXISTS "handicap_participants_delete_auth" ON public.handicap_participants;
CREATE POLICY "handicap_participants_delete_auth" ON public.handicap_participants
  FOR DELETE USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "handicap_participants_insert_auth" ON public.handicap_participants;
CREATE POLICY "handicap_participants_insert_auth" ON public.handicap_participants
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "handicap_participants_update_auth" ON public.handicap_participants;
CREATE POLICY "handicap_participants_update_auth" ON public.handicap_participants
  FOR UPDATE USING ((SELECT auth.uid()) IS NOT NULL);

----------------------------------------------------------------------
-- history_position_changes (consolida 2 policies admin insert → 1)
----------------------------------------------------------------------
DROP POLICY IF EXISTS "admin insert history" ON public.history_position_changes;
DROP POLICY IF EXISTS "admins poden inserir history_position_changes" ON public.history_position_changes;
CREATE POLICY "admins poden inserir history_position_changes" ON public.history_position_changes
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- initial_ranking
----------------------------------------------------------------------
DROP POLICY IF EXISTS "admin all initial_ranking" ON public.initial_ranking;
CREATE POLICY "admin all initial_ranking" ON public.initial_ranking
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- inscripcions
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Només admins poden gestionar totes les inscripcions" ON public.inscripcions;
CREATE POLICY "Només admins poden gestionar totes les inscripcions" ON public.inscripcions
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "Usuaris poden gestionar les seves inscripcions" ON public.inscripcions;
CREATE POLICY "Usuaris poden gestionar les seves inscripcions" ON public.inscripcions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.socis
      WHERE socis.numero_soci = inscripcions.soci_numero
        AND socis.email = ((SELECT auth.jwt()) ->> 'email'::text)
    )
  );

----------------------------------------------------------------------
-- maintenance_run_items / maintenance_runs
----------------------------------------------------------------------
DROP POLICY IF EXISTS "maintenance_items_read_admin" ON public.maintenance_run_items;
CREATE POLICY "maintenance_items_read_admin" ON public.maintenance_run_items
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin_by_email()));

DROP POLICY IF EXISTS "maintenance_runs_read_admin" ON public.maintenance_runs;
CREATE POLICY "maintenance_runs_read_admin" ON public.maintenance_runs
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- matches (consolida 2 policies admin insert → 1)
----------------------------------------------------------------------
DROP POLICY IF EXISTS "admin insert matches" ON public.matches;
DROP POLICY IF EXISTS "admins poden inserir matches" ON public.matches;
CREATE POLICY "admins poden inserir matches" ON public.matches
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- notes
----------------------------------------------------------------------
DROP POLICY IF EXISTS "only owners read/write their notes" ON public.notes;
CREATE POLICY "only owners read/write their notes" ON public.notes
  FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

----------------------------------------------------------------------
-- notification_history
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Usuaris poden veure el seu historial" ON public.notification_history;
CREATE POLICY "Usuaris poden veure el seu historial" ON public.notification_history
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

----------------------------------------------------------------------
-- notification_preferences
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Usuaris poden actualitzar les seves preferències" ON public.notification_preferences;
CREATE POLICY "Usuaris poden actualitzar les seves preferències" ON public.notification_preferences
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Usuaris poden crear les seves preferències" ON public.notification_preferences;
CREATE POLICY "Usuaris poden crear les seves preferències" ON public.notification_preferences
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Usuaris poden veure les seves preferències" ON public.notification_preferences;
CREATE POLICY "Usuaris poden veure les seves preferències" ON public.notification_preferences
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

----------------------------------------------------------------------
-- page_content
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Only admins can insert page content" ON public.page_content;
CREATE POLICY "Only admins can insert page content" ON public.page_content
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Only admins can update page content" ON public.page_content;
CREATE POLICY "Only admins can update page content" ON public.page_content
  FOR UPDATE
  USING ((SELECT auth.uid()) IS NOT NULL);

----------------------------------------------------------------------
-- penalties
----------------------------------------------------------------------
DROP POLICY IF EXISTS "admins poden INSERT a penalties" ON public.penalties;
CREATE POLICY "admins poden INSERT a penalties" ON public.penalties
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- push_subscriptions
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Usuaris poden actualitzar les seves subscripcions" ON public.push_subscriptions;
CREATE POLICY "Usuaris poden actualitzar les seves subscripcions" ON public.push_subscriptions
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Usuaris poden crear les seves subscripcions" ON public.push_subscriptions;
CREATE POLICY "Usuaris poden crear les seves subscripcions" ON public.push_subscriptions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Usuaris poden eliminar les seves subscripcions" ON public.push_subscriptions;
CREATE POLICY "Usuaris poden eliminar les seves subscripcions" ON public.push_subscriptions
  FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Usuaris poden veure les seves subscripcions" ON public.push_subscriptions;
CREATE POLICY "Usuaris poden veure les seves subscripcions" ON public.push_subscriptions
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

----------------------------------------------------------------------
-- socis
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Admin can update socis" ON public.socis;
CREATE POLICY "Admin can update socis" ON public.socis
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- socis_jugador
----------------------------------------------------------------------
DROP POLICY IF EXISTS "socis_jugador_delete_auth" ON public.socis_jugador;
CREATE POLICY "socis_jugador_delete_auth" ON public.socis_jugador
  FOR DELETE USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "socis_jugador_insert_auth" ON public.socis_jugador;
CREATE POLICY "socis_jugador_insert_auth" ON public.socis_jugador
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "socis_jugador_update_auth" ON public.socis_jugador;
CREATE POLICY "socis_jugador_update_auth" ON public.socis_jugador
  FOR UPDATE USING ((SELECT auth.uid()) IS NOT NULL);

----------------------------------------------------------------------
-- waiting_list
----------------------------------------------------------------------
DROP POLICY IF EXISTS "admin all waiting_list" ON public.waiting_list;
CREATE POLICY "admin all waiting_list" ON public.waiting_list
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));
