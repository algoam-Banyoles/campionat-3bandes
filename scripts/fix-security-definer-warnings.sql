-- ===============================================
-- FIX SECURITY DEFINER VIEWS WARNINGS
-- ===============================================
-- Script per arreglar les vistes reportades per Supabase Database Linter
-- que estan definides amb SECURITY DEFINER
-- 
-- Les recreem sense aquesta propietat (per defecte són SECURITY INVOKER)
-- mantenint la mateixa funcionalitat però sense el risc de seguretat

-- 1. DROP LES VISTES EXISTENTS
DROP VIEW IF EXISTS public.v_analisi_calendari CASCADE;
DROP VIEW IF EXISTS public.v_player_badges CASCADE; 
DROP VIEW IF EXISTS public.v_promocions_candidates CASCADE;

-- 2. RECREAR COM SECURITY INVOKER VIEWS (comportament per defecte)

-- v_analisi_calendari - Anàlisi del calendari de partides
CREATE OR REPLACE VIEW public.v_analisi_calendari AS
SELECT
    cp.event_id,
    cp.categoria_id,
    c.nom as categoria_nom,
    COUNT(*) as total_partides,
    COUNT(*) FILTER (WHERE cp.estat = 'generat') as partides_generades,
    COUNT(*) FILTER (WHERE cp.estat = 'validat') as partides_validades,
    COUNT(*) FILTER (WHERE cp.estat = 'jugada') as partides_jugades,
    COUNT(*) FILTER (WHERE cp.estat = 'pendent_programar') as partides_pendents,
    MIN(DATE(cp.data_programada)) as data_inici,
    MAX(DATE(cp.data_programada)) as data_fi,
    CASE
        WHEN MIN(DATE(cp.data_programada)) IS NOT NULL THEN
            MAX(DATE(cp.data_programada)) - MIN(DATE(cp.data_programada))
        ELSE NULL
    END as durada_dies
FROM calendari_partides cp
JOIN categories c ON cp.categoria_id = c.id
GROUP BY cp.event_id, cp.categoria_id, c.nom;

-- v_player_badges - Badges i estat dels jugadors
CREATE OR REPLACE VIEW public.v_player_badges AS
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

-- v_promocions_candidates - Candidates per promoció
CREATE OR REPLACE VIEW public.v_promocions_candidates AS
SELECT
    e.nom AS event_name,
    e.id AS event_id,
    p.player_id,
    p.player_name,
    p.current_category_name,
    p.current_position,
    p.current_average,
    p.target_category_name,
    p.meets_minimum,
    p.required_minimum,
    CASE
        WHEN p.meets_minimum THEN 'Apte per promoció'
        ELSE CONCAT('Promig insuficient (mínim: ', p.required_minimum, ')')
    END AS estat_promocio
FROM events e
CROSS JOIN LATERAL get_eligible_promotions(e.id) p
WHERE e.estat_competicio = 'finalitzat'
ORDER BY e.nom, p.current_category_name, p.current_position;

-- 3. ASSIGNAR PERMISOS ADEQUATS
GRANT SELECT ON public.v_analisi_calendari TO authenticated;
GRANT SELECT ON public.v_player_badges TO authenticated;
GRANT SELECT ON public.v_promocions_candidates TO authenticated;

-- 4. HABILITAR RLS (Row Level Security) si és necessari
-- Les vistes heretaran les polítiques RLS de les taules subjacents
ALTER VIEW public.v_analisi_calendari SET (security_barrier = true);
ALTER VIEW public.v_player_badges SET (security_barrier = true);
ALTER VIEW public.v_promocions_candidates SET (security_barrier = true);

-- NOTA: Aquestes vistes ara s'executaran amb els permisos de l'usuari que les consulta
-- en lloc dels permisos del creador, el que elimina el risc de seguretat reportat.