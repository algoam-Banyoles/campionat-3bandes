-- Fusionem policies de scope dual (ex: admin OR own) en una sola amb OR.
-- Manté la mateixa semàntica però redueix RLS d'una avaluació per fila a una.

----------------------------------------------------------------------
-- calendari_partides
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated users can view all calendar matches" ON public.calendari_partides;
DROP POLICY IF EXISTS "Public access to published calendar matches" ON public.calendari_partides;
CREATE POLICY "calendari_partides_select" ON public.calendari_partides
  FOR SELECT
  USING (
    ((SELECT auth.role()) = 'authenticated'::text)
    OR EXISTS (
      SELECT 1
      FROM public.events e
      WHERE e.id = calendari_partides.event_id
        AND e.calendari_publicat = true
        AND calendari_partides.estat = ANY (ARRAY['validat'::text,'confirmat'::text,'jugada'::text,'jugat'::text,'pendent_programar'::text])
    )
  );

----------------------------------------------------------------------
-- esdeveniments_club
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated users can view all events" ON public.esdeveniments_club;
DROP POLICY IF EXISTS "Public access to visible events" ON public.esdeveniments_club;
CREATE POLICY "esdeveniments_club_select" ON public.esdeveniments_club
  FOR SELECT
  USING (
    ((SELECT auth.role()) = 'authenticated'::text)
    OR (visible_per_tots = true)
  );

----------------------------------------------------------------------
-- challenges — fusiona INSERT i UPDATE de dos camins (admin O reptat/can_create)
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can insert challenges" ON public.challenges;
DROP POLICY IF EXISTS "Players can insert challenges" ON public.challenges;
CREATE POLICY "challenges_insert" ON public.challenges
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT public.is_admin_by_email())
    OR public.can_create_challenge_v2(event_id, reptador_soci_numero, reptat_soci_numero)
  );

DROP POLICY IF EXISTS "admins_update_challenges" ON public.challenges;
DROP POLICY IF EXISTS "upd_challenges_by_reptat" ON public.challenges;
CREATE POLICY "challenges_update" ON public.challenges
  FOR UPDATE
  USING (
    (SELECT public.is_admin_by_email())
    OR (
      estat = 'proposat'::challenge_state
      AND reptat_soci_numero = (
        SELECT s.numero_soci FROM public.socis s
        WHERE s.email = (SELECT auth.email())
      )
    )
  )
  WITH CHECK (
    (SELECT public.is_admin_by_email())
    OR estat = ANY (ARRAY['acceptat'::challenge_state, 'refusat'::challenge_state])
  );

----------------------------------------------------------------------
-- inscripcions
----------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins poden inserir inscripcions" ON public.inscripcions;
DROP POLICY IF EXISTS "Usuaris poden inserir les seves inscripcions" ON public.inscripcions;
CREATE POLICY "inscripcions_insert" ON public.inscripcions
  FOR INSERT TO authenticated
  WITH CHECK (
    (SELECT public.is_admin_by_email())
    OR EXISTS (
      SELECT 1 FROM public.socis
      WHERE socis.numero_soci = inscripcions.soci_numero
        AND socis.email = ((SELECT auth.jwt()) ->> 'email'::text)
    )
  );

DROP POLICY IF EXISTS "Admins poden actualitzar inscripcions" ON public.inscripcions;
DROP POLICY IF EXISTS "Usuaris poden actualitzar les seves inscripcions" ON public.inscripcions;
CREATE POLICY "inscripcions_update" ON public.inscripcions
  FOR UPDATE TO authenticated
  USING (
    (SELECT public.is_admin_by_email())
    OR EXISTS (
      SELECT 1 FROM public.socis
      WHERE socis.numero_soci = inscripcions.soci_numero
        AND socis.email = ((SELECT auth.jwt()) ->> 'email'::text)
    )
  );

DROP POLICY IF EXISTS "Admins poden eliminar inscripcions" ON public.inscripcions;
DROP POLICY IF EXISTS "Usuaris poden eliminar les seves inscripcions" ON public.inscripcions;
CREATE POLICY "inscripcions_delete" ON public.inscripcions
  FOR DELETE TO authenticated
  USING (
    (SELECT public.is_admin_by_email())
    OR EXISTS (
      SELECT 1 FROM public.socis
      WHERE socis.numero_soci = inscripcions.soci_numero
        AND socis.email = ((SELECT auth.jwt()) ->> 'email'::text)
    )
  );
