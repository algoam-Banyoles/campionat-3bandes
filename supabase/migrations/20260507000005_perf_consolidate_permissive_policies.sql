-- Performance: consolidació de policies permissives duplicades.
--
-- Patrons trobats al schema:
--   * Policies "all_*_admin" (FOR ALL, role=PUBLIC, is_admin()) que ja
--     estan substituïdes per policies admin específiques amb is_admin_by_email().
--   * Policies "sel_*" PUBLIC qual=true que cobreixen anon i authenticated,
--     duplicades amb "Authenticated users can select X" authenticated qual=true.
--   * Policies "admin insert/update/delete X" duplicades amb una "admin all X" FOR ALL.
--   * Policies "calendari_admin_*" amb is_current_user_admin() vs el "Només admins
--     poden gestionar calendari" FOR ALL.
--
-- Estratègia general: drop les redundants, mantenir la semàntica.

----------------------------------------------------------------------
-- calendari_partides
----------------------------------------------------------------------
-- Granular admin policies redundants amb "Només admins poden gestionar calendari" (FOR ALL)
DROP POLICY IF EXISTS "calendari_admin_insert" ON public.calendari_partides;
DROP POLICY IF EXISTS "calendari_admin_delete" ON public.calendari_partides;
DROP POLICY IF EXISTS "calendari_admin_update" ON public.calendari_partides;
-- "Admins can update match results" duplicada amb la FOR ALL admin
DROP POLICY IF EXISTS "Admins can update match results" ON public.calendari_partides;
-- Authenticated SELECT redundant amb "Authenticated users can view all calendar matches"
DROP POLICY IF EXISTS "Usuaris autenticats poden veure calendari" ON public.calendari_partides;

----------------------------------------------------------------------
-- categories
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Usuaris autenticats poden veure categories" ON public.categories;

----------------------------------------------------------------------
-- challenges
----------------------------------------------------------------------
DROP POLICY IF EXISTS "all_ch_admin" ON public.challenges;
DROP POLICY IF EXISTS "Authenticated users can select challenges" ON public.challenges;
DROP POLICY IF EXISTS "challenges_select_auth" ON public.challenges;
DROP POLICY IF EXISTS "ins_ch_user" ON public.challenges;
-- ins_ch_user permetia a qualsevol authenticated INSERT — eliminar reforça el check
-- de Players can insert challenges (can_create_challenge_v2).

----------------------------------------------------------------------
-- classificacions
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Usuaris autenticats poden veure classificacions" ON public.classificacions;

----------------------------------------------------------------------
-- configuracio_calendari
----------------------------------------------------------------------
-- Convertim el FOR ALL admin a FOR INSERT/UPDATE/DELETE separats perquè
-- el SELECT pugui ser una policy única (no duplicada).
DROP POLICY IF EXISTS "Només admins poden gestionar configuració calendari" ON public.configuracio_calendari;
CREATE POLICY "Admins poden inserir configuració calendari" ON public.configuracio_calendari
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden actualitzar configuració calendari" ON public.configuracio_calendari
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden eliminar configuració calendari" ON public.configuracio_calendari
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin_by_email()));
-- "Usuaris autenticats poden veure configuració calendari" es manté com a única SELECT.

----------------------------------------------------------------------
-- esdeveniments_club
----------------------------------------------------------------------
-- Les policies *_auth són redundants amb les "Creadors poden ..." (que ja
-- comproven creat_per = auth.uid()).
DROP POLICY IF EXISTS "esdeveniments_insert_auth" ON public.esdeveniments_club;
DROP POLICY IF EXISTS "esdeveniments_delete_auth" ON public.esdeveniments_club;
DROP POLICY IF EXISTS "esdeveniments_update_auth" ON public.esdeveniments_club;
-- SELECT: "Authenticated users can view all events" cobreix authenticated;
-- "Public access to visible events" cobreix anon. Drop la duplicada
-- "Esdeveniments visibles per usuaris autenticats" i "Creadors poden veure"
-- (ja inclòs al "view all events").
DROP POLICY IF EXISTS "Esdeveniments visibles per usuaris autenticats" ON public.esdeveniments_club;
DROP POLICY IF EXISTS "Creadors poden veure els seus esdeveniments" ON public.esdeveniments_club;

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------
-- 5 policies SELECT duplicades amb qual=true. Mantenir només "Events are publicly readable" (PUBLIC).
DROP POLICY IF EXISTS "Authenticated users can select events" ON public.events;
DROP POLICY IF EXISTS "Usuaris autenticats poden veure events" ON public.events;
DROP POLICY IF EXISTS "anon can select events" ON public.events;
DROP POLICY IF EXISTS "auth can select events" ON public.events;
DROP POLICY IF EXISTS "events_select_authenticated" ON public.events;

----------------------------------------------------------------------
-- history_position_changes
----------------------------------------------------------------------
DROP POLICY IF EXISTS "all_hist_admin" ON public.history_position_changes;
DROP POLICY IF EXISTS "Authenticated users can select history_position_changes" ON public.history_position_changes;
-- Mantenir sel_hist (PUBLIC qual=true) com a única SELECT.

----------------------------------------------------------------------
-- initial_ranking
----------------------------------------------------------------------
-- "admin all initial_ranking" cobreix admins. "Authenticated users can select"
-- cobreix tots authenticated. Idealment només volem una SELECT — convertim
-- el "admin all" a un FOR INSERT/UPDATE/DELETE (no SELECT).
DROP POLICY IF EXISTS "admin all initial_ranking" ON public.initial_ranking;
CREATE POLICY "Admins poden inserir initial_ranking" ON public.initial_ranking
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden actualitzar initial_ranking" ON public.initial_ranking
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden eliminar initial_ranking" ON public.initial_ranking
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- inscripcions
----------------------------------------------------------------------
-- "Usuaris autenticats poden veure inscripcions" qual=true cobreix tothom.
-- Però "Només admins poden gestionar totes les inscripcions" FOR ALL i
-- "Usuaris poden gestionar les seves inscripcions" FOR ALL ja cobren
-- INSERT/UPDATE/DELETE. Per a SELECT, mantenim la pública unica.
DROP POLICY IF EXISTS "Només admins poden gestionar totes les inscripcions" ON public.inscripcions;
DROP POLICY IF EXISTS "Usuaris poden gestionar les seves inscripcions" ON public.inscripcions;
-- Recreem com a INSERT/UPDATE/DELETE separats per evitar l'overlapping a SELECT
CREATE POLICY "Admins poden inserir inscripcions" ON public.inscripcions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden actualitzar inscripcions" ON public.inscripcions
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden eliminar inscripcions" ON public.inscripcions
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin_by_email()));

CREATE POLICY "Usuaris poden inserir les seves inscripcions" ON public.inscripcions
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.socis
      WHERE socis.numero_soci = inscripcions.soci_numero
        AND socis.email = ((SELECT auth.jwt()) ->> 'email'::text)
    )
  );
CREATE POLICY "Usuaris poden actualitzar les seves inscripcions" ON public.inscripcions
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.socis
      WHERE socis.numero_soci = inscripcions.soci_numero
        AND socis.email = ((SELECT auth.jwt()) ->> 'email'::text)
    )
  );
CREATE POLICY "Usuaris poden eliminar les seves inscripcions" ON public.inscripcions
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.socis
      WHERE socis.numero_soci = inscripcions.soci_numero
        AND socis.email = ((SELECT auth.jwt()) ->> 'email'::text)
    )
  );
-- "Usuaris autenticats poden veure inscripcions" es manté com a única SELECT.

----------------------------------------------------------------------
-- matches
----------------------------------------------------------------------
DROP POLICY IF EXISTS "all_matches_admin" ON public.matches;
DROP POLICY IF EXISTS "Authenticated users can select matches" ON public.matches;
-- Mantenir sel_matches (PUBLIC qual=true) com a única SELECT.

----------------------------------------------------------------------
-- mitjanes_historiques
----------------------------------------------------------------------
DROP POLICY IF EXISTS "mitjanes_historiques_read_policy" ON public.mitjanes_historiques;

----------------------------------------------------------------------
-- penalties
----------------------------------------------------------------------
DROP POLICY IF EXISTS "all_pens_admin" ON public.penalties;
-- sel_pens (PUBLIC, is_admin()) i admins poden INSERT a penalties amb is_admin_by_email().
-- Cap més SELECT: només admins poden veure penalties (sel_pens) — això està bé.

----------------------------------------------------------------------
-- ranking_positions
----------------------------------------------------------------------
DROP POLICY IF EXISTS "all_ranking_admin" ON public.ranking_positions;
DROP POLICY IF EXISTS "admin insert ranking_positions" ON public.ranking_positions;
DROP POLICY IF EXISTS "admin delete ranking_positions" ON public.ranking_positions;
DROP POLICY IF EXISTS "admin update ranking_positions" ON public.ranking_positions;
DROP POLICY IF EXISTS "Authenticated users can select ranking_positions" ON public.ranking_positions;
DROP POLICY IF EXISTS "anon can select ranking" ON public.ranking_positions;
DROP POLICY IF EXISTS "auth can select ranking" ON public.ranking_positions;
-- Mantenir sel_ranking (PUBLIC qual=true) com a SELECT pública.
-- Crear policies admin separades per a INSERT/UPDATE/DELETE.
CREATE POLICY "Admins poden inserir ranking_positions" ON public.ranking_positions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden actualitzar ranking_positions" ON public.ranking_positions
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden eliminar ranking_positions" ON public.ranking_positions
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin_by_email()));

----------------------------------------------------------------------
-- socis
----------------------------------------------------------------------
DROP POLICY IF EXISTS "socis_read_authenticated" ON public.socis;
-- "Public can view socis basic info for ranking" PUBLIC qual=true cobreix tothom.

----------------------------------------------------------------------
-- waiting_list
----------------------------------------------------------------------
DROP POLICY IF EXISTS "all_wait_admin" ON public.waiting_list;
DROP POLICY IF EXISTS "admin insert waiting_list" ON public.waiting_list;
DROP POLICY IF EXISTS "admin delete waiting_list" ON public.waiting_list;
DROP POLICY IF EXISTS "admin update waiting_list" ON public.waiting_list;
DROP POLICY IF EXISTS "Authenticated users can select waiting_list" ON public.waiting_list;
DROP POLICY IF EXISTS "anon can select waiting" ON public.waiting_list;
DROP POLICY IF EXISTS "auth can select waiting" ON public.waiting_list;
DROP POLICY IF EXISTS "admin all waiting_list" ON public.waiting_list;
-- Recreem policies admin separades per INSERT/UPDATE/DELETE
-- (no SELECT, perquè sel_wait PUBLIC ja cobreix lectura).
CREATE POLICY "Admins poden inserir waiting_list" ON public.waiting_list
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden actualitzar waiting_list" ON public.waiting_list
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden eliminar waiting_list" ON public.waiting_list
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin_by_email()));
