-- ===============================================
-- FIX ALL RLS SECURITY ISSUES - COMPLETE SCRIPT
-- Resolves Supabase linter security errors  
-- ===============================================

-- STEP 1: ENABLE RLS ON AFFECTED TABLES
-- =====================================
ALTER TABLE public.socis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_runs ENABLE ROW LEVEL SECURITY; 
ALTER TABLE public.maintenance_run_items ENABLE ROW LEVEL SECURITY;

-- STEP 2: CREATE PROPER POLICIES
-- ===============================

-- Remove existing conflicting policy
DROP POLICY IF EXISTS socis_read_policy ON public.socis;

-- SOCIS: Reference table - readable by authenticated users
CREATE POLICY socis_read_authenticated 
ON public.socis 
FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY socis_write_service 
ON public.socis 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

-- MAINTENANCE_RUNS: Operations table - service_role + admin read
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

CREATE POLICY maintenance_runs_service 
ON public.maintenance_runs 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

-- MAINTENANCE_RUN_ITEMS: Same as maintenance_runs
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

CREATE POLICY maintenance_items_service 
ON public.maintenance_run_items 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

-- STEP 3: FIX SECURITY DEFINER VIEWS
-- ===================================

-- Drop and recreate as SECURITY INVOKER (default)
DROP VIEW IF EXISTS public.v_challenges_pending;
DROP VIEW IF EXISTS public.v_player_timeline;
DROP VIEW IF EXISTS public.v_maintenance_runs;
DROP VIEW IF EXISTS public.v_maintenance_run_details;

-- Recreate views (SECURITY INVOKER by default)
CREATE VIEW public.v_challenges_pending AS
SELECT 
    c.id,
    c.event_id,
    c.reptador_id,
    c.reptat_id,
    c.estat,
    c.data_proposta,
    c.data_programada,
    p1.nom as reptador_nom,
    p2.nom as reptat_nom
FROM challenges c
JOIN players p1 ON p1.id = c.reptador_id  
JOIN players p2 ON p2.id = c.reptat_id
WHERE c.estat IN ('proposat', 'acceptat', 'programat');

CREATE VIEW public.v_player_timeline AS
SELECT 
    p.id as player_id,
    p.nom,
    'challenge' as event_type,
    c.data_proposta as event_date,
    'Repte proposat' as description
FROM players p
JOIN challenges c ON (c.reptador_id = p.id OR c.reptat_id = p.id)
UNION ALL
SELECT 
    p.id as player_id,
    p.nom,
    'match' as event_type, 
    m.data_joc as event_date,
    'Partida jugada' as description
FROM players p
JOIN challenges c ON (c.reptador_id = p.id OR c.reptat_id = p.id)
JOIN matches m ON m.challenge_id = c.id
ORDER BY event_date DESC;

CREATE VIEW public.v_maintenance_runs AS
SELECT 
    id,
    started_at,
    finished_at,
    triggered_by,
    ok,
    notes
FROM maintenance_runs
ORDER BY started_at DESC;

CREATE VIEW public.v_maintenance_run_details AS
SELECT 
    mr.id as run_id,
    mr.started_at,
    mr.finished_at,
    mr.triggered_by,
    mr.ok,
    mri.kind,
    mri.payload,
    mri.created_at as item_created_at
FROM maintenance_runs mr
JOIN maintenance_run_items mri ON mri.run_id = mr.id
ORDER BY mr.started_at DESC, mri.created_at ASC;

-- Grant permissions
GRANT SELECT ON public.v_challenges_pending TO authenticated;
GRANT SELECT ON public.v_player_timeline TO authenticated;

-- STEP 4: VERIFICATION
-- ====================

-- Verify RLS is enabled
SELECT 
    schemaname, 
    tablename, 
    rowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
    AND tablename IN ('socis', 'maintenance_runs', 'maintenance_run_items')
    AND rowsecurity = true;

-- Verify policies exist  
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE schemaname = 'public'
    AND tablename IN ('socis', 'maintenance_runs', 'maintenance_run_items')
ORDER BY tablename, policyname;