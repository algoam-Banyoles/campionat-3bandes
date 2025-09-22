-- ===============================================
-- FIX SECURITY DEFINER VIEWS - SPECIFIC FIX
-- ===============================================

-- Force drop views with CASCADE to remove dependencies
DROP VIEW IF EXISTS public.v_challenges_pending CASCADE;
DROP VIEW IF EXISTS public.v_player_timeline CASCADE;
DROP VIEW IF EXISTS public.v_maintenance_runs CASCADE;
DROP VIEW IF EXISTS public.v_maintenance_run_details CASCADE;

-- Recreate views explicitly with SECURITY INVOKER
CREATE VIEW public.v_challenges_pending 
WITH (security_invoker=on) AS
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

CREATE VIEW public.v_player_timeline 
WITH (security_invoker=on) AS
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

CREATE VIEW public.v_maintenance_runs 
WITH (security_invoker=on) AS
SELECT 
    id,
    started_at,
    finished_at,
    triggered_by,
    ok,
    notes
FROM maintenance_runs
ORDER BY started_at DESC;

CREATE VIEW public.v_maintenance_run_details 
WITH (security_invoker=on) AS
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

-- Verification: This should return EMPTY if views are fixed
SELECT 
    schemaname,
    viewname,
    'STILL HAS SECURITY DEFINER' as status
FROM pg_views 
WHERE schemaname = 'public' 
    AND viewname IN ('v_challenges_pending', 'v_player_timeline', 'v_maintenance_runs', 'v_maintenance_run_details')
    AND definition LIKE '%SECURITY DEFINER%';

-- Show current view definitions to verify
SELECT 
    schemaname,
    viewname,
    left(definition, 100) as definition_start
FROM pg_views 
WHERE schemaname = 'public' 
    AND viewname IN ('v_challenges_pending', 'v_player_timeline', 'v_maintenance_runs', 'v_maintenance_run_details')
ORDER BY viewname;