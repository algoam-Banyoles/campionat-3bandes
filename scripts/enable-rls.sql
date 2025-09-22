-- ===============================================
-- FIX RLS SECURITY ISSUES - STEP 1: ENABLE RLS
-- ===============================================

-- Activar RLS a les 3 taules reportades
ALTER TABLE public.socis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_runs ENABLE ROW LEVEL SECURITY; 
ALTER TABLE public.maintenance_run_items ENABLE ROW LEVEL SECURITY;

-- Verificar que s'ha activat correctament
SELECT 
    schemaname, 
    tablename, 
    rowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
    AND tablename IN ('socis', 'maintenance_runs', 'maintenance_run_items')
    AND rowsecurity = true;