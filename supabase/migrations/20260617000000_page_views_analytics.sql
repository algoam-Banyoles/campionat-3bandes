-- ============================================================================
-- Migració: Estadístiques d'accés (visites de pàgina) per a administradors
-- Data: 2026-06-17
--
-- Objectiu: registrar de manera AGREGADA i ANÒNIMA les visites a les diferents
-- seccions/pàgines de l'aplicació, perquè els admins puguin veure estadístiques
-- d'ús (visites per secció, evolució diària, pàgines més vistes).
--
-- Decisions de privadesa (acordades amb l'usuari):
--   * NO es desa cap identitat d'usuari (ni email, ni numero_soci, ni auth uid).
--   * Només es desen: secció derivada, path normalitzat, dos flags booleans
--     (is_authenticated / is_admin) i un visitor_id aleatori per navegador
--     (generat al client, guardat a localStorage) per estimar visitants únics
--     sense identificar ningú.
--   * Es compten també les visites de visitants no loggats (anònims).
--
-- Arquitectura (la taula queda totalment tancada a l'API):
--   * Escriptura: NOMÉS via la funció SECURITY DEFINER public.log_page_view().
--     Els flags is_authenticated/is_admin es deriven al servidor (no es confia
--     en el client). Es concedeix EXECUTE a anon i authenticated.
--   * Lectura: NOMÉS via funcions d'agregació SECURITY DEFINER (propietari =
--     postgres = propietari de la taula, force_rls=false → poden llegir-la) que
--     s'auto-protegeixen amb `WHERE public.is_admin_by_email()`. Cap rol (anon
--     ni authenticated) pot fer SELECT directe sobre la taula. Les funcions
--     retornen poques files i no topen amb el límit max_rows=1000 de PostgREST.
-- ============================================================================

-- ─── Taula ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.page_views (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  path             TEXT NOT NULL,
  section          TEXT NOT NULL,
  is_authenticated BOOLEAN NOT NULL DEFAULT false,
  is_admin         BOOLEAN NOT NULL DEFAULT false,
  visitor_id       UUID
);

COMMENT ON TABLE public.page_views IS
  'Registre agregat i anònim de visites de pàgina per a estadístiques d''ús (admin). No desa cap identitat d''usuari.';

CREATE INDEX IF NOT EXISTS idx_page_views_created_at
  ON public.page_views (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_page_views_section_created_at
  ON public.page_views (section, created_at DESC);

-- ─── Tancament total de l'accés directe a la taula ───────────────────────────
-- RLS activada (defensa en profunditat) i tots els accessos directes revocats.
-- Tota lectura passa per les funcions d'agregació SECURITY DEFINER d'avall.

ALTER TABLE public.page_views ENABLE ROW LEVEL SECURITY;

-- Política admin-only mantinguda com a xarxa de seguretat per si algun dia es
-- torna a concedir SELECT sobre la taula (ara mateix està revocat).
DROP POLICY IF EXISTS page_views_admin_select ON public.page_views;
CREATE POLICY page_views_admin_select ON public.page_views
  FOR SELECT
  TO authenticated
  USING ((SELECT public.is_admin_by_email()));

REVOKE SELECT, INSERT, UPDATE, DELETE ON public.page_views FROM anon, authenticated;

-- ─── Funció d'escriptura ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.log_page_view(
  p_path TEXT,
  p_visitor_id UUID DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_email   TEXT;
  v_is_admin BOOLEAN := false;
  v_path    TEXT;
  v_section TEXT;
BEGIN
  IF p_path IS NULL OR length(p_path) = 0 THEN
    RETURN;
  END IF;

  -- Normalitza el path: límit de longitud i col·lapsa identificadors dinàmics
  -- (UUIDs i ids numèrics) perquè les pàgines amb paràmetre agrupin bé.
  v_path := left(p_path, 300);
  v_path := regexp_replace(
    v_path,
    '/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    '/:id', 'g'
  );
  v_path := regexp_replace(v_path, '/[0-9]+', '/:id', 'g');

  v_section := CASE
    WHEN v_path = '/'                            THEN 'inici'
    WHEN v_path LIKE '/general%'                 THEN 'general'
    WHEN v_path LIKE '/campionats-socials%'      THEN 'campionats-socials'
    WHEN v_path LIKE '/campionat-continu%'       THEN 'campionat-continu'
    WHEN v_path LIKE '/handicap%'                THEN 'handicap'
    WHEN v_path LIKE '/admin%'                   THEN 'admin'
    WHEN v_path LIKE '/jugador%'                 THEN 'jugador'
    ELSE 'altres'
  END;

  IF v_uid IS NOT NULL THEN
    SELECT u.email INTO v_email FROM auth.users u WHERE u.id = v_uid;
    IF v_email IS NOT NULL THEN
      v_is_admin := EXISTS (SELECT 1 FROM public.admins a WHERE a.email = v_email);
    END IF;
  END IF;

  INSERT INTO public.page_views (path, section, is_authenticated, is_admin, visitor_id)
  VALUES (v_path, v_section, v_uid IS NOT NULL, v_is_admin, p_visitor_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_page_view(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_page_view(TEXT, UUID) TO anon, authenticated;

-- ─── Funcions d'agregació (SECURITY DEFINER + guarda d'admin interna) ────────
-- Propietari = postgres (propietari de la taula, force_rls=false) → poden llegir
-- la taula sense topar amb la RLS. La guarda `WHERE public.is_admin_by_email()`
-- assegura que un usuari no-admin que cridi l'RPC rep zero files.

CREATE OR REPLACE FUNCTION public.get_page_view_totals(
  p_from timestamptz,
  p_to timestamptz,
  p_include_admin boolean DEFAULT false
)
RETURNS TABLE (
  total_views     bigint,
  unique_visitors bigint,
  authed_views    bigint,
  anon_views      bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT
    count(*)::bigint,
    count(DISTINCT pv.visitor_id)::bigint,
    count(*) FILTER (WHERE pv.is_authenticated)::bigint,
    count(*) FILTER (WHERE NOT pv.is_authenticated)::bigint
  FROM public.page_views pv
  WHERE public.is_admin_by_email()
    AND pv.created_at >= p_from
    AND pv.created_at <  p_to
    AND (p_include_admin OR NOT pv.is_admin);
$$;

CREATE OR REPLACE FUNCTION public.get_page_view_section_stats(
  p_from timestamptz,
  p_to timestamptz,
  p_include_admin boolean DEFAULT false
)
RETURNS TABLE (
  section      text,
  views        bigint,
  visitors     bigint,
  authed_views bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT
    pv.section,
    count(*)::bigint,
    count(DISTINCT pv.visitor_id)::bigint,
    count(*) FILTER (WHERE pv.is_authenticated)::bigint
  FROM public.page_views pv
  WHERE public.is_admin_by_email()
    AND pv.created_at >= p_from
    AND pv.created_at <  p_to
    AND (p_include_admin OR NOT pv.is_admin)
  GROUP BY pv.section
  ORDER BY count(*) DESC;
$$;

CREATE OR REPLACE FUNCTION public.get_page_view_daily(
  p_from timestamptz,
  p_to timestamptz,
  p_include_admin boolean DEFAULT false
)
RETURNS TABLE (
  day      date,
  views    bigint,
  visitors bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT
    (pv.created_at AT TIME ZONE 'Europe/Madrid')::date AS day,
    count(*)::bigint,
    count(DISTINCT pv.visitor_id)::bigint
  FROM public.page_views pv
  WHERE public.is_admin_by_email()
    AND pv.created_at >= p_from
    AND pv.created_at <  p_to
    AND (p_include_admin OR NOT pv.is_admin)
  GROUP BY (pv.created_at AT TIME ZONE 'Europe/Madrid')::date
  ORDER BY 1;
$$;

CREATE OR REPLACE FUNCTION public.get_page_view_top_paths(
  p_from timestamptz,
  p_to timestamptz,
  p_include_admin boolean DEFAULT false,
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  path     text,
  section  text,
  views    bigint,
  visitors bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT
    pv.path,
    pv.section,
    count(*)::bigint,
    count(DISTINCT pv.visitor_id)::bigint
  FROM public.page_views pv
  WHERE public.is_admin_by_email()
    AND pv.created_at >= p_from
    AND pv.created_at <  p_to
    AND (p_include_admin OR NOT pv.is_admin)
  GROUP BY pv.path, pv.section
  ORDER BY count(*) DESC
  LIMIT GREATEST(p_limit, 1);
$$;

REVOKE EXECUTE ON FUNCTION public.get_page_view_totals(timestamptz, timestamptz, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_page_view_section_stats(timestamptz, timestamptz, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_page_view_daily(timestamptz, timestamptz, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_page_view_top_paths(timestamptz, timestamptz, boolean, int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_page_view_totals(timestamptz, timestamptz, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_page_view_section_stats(timestamptz, timestamptz, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_page_view_daily(timestamptz, timestamptz, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_page_view_top_paths(timestamptz, timestamptz, boolean, int) TO authenticated;
