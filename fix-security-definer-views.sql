-- Fix Security Definer Views
-- Remove SECURITY DEFINER from problematic views to comply with Supabase security policies

-- 1. Fix v_analisi_calendari
DROP VIEW IF EXISTS public.v_analisi_calendari CASCADE;

-- Recreate v_analisi_calendari WITHOUT SECURITY DEFINER
CREATE OR REPLACE VIEW public.v_analisi_calendari AS
SELECT 
    cp.event_id,
    e.nom as event_nom,
    cat.nom as categoria_nom,
    cat.id as categoria_id,
    COUNT(cp.id) as total_partides,
    COUNT(CASE WHEN cp.estat = 'validat' THEN 1 END) as partides_validades,
    COUNT(CASE WHEN cp.estat = 'pendent' THEN 1 END) as partides_pendents,
    COUNT(CASE WHEN cp.estat = 'programat' THEN 1 END) as partides_programades,
    ROUND(
        (COUNT(CASE WHEN cp.estat = 'validat' THEN 1 END)::numeric / 
         NULLIF(COUNT(cp.id), 0) * 100), 2
    ) as percentatge_completat,
    MIN(cp.data_joc) as primera_partida,
    MAX(cp.data_joc) as darrera_partida,
    COUNT(DISTINCT cp.jugador1_id) + COUNT(DISTINCT cp.jugador2_id) as jugadors_actius
FROM calendari_partides cp
LEFT JOIN events e ON cp.event_id = e.id
LEFT JOIN categories cat ON cp.categoria_id = cat.id
GROUP BY cp.event_id, e.nom, cat.nom, cat.id
ORDER BY e.nom, cat.nom;

-- 2. Fix v_promocions_candidates  
DROP VIEW IF EXISTS public.v_promocions_candidates CASCADE;

-- Recreate v_promocions_candidates WITHOUT SECURITY DEFINER
CREATE OR REPLACE VIEW public.v_promocions_candidates AS
SELECT 
    rp.player_id,
    p.nom,
    p.cognoms,
    rp.posicio,
    rp.mitjana,
    rp.partides_jugades,
    rp.partides_guanyades,
    rp.event_id,
    e.nom as event_nom,
    CASE 
        WHEN rp.posicio <= 3 AND rp.mitjana >= 0.8 AND rp.partides_jugades >= 10 THEN 'CANDIDAT_FORT'
        WHEN rp.posicio <= 5 AND rp.mitjana >= 0.6 AND rp.partides_jugades >= 8 THEN 'CANDIDAT_MODERAT'
        WHEN rp.posicio <= 10 AND rp.mitjana >= 0.4 AND rp.partides_jugades >= 5 THEN 'CANDIDAT_INICIAL'
        ELSE 'NO_CANDIDAT'
    END as tipus_candidatura
FROM ranking_positions rp
LEFT JOIN players p ON rp.player_id = p.id
LEFT JOIN events e ON rp.event_id = e.id
WHERE rp.posicio <= 10 AND rp.partides_jugades >= 5
ORDER BY rp.posicio;

-- 3. Fix v_player_badges
DROP VIEW IF EXISTS public.v_player_badges CASCADE;

-- Recreate v_player_badges WITHOUT SECURITY DEFINER
CREATE OR REPLACE VIEW public.v_player_badges AS
SELECT 
    p.id as player_id,
    p.nom,
    p.cognoms,
    p.numero_soci,
    rp.posicio,
    rp.mitjana,
    rp.partides_jugades,
    rp.partides_guanyades,
    CASE 
        WHEN rp.posicio = 1 THEN 'CHAMPION'
        WHEN rp.posicio <= 3 THEN 'PODIUM'
        WHEN rp.posicio <= 10 THEN 'TOP_10'
        WHEN rp.mitjana >= 1.0 THEN 'HIGH_AVERAGE'
        WHEN rp.partides_jugades >= 20 THEN 'ACTIVE_PLAYER'
        ELSE 'REGULAR'
    END as badge_type,
    CASE 
        WHEN rp.posicio = 1 THEN '🏆'
        WHEN rp.posicio = 2 THEN '🥈'
        WHEN rp.posicio = 3 THEN '🥉'
        WHEN rp.posicio <= 10 THEN '⭐'
        WHEN rp.mitjana >= 1.0 THEN '🎯'
        WHEN rp.partides_jugades >= 20 THEN '🔥'
        ELSE '👤'
    END as badge_emoji,
    -- Calculate days since last challenge
    EXTRACT(EPOCH FROM (NOW() - COALESCE(
        (SELECT MAX(ch.creat_el) 
         FROM challenges ch 
         WHERE ch.challenger_id = p.id OR ch.challenged_id = p.id),
        p.creat_el
    ))) / 86400 as days_since_last
FROM players p
LEFT JOIN ranking_positions rp ON p.id = rp.player_id
LEFT JOIN events e ON rp.event_id = e.id
WHERE e.actiu = true OR e.actiu IS NULL
ORDER BY rp.posicio NULLS LAST;

-- Grant appropriate permissions
GRANT SELECT ON public.v_analisi_calendari TO authenticated, anon;
GRANT SELECT ON public.v_promocions_candidates TO authenticated, anon;
GRANT SELECT ON public.v_player_badges TO authenticated, anon;

-- Add comments for documentation
COMMENT ON VIEW public.v_analisi_calendari IS 'Vista per analitzar l''estat del calendari de partides sense SECURITY DEFINER';
COMMENT ON VIEW public.v_promocions_candidates IS 'Vista per identificar candidats a promoció sense SECURITY DEFINER';
COMMENT ON VIEW public.v_player_badges IS 'Vista per mostrar badges dels jugadors sense SECURITY DEFINER';