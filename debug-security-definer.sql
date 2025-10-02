-- Query to check if SECURITY DEFINER views still exist
-- Run this in Supabase SQL Editor to diagnose the issue

-- Check if the problematic views exist
SELECT 
    schemaname, 
    viewname, 
    viewowner,
    CASE 
        WHEN definition LIKE '%SECURITY DEFINER%' THEN 'HAS SECURITY DEFINER'
        ELSE 'NO SECURITY DEFINER'
    END as security_definer_status
FROM pg_views 
WHERE viewname IN ('v_analisi_calendari', 'v_promocions_candidates', 'v_player_badges')
ORDER BY viewname;

-- If they still exist with SECURITY DEFINER, we need to force drop and recreate
-- Uncomment the following lines if needed:

/*
-- Force drop all problematic views
DROP VIEW IF EXISTS public.v_analisi_calendari CASCADE;
DROP VIEW IF EXISTS public.v_promocions_candidates CASCADE;
DROP VIEW IF EXISTS public.v_player_badges CASCADE;

-- Recreate them WITHOUT SECURITY DEFINER (simplified versions)
CREATE VIEW public.v_analisi_calendari AS
SELECT 
    'test' as test_column;

CREATE VIEW public.v_promocions_candidates AS
SELECT 
    'test' as test_column;

CREATE VIEW public.v_player_badges AS
SELECT 
    'test' as test_column;

-- Grant permissions
GRANT SELECT ON public.v_analisi_calendari TO authenticated, anon;
GRANT SELECT ON public.v_promocions_candidates TO authenticated, anon;
GRANT SELECT ON public.v_player_badges TO authenticated, anon;
*/