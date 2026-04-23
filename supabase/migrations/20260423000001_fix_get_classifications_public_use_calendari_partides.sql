-- Fix: get_classifications_public was based on legacy `matches` table via cp.match_id,
-- which is always NULL for social matches under the current model. It also filtered by
-- estat = 'validat' AND match_id IS NOT NULL, so it returned zeros for all social players.
-- Rewrite it to compute stats directly from calendari_partides using per-player
-- punts_jugador1/2 (with caramboles fallback), mirroring get_social_league_classifications.
-- Keeps the same output schema so the caller /campionats-socials/[eventId]/+page.svelte
-- continues to work unchanged.

CREATE OR REPLACE FUNCTION public.get_classifications_public(event_id_param uuid, category_ids uuid[])
RETURNS TABLE(
  id uuid,
  event_id uuid,
  categoria_id uuid,
  posicio integer,
  partides_jugades integer,
  partides_guanyades integer,
  partides_perdudes integer,
  partides_empat integer,
  caramboles_favor integer,
  caramboles_contra integer,
  mitjana_particular numeric,
  punts integer,
  updated_at timestamptz,
  categoria_nom text,
  categoria_distancia integer,
  categoria_ordre smallint,
  soci_nom text,
  soci_cognoms text,
  soci_numero integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN QUERY
  WITH player_matches AS (
    SELECT
      i.event_id AS ev_id,
      i.categoria_assignada_id AS cat_id,
      i.soci_numero AS numero_soci,
      cp.id AS match_id,
      CASE
        WHEN cp.jugador1_soci_numero = i.soci_numero THEN cp.caramboles_jugador1
        WHEN cp.jugador2_soci_numero = i.soci_numero THEN cp.caramboles_jugador2
      END AS c_favor,
      CASE
        WHEN cp.jugador1_soci_numero = i.soci_numero THEN cp.caramboles_jugador2
        WHEN cp.jugador2_soci_numero = i.soci_numero THEN cp.caramboles_jugador1
      END AS c_contra,
      CASE
        WHEN cp.jugador1_soci_numero = i.soci_numero THEN COALESCE(cp.entrades_jugador1, cp.entrades, 0)
        WHEN cp.jugador2_soci_numero = i.soci_numero THEN COALESCE(cp.entrades_jugador2, cp.entrades, 0)
      END AS entrades_player,
      CASE
        WHEN cp.jugador1_soci_numero = i.soci_numero THEN
          COALESCE(
            cp.punts_jugador1,
            CASE
              WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
              WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
              ELSE 0
            END
          )
        WHEN cp.jugador2_soci_numero = i.soci_numero THEN
          COALESCE(
            cp.punts_jugador2,
            CASE
              WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
              WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1
              ELSE 0
            END
          )
      END AS player_points
    FROM inscripcions i
    INNER JOIN calendari_partides cp
      ON (cp.jugador1_soci_numero = i.soci_numero OR cp.jugador2_soci_numero = i.soci_numero)
     AND cp.event_id = i.event_id
     AND cp.caramboles_jugador1 IS NOT NULL
     AND cp.caramboles_jugador2 IS NOT NULL
     AND COALESCE(cp.partida_anullada, false) = false
    LEFT JOIN inscripcions i_j1 ON i_j1.event_id = cp.event_id AND i_j1.soci_numero = cp.jugador1_soci_numero
    LEFT JOIN inscripcions i_j2 ON i_j2.event_id = cp.event_id AND i_j2.soci_numero = cp.jugador2_soci_numero
    WHERE i.event_id = event_id_param
      AND i.categoria_assignada_id IS NOT NULL
      AND (category_ids IS NULL OR i.categoria_assignada_id = ANY(category_ids))
      AND COALESCE(i_j1.eliminat_per_incompareixences, false) = false
      AND COALESCE(i_j2.eliminat_per_incompareixences, false) = false
      AND COALESCE(i_j1.estat_jugador, 'actiu') <> 'retirat'
      AND COALESCE(i_j2.estat_jugador, 'actiu') <> 'retirat'
  ),
  player_stats AS (
    SELECT
      i.event_id AS ev_id,
      i.categoria_assignada_id AS cat_id,
      i.soci_numero AS numero_soci,
      COUNT(pm.match_id)::INTEGER AS p_jugades,
      COUNT(CASE WHEN pm.player_points = 2 THEN 1 END)::INTEGER AS p_guanyades,
      COUNT(CASE WHEN pm.player_points = 0 THEN 1 END)::INTEGER AS p_perdudes,
      COUNT(CASE WHEN pm.player_points = 1 THEN 1 END)::INTEGER AS p_empat,
      COALESCE(SUM(pm.c_favor), 0)::INTEGER AS c_favor_total,
      COALESCE(SUM(pm.c_contra), 0)::INTEGER AS c_contra_total,
      COALESCE(SUM(pm.entrades_player), 0)::INTEGER AS entrades_total,
      COALESCE(SUM(pm.player_points), 0)::INTEGER AS total_punts
    FROM inscripcions i
    LEFT JOIN player_matches pm
      ON pm.ev_id = i.event_id
     AND pm.cat_id = i.categoria_assignada_id
     AND pm.numero_soci = i.soci_numero
    WHERE i.event_id = event_id_param
      AND i.categoria_assignada_id IS NOT NULL
      AND (category_ids IS NULL OR i.categoria_assignada_id = ANY(category_ids))
      AND COALESCE(i.eliminat_per_incompareixences, false) = false
      AND COALESCE(i.estat_jugador, 'actiu') <> 'retirat'
    GROUP BY i.event_id, i.categoria_assignada_id, i.soci_numero
  ),
  ranked_players AS (
    SELECT
      ps.*,
      CASE WHEN ps.entrades_total > 0
           THEN ROUND((ps.c_favor_total::NUMERIC / ps.entrades_total::NUMERIC), 3)
           ELSE 0
      END AS mitjana,
      ROW_NUMBER() OVER (
        PARTITION BY ps.cat_id
        ORDER BY
          ps.total_punts DESC,
          CASE WHEN ps.entrades_total > 0
               THEN ps.c_favor_total::NUMERIC / ps.entrades_total::NUMERIC
               ELSE 0
          END DESC,
          ps.c_favor_total DESC
      )::INTEGER AS pos
    FROM player_stats ps
  )
  SELECT
    gen_random_uuid() AS id,
    rp.ev_id AS event_id,
    rp.cat_id AS categoria_id,
    rp.pos AS posicio,
    rp.p_jugades AS partides_jugades,
    rp.p_guanyades AS partides_guanyades,
    rp.p_perdudes AS partides_perdudes,
    rp.p_empat AS partides_empat,
    rp.c_favor_total AS caramboles_favor,
    rp.c_contra_total AS caramboles_contra,
    rp.mitjana AS mitjana_particular,
    rp.total_punts AS punts,
    NOW() AS updated_at,
    cat.nom AS categoria_nom,
    cat.distancia_caramboles AS categoria_distancia,
    cat.ordre_categoria AS categoria_ordre,
    s.nom AS soci_nom,
    s.cognoms AS soci_cognoms,
    rp.numero_soci AS soci_numero
  FROM ranked_players rp
  LEFT JOIN categories cat ON rp.cat_id = cat.id
  LEFT JOIN socis s ON s.numero_soci = rp.numero_soci
  ORDER BY cat.ordre_categoria ASC, rp.pos ASC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_classifications_public(uuid, uuid[]) TO anon, authenticated;
