-- ============================================================================
-- Migració: Restringir escriptura a multimedia_links només a admins
-- Data: 2026-06-10
-- Motivació: Les policies existents permetien INSERT/UPDATE/DELETE a qualsevol
--   usuari autenticat (auth.uid() IS NOT NULL). Qualsevol soci loggat podia
--   crear, modificar i esborrar enllaços. Cal restringir-ho als admins.
-- Canvis:
--   - DROP de les 3 policies write que usaven auth.uid() IS NOT NULL
--   - RECREACIÓ amb public.is_admin_by_email() (patró establert)
--   - La policy SELECT "multimedia_links_select_all" (USING true) no es toca.
-- ============================================================================

-- Eliminar policies write permissives existents
-- (noms exactes de 20250121000000_create_multimedia_links.sql)
DROP POLICY IF EXISTS "multimedia_links_insert_auth" ON public.multimedia_links;
DROP POLICY IF EXISTS "multimedia_links_update_auth" ON public.multimedia_links;
DROP POLICY IF EXISTS "multimedia_links_delete_auth" ON public.multimedia_links;

-- Recrear policies write restringides als admins
CREATE POLICY "multimedia_links_insert_admin" ON public.multimedia_links
  FOR INSERT
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "multimedia_links_update_admin" ON public.multimedia_links
  FOR UPDATE
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));

CREATE POLICY "multimedia_links_delete_admin" ON public.multimedia_links
  FOR DELETE
  USING ((SELECT public.is_admin_by_email()));
