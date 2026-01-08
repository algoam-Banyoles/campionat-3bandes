-- Migration: Remove SECURITY DEFINER from views
-- Date: 2025-12-12
-- Purpose: Fix Supabase linter warnings about SECURITY DEFINER views
--
-- These views were incorrectly created with SECURITY DEFINER, which is a security risk.
-- Views should use SECURITY INVOKER (the default) to run with the caller's privileges.
-- This ensures RLS policies are properly enforced.

-- Step 1: Drop existing views with CASCADE to handle dependencies
DROP VIEW IF EXISTS public.v_analisi_calendari CASCADE;
DROP VIEW IF EXISTS public.v_promocions_candidates CASCADE;
DROP VIEW IF EXISTS public.v_player_badges CASCADE;

-- Step 2: Recreate v_analisi_calendari WITHOUT SECURITY DEFINER
-- This view analyzes calendar statistics per event and category
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
-- This view identifies promotion candidates based on ranking positions
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
-- This view provides player badge information including cooldown status
CREATE VIEW public.v_player_badges AS
WITH active_event AS (
  SELECT id
  FROM events
  WHERE actiu IS TRUE
  ORDER BY creat_el DESC
  LIMIT 1
),
cfg AS (
  SELECT COALESCE(
    (SELECT cooldown_min_dies
     FROM app_settings
     ORDER BY updated_at DESC
     LIMIT 1),
    0
  ) AS cooldown_min_dies
),
lp AS (
  SELECT rp.event_id,
         rp.player_id,
         MAX(COALESCE(m.data_joc::date, c.data_proposta::date)) AS last_play_date,
         CASE
           WHEN MAX(COALESCE(m.data_joc::date, c.data_proposta::date)) IS NULL THEN NULL
           ELSE (CURRENT_DATE - MAX(COALESCE(m.data_joc::date, c.data_proposta::date)))::int
         END AS days_since_last
  FROM ranking_positions rp
  JOIN active_event ae ON ae.id = rp.event_id
  LEFT JOIN challenges c
    ON c.event_id = rp.event_id
   AND (c.reptador_id = rp.player_id OR c.reptat_id = rp.player_id)
  LEFT JOIN matches m ON m.challenge_id = c.id
  GROUP BY rp.event_id, rp.player_id
),
active AS (
  SELECT event_id, reptador_id AS player_id
  FROM challenges
  WHERE estat IN ('proposat', 'acceptat', 'programat')
  UNION
  SELECT event_id, reptat_id AS player_id
  FROM challenges
  WHERE estat IN ('proposat', 'acceptat', 'programat')
)
SELECT rp.event_id,
       rp.player_id,
       rp.posicio,
       lp.last_play_date,
       lp.days_since_last,
       (ac.player_id IS NOT NULL) AS has_active_challenge,
       CASE
         WHEN lp.last_play_date IS NULL THEN FALSE
         WHEN lp.days_since_last < (SELECT cooldown_min_dies FROM cfg) THEN TRUE
         ELSE FALSE
       END AS in_cooldown,
       CASE
         WHEN ac.player_id IS NOT NULL THEN FALSE
         WHEN lp.last_play_date IS NOT NULL AND lp.days_since_last < (SELECT cooldown_min_dies FROM cfg) THEN FALSE
         ELSE TRUE
       END AS can_be_challenged,
       GREATEST((SELECT cooldown_min_dies FROM cfg) - lp.days_since_last, 0) AS cooldown_days_left
FROM ranking_positions rp
JOIN active_event ae ON ae.id = rp.event_id
LEFT JOIN lp ON lp.event_id = rp.event_id AND lp.player_id = rp.player_id
LEFT JOIN active ac ON ac.event_id = rp.event_id AND ac.player_id = rp.player_id;

-- Step 5: Grant appropriate permissions
-- Since views now use SECURITY INVOKER (default), they run with caller's privileges
-- We need to grant SELECT permissions to allow access
GRANT SELECT ON public.v_analisi_calendari TO authenticated, anon;
GRANT SELECT ON public.v_promocions_candidates TO authenticated, anon;
GRANT SELECT ON public.v_player_badges TO authenticated, anon;

-- Step 6: Add documentation comments
COMMENT ON VIEW public.v_analisi_calendari IS
  'Calendar analysis view showing match statistics per event and category. Uses SECURITY INVOKER (default) for proper RLS enforcement.';

COMMENT ON VIEW public.v_promocions_candidates IS
  'Promotion candidates view showing top 10 players per event. Uses SECURITY INVOKER (default) for proper RLS enforcement.';

COMMENT ON VIEW public.v_player_badges IS
  'Player badges view with cooldown and challenge status. Uses SECURITY INVOKER (default) for proper RLS enforcement.';
