-- Fase 5c Sessio 3 / Fase D
-- Recrear les 4 vistes que depenien de la taula players, ara llegint nom des de socis directament.
-- La signatura externa es manté (player_id UUID) per no trencar consumidors. Els JOINs interns
-- usen les columnes *_soci_numero ja poblades pels triggers dual-write.

DROP VIEW IF EXISTS public.v_challenges_pending;
CREATE VIEW public.v_challenges_pending AS
 SELECT c.id,
    c.event_id,
    c.reptador_id,
    c.reptat_id,
    c.estat,
    c.data_proposta,
    c.data_programada,
    s1.nom AS reptador_nom,
    s2.nom AS reptat_nom
   FROM challenges c
     JOIN socis s1 ON s1.numero_soci = c.reptador_soci_numero
     JOIN socis s2 ON s2.numero_soci = c.reptat_soci_numero
  WHERE c.estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state]);

DROP VIEW IF EXISTS public.v_player_badges;
CREATE VIEW public.v_player_badges AS
 WITH active_event AS (
         SELECT events.id
           FROM events
          WHERE events.actiu IS TRUE
          ORDER BY events.creat_el DESC
         LIMIT 1
        ), cfg AS (
         SELECT COALESCE((( SELECT app_settings.cooldown_min_dies
                   FROM app_settings
                  ORDER BY app_settings.updated_at DESC
                 LIMIT 1))::integer, 0) AS cooldown_min_dies
        ), lp AS (
         SELECT rp_1.event_id,
            rp_1.player_id,
            max(COALESCE(m.data_joc::date, c.data_proposta::date)) AS last_play_date,
                CASE
                    WHEN max(COALESCE(m.data_joc::date, c.data_proposta::date)) IS NULL THEN NULL::integer
                    ELSE CURRENT_DATE - max(COALESCE(m.data_joc::date, c.data_proposta::date))
                END AS days_since_last
           FROM ranking_positions rp_1
             JOIN active_event ae_1 ON ae_1.id = rp_1.event_id
             LEFT JOIN challenges c ON c.event_id = rp_1.event_id AND (c.reptador_id = rp_1.player_id OR c.reptat_id = rp_1.player_id)
             LEFT JOIN matches m ON m.challenge_id = c.id
          GROUP BY rp_1.event_id, rp_1.player_id
        ), active AS (
         SELECT challenges.event_id,
            challenges.reptador_id AS player_id
           FROM challenges
          WHERE challenges.estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state])
        UNION
         SELECT challenges.event_id,
            challenges.reptat_id AS player_id
           FROM challenges
          WHERE challenges.estat = ANY (ARRAY['proposat'::challenge_state, 'acceptat'::challenge_state, 'programat'::challenge_state])
        )
 SELECT rp.event_id,
    rp.player_id,
    rp.posicio,
    lp.last_play_date,
    lp.days_since_last,
    ac.player_id IS NOT NULL AS has_active_challenge,
        CASE
            WHEN lp.last_play_date IS NULL THEN false
            WHEN lp.days_since_last < (( SELECT cfg.cooldown_min_dies
               FROM cfg)) THEN true
            ELSE false
        END AS in_cooldown,
        CASE
            WHEN ac.player_id IS NOT NULL THEN false
            WHEN lp.last_play_date IS NOT NULL AND lp.days_since_last < (( SELECT cfg.cooldown_min_dies
               FROM cfg)) THEN false
            ELSE true
        END AS can_be_challenged,
    GREATEST((( SELECT cfg.cooldown_min_dies
           FROM cfg)) - lp.days_since_last, 0) AS cooldown_days_left
   FROM ranking_positions rp
     JOIN active_event ae ON ae.id = rp.event_id
     LEFT JOIN lp ON lp.event_id = rp.event_id AND lp.player_id = rp.player_id
     LEFT JOIN active ac ON ac.event_id = rp.event_id AND ac.player_id = rp.player_id;

DROP VIEW IF EXISTS public.v_player_timeline;
CREATE VIEW public.v_player_timeline AS
 SELECT c.reptador_id AS player_id,
    s.nom,
    'challenge'::text AS event_type,
    c.data_proposta AS event_date,
    'Repte proposat'::text AS description
   FROM challenges c
     JOIN socis s ON s.numero_soci = c.reptador_soci_numero
UNION ALL
 SELECT c.reptat_id AS player_id,
    s.nom,
    'challenge'::text AS event_type,
    c.data_proposta AS event_date,
    'Repte proposat'::text AS description
   FROM challenges c
     JOIN socis s ON s.numero_soci = c.reptat_soci_numero
UNION ALL
 SELECT c.reptador_id AS player_id,
    s.nom,
    'match'::text AS event_type,
    m.data_joc AS event_date,
    'Partida jugada'::text AS description
   FROM challenges c
     JOIN matches m ON m.challenge_id = c.id
     JOIN socis s ON s.numero_soci = c.reptador_soci_numero
UNION ALL
 SELECT c.reptat_id AS player_id,
    s.nom,
    'match'::text AS event_type,
    m.data_joc AS event_date,
    'Partida jugada'::text AS description
   FROM challenges c
     JOIN matches m ON m.challenge_id = c.id
     JOIN socis s ON s.numero_soci = c.reptat_soci_numero
  ORDER BY 4 DESC;

DROP VIEW IF EXISTS public.v_promocions_candidates;
CREATE VIEW public.v_promocions_candidates AS
 SELECT rp.player_id,
    s.nom,
    s.cognoms,
    rp.posicio,
    rp.event_id,
    e.nom AS event_nom,
        CASE
            WHEN rp.posicio <= 3 THEN 'CANDIDAT_FORT'::text
            WHEN rp.posicio <= 5 THEN 'CANDIDAT_MODERAT'::text
            WHEN rp.posicio <= 10 THEN 'CANDIDAT_INICIAL'::text
            ELSE 'NO_CANDIDAT'::text
        END AS tipus_candidatura
   FROM ranking_positions rp
     LEFT JOIN socis s ON s.numero_soci = rp.soci_numero
     LEFT JOIN events e ON rp.event_id = e.id
  WHERE rp.posicio <= 10;
