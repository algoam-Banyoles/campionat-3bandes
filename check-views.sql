-- Check problematic views with SECURITY DEFINER
-- Query to see view definitions

-- Check if views exist
SELECT 
    schemaname,
    viewname,
    viewowner
FROM pg_views 
WHERE viewname IN ('v_analisi_calendari', 'v_promocions_candidates', 'v_player_badges')
ORDER BY viewname;

-- Get detailed view definitions
\d+ v_analisi_calendari
\d+ v_promocions_candidates  
\d+ v_player_badges