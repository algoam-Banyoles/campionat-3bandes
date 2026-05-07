-- "Només admins poden gestionar calendari" era FOR ALL i overlapava amb
-- calendari_partides_select per a authenticated. La separem en 3 policies
-- (INSERT/UPDATE/DELETE) per evitar el flag multiple_permissive_policies.
DROP POLICY IF EXISTS "Només admins poden gestionar calendari" ON public.calendari_partides;
CREATE POLICY "Admins poden inserir calendari" ON public.calendari_partides
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden actualitzar calendari" ON public.calendari_partides
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_admin_by_email()))
  WITH CHECK ((SELECT public.is_admin_by_email()));
CREATE POLICY "Admins poden eliminar calendari" ON public.calendari_partides
  FOR DELETE TO authenticated
  USING ((SELECT public.is_admin_by_email()));
