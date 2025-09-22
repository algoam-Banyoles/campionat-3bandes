-- ===============================================
-- FIX RLS SECURITY ISSUES - PAS 1: VERIFICAR ESTAT ACTUAL
-- ===============================================

-- 1. Verificar l'estat actual de RLS (sense forcerowsecurity)
SELECT 
    schemaname, 
    tablename, 
    rowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
    AND tablename IN ('socis', 'maintenance_runs', 'maintenance_run_items');

-- 2. Verificar policies existents
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 3. Verificar vistes amb SECURITY DEFINER
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'public' 
    AND viewname IN ('v_challenges_pending', 'v_player_badges', 'v_player_timeline', 'v_maintenance_runs', 'v_maintenance_run_details');