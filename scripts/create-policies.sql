-- ===============================================
-- FIX RLS SECURITY ISSUES - STEP 2: CREATE POLICIES
-- ===============================================

-- 1. POLICIES PER SOCIS
-- La taula socis és de referència pública (sense user_id)
-- Els usuaris autenticats han de poder llegir socis per vincular amb players
-- Només service_role pot modificar

-- Esborrar policy existent si existeix
DROP POLICY IF EXISTS socis_read_policy ON public.socis;

-- Lectura per a usuaris autenticats (necessari per players.numero_soci)
CREATE POLICY socis_read_authenticated 
ON public.socis 
FOR SELECT 
TO authenticated 
USING (true);

-- Escriptura només per service_role
CREATE POLICY socis_write_service 
ON public.socis 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

-- 2. POLICIES PER MAINTENANCE_RUNS
-- Taules operatives - només service_role

-- Lectura per admins (si cal consultar logs)
CREATE POLICY maintenance_runs_read_admin 
ON public.maintenance_runs 
FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.admins 
        WHERE email = auth.jwt() ->> 'email'
    )
);

-- Tot per service_role
CREATE POLICY maintenance_runs_service 
ON public.maintenance_runs 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

-- 3. POLICIES PER MAINTENANCE_RUN_ITEMS
-- Igual que maintenance_runs

-- Lectura per admins
CREATE POLICY maintenance_items_read_admin 
ON public.maintenance_run_items 
FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM public.admins 
        WHERE email = auth.jwt() ->> 'email'
    )
);

-- Tot per service_role  
CREATE POLICY maintenance_items_service 
ON public.maintenance_run_items 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);