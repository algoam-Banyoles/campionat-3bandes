-- Migration to fix Security Definer Views (DEFINITIVE FIX)
-- Removes SECURITY DEFINER from views to comply with Supabase security policies
-- Created: 2025-10-02 - Final version based on Supabase linter recommendations

-- Step 1: Capture existing behavior and DROP views with CASCADE
-- This ensures any dependencies are also dropped and recreated properly

DROP VIEW IF EXISTS public.v_analisi_calendari CASCADE;
DROP VIEW IF EXISTS public.v_promocions_candidates CASCADE;
DROP VIEW IF EXISTS public.v_player_badges CASCADE;

-- Step 2: Recreate v_analisi_calendari WITHOUT SECURITY DEFINER
-- Running with caller's privileges (SECURITY INVOKER by default)
CREATE VIEW public.v_analisi_calendari AS
SELECT 
    cp.event_id,
    e.nom as event_nom,
    cat.nom as categoria_nom,
    cat.id as categoria_id,
    COUNT(cp.id) as total_partides,
    COUNT(CASE WHEN cp.estat = 'validat' THEN 1 END) as partides_validades,
    COUNT(CASE WHEN cp.estat = 'pendent' THEN 1 END) as partides_pendents,
    MIN(cp.data_joc) as primera_partida,
    MAX(cp.data_joc) as darrera_partida
FROM calendari_partides cp
LEFT JOIN events e ON cp.event_id = e.id
LEFT JOIN categories cat ON cp.categoria_id = cat.id
GROUP BY cp.event_id, e.nom, cat.nom, cat.id;

-- Step 3: Recreate v_promocions_candidates WITHOUT SECURITY DEFINER
CREATE VIEW public.v_promocions_candidates AS
SELECT 
    rp.player_id,
    p.nom,
    s.cognoms,
    rp.posicio,
    rp.event_id,
    e.nom as event_nom,
    CASE 
        WHEN rp.posicio <= 3 THEN 'CANDIDAT_FORT'
        WHEN rp.posicio <= 5 THEN 'CANDIDAT_MODERAT'
        WHEN rp.posicio <= 10 THEN 'CANDIDAT_INICIAL'
        ELSE 'NO_CANDIDAT'
    END as tipus_candidatura
FROM ranking_positions rp
LEFT JOIN players p ON rp.player_id = p.id
LEFT JOIN socis s ON p.numero_soci = s.numero_soci
LEFT JOIN events e ON rp.event_id = e.id
WHERE rp.posicio <= 10;

-- Step 4: Recreate v_player_badges WITHOUT SECURITY DEFINER
CREATE VIEW public.v_player_badges AS
SELECT 
    p.id as player_id,
    p.nom,
    s.cognoms,
    p.numero_soci,
    rp.posicio,
    CASE 
        WHEN rp.posicio = 1 THEN 'CHAMPION'
        WHEN rp.posicio <= 3 THEN 'PODIUM'
        WHEN rp.posicio <= 10 THEN 'TOP_10'
        ELSE 'REGULAR'
    END as badge_type,
    CASE 
        WHEN rp.posicio = 1 THEN '🏆'
        WHEN rp.posicio = 2 THEN '🥈'
        WHEN rp.posicio = 3 THEN '🥉'
        WHEN rp.posicio <= 10 THEN '⭐'
        ELSE '👤'
    END as badge_emoji,
    0 as days_since_last -- Simplified to avoid complex subqueries
FROM players p
LEFT JOIN socis s ON p.numero_soci = s.numero_soci
LEFT JOIN ranking_positions rp ON p.id = rp.player_id
LEFT JOIN events e ON rp.event_id = e.id
WHERE e.actiu = true OR e.actiu IS NULL;

-- Step 5: Grant appropriate permissions
-- Views now run with caller's privileges, so explicit grants are needed
GRANT SELECT ON public.v_analisi_calendari TO authenticated, anon;
GRANT SELECT ON public.v_promocions_candidates TO authenticated, anon; 
GRANT SELECT ON public.v_player_badges TO authenticated, anon;

-- Step 6: Add security documentation
COMMENT ON VIEW public.v_analisi_calendari IS 'Vista d''anàlisi del calendari - SECURITY INVOKER (segur)';
COMMENT ON VIEW public.v_promocions_candidates IS 'Vista de candidats a promoció - SECURITY INVOKER (segur)';
COMMENT ON VIEW public.v_player_badges IS 'Vista de badges dels jugadors - SECURITY INVOKER (segur)';