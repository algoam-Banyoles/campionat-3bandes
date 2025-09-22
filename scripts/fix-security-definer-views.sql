-- ===============================================
-- FIX RLS SECURITY ISSUES - STEP 3: FIX SECURITY DEFINER VIEWS  
-- ===============================================

-- Les vistes reportades per el linter estan definides amb SECURITY DEFINER
-- Les recreem sense aquesta propietat (per defecte són SECURITY INVOKER)

-- 1. DROP EXISTING SECURITY DEFINER VIEWS
DROP VIEW IF EXISTS public.v_challenges_pending;
DROP VIEW IF EXISTS public.v_player_badges; 
DROP VIEW IF EXISTS public.v_player_timeline;
DROP VIEW IF EXISTS public.v_maintenance_runs;
DROP VIEW IF EXISTS public.v_maintenance_run_details;

-- 2. RECREATE AS SECURITY INVOKER VIEWS (default behavior)

-- v_challenges_pending - Reptes pendents
CREATE OR REPLACE VIEW public.v_challenges_pending AS
SELECT 
    c.id,
    c.event_id,
    c.reptador_id,
    c.reptat_id,
    c.estat,
    c.data_proposta,
    c.data_acceptacio,
    c.data_programada,
    p1.nom as reptador_nom,
    p2.nom as reptat_nom
FROM challenges c
JOIN players p1 ON p1.id = c.reptador_id  
JOIN players p2 ON p2.id = c.reptat_id
WHERE c.estat IN ('proposat', 'acceptat', 'programat');

-- v_player_timeline - Timeline de jugador (si cal)
CREATE OR REPLACE VIEW public.v_player_timeline AS
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

-- v_maintenance_runs - Logs de manteniment
CREATE OR REPLACE VIEW public.v_maintenance_runs AS
SELECT 
    id,
    started_at,
    finished_at,
    triggered_by,
    ok,
    notes
FROM maintenance_runs
ORDER BY started_at DESC;

-- v_maintenance_run_details - Detalls de manteniment  
CREATE OR REPLACE VIEW public.v_maintenance_run_details AS
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

-- Grant permissions adequats
GRANT SELECT ON public.v_challenges_pending TO authenticated;
GRANT SELECT ON public.v_player_timeline TO authenticated;
GRANT SELECT ON public.v_maintenance_runs TO authenticated; 
GRANT SELECT ON public.v_maintenance_run_details TO authenticated;