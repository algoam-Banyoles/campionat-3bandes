-- get_social_league_classifications: afegeix fallback a la taula `classificacions`
-- per events històrics sense inscripcions i back-càlcul d'entrades_totals a
-- partir de caramboles/mitjana per mostrar la columna "Ent. Tot." a la UI.
--
-- La primera branca (càlcul en temps real a partir de inscripcions+calendari)
-- preserva la lògica post-Fase 5c (usa jugador1_soci_numero i jugador2_soci_numero,
-- NO la taula players ni jugador1_id/jugador2_id).

CREATE OR REPLACE FUNCTION public.get_social_league_classifications(p_event_id uuid)
RETURNS TABLE (
  categoria_id uuid,
  posicio integer,
  soci_numero integer,
  soci_nom text,
  soci_cognoms text,
  punts integer,
  caramboles_totals integer,
  entrades_totals integer,
  mitjana_general numeric,
  millor_mitjana numeric,
  partides_jugades integer,
  partides_guanyades integer,
  partides_empat integer,
  partides_perdudes integer,
  categoria_nom text,
  categoria_ordre smallint,
  estat_jugador text,
  data_retirada timestamp with time zone,
  motiu_retirada text,
  eliminat_per_incompareixences boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_has_inscriptions BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM inscripcions i
    WHERE i.event_id = p_event_id AND i.categoria_assignada_id IS NOT NULL
  ) INTO v_has_inscriptions;

  IF v_has_inscriptions THEN
    RETURN QUERY
    WITH player_matches_raw AS (
      SELECT
        i.categoria_assignada_id as cat_id,
        i.soci_numero as s_numero,
        s.nom as s_nom,
        s.cognoms as s_cognoms,
        cp.id as match_id,
        CASE
          WHEN cp.jugador1_soci_numero = i.soci_numero THEN COALESCE(cp.entrades_jugador1, cp.entrades, 0)
          WHEN cp.jugador2_soci_numero = i.soci_numero THEN COALESCE(cp.entrades_jugador2, cp.entrades, 0)
          ELSE 0
        END as entrades,
        CASE
          WHEN cp.jugador1_soci_numero = i.soci_numero THEN cp.caramboles_jugador1
          WHEN cp.jugador2_soci_numero = i.soci_numero THEN cp.caramboles_jugador2
          ELSE NULL
        END as player_caramboles,
        CASE
          WHEN cp.id IS NULL THEN NULL
          WHEN cp.jugador1_soci_numero = i.soci_numero THEN
            COALESCE(cp.punts_jugador1,
              CASE
                WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
                WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
                ELSE 0
              END)
          WHEN cp.jugador2_soci_numero = i.soci_numero THEN
            COALESCE(cp.punts_jugador2,
              CASE
                WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
                WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1
                ELSE 0
              END)
          ELSE NULL
        END as player_points,
        CASE
          WHEN cp.id IS NULL THEN NULL
          WHEN cp.jugador1_soci_numero = i.soci_numero THEN
            COALESCE(cp.punts_jugador2,
              CASE
                WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
                WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1
                ELSE 0
              END)
          WHEN cp.jugador2_soci_numero = i.soci_numero THEN
            COALESCE(cp.punts_jugador1,
              CASE
                WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
                WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
                ELSE 0
              END)
          ELSE NULL
        END as opponent_points
      FROM inscripcions i
      LEFT JOIN socis s ON s.numero_soci = i.soci_numero
      LEFT JOIN calendari_partides cp ON (cp.jugador1_soci_numero = i.soci_numero OR cp.jugador2_soci_numero = i.soci_numero)
        AND cp.event_id = i.event_id
        AND cp.caramboles_jugador1 IS NOT NULL
        AND cp.caramboles_jugador2 IS NOT NULL
        AND COALESCE(cp.partida_anullada, false) = false
      LEFT JOIN inscripcions i_cp1 ON i_cp1.event_id = i.event_id AND i_cp1.soci_numero = cp.jugador1_soci_numero
      LEFT JOIN inscripcions i_cp2 ON i_cp2.event_id = i.event_id AND i_cp2.soci_numero = cp.jugador2_soci_numero
      WHERE i.event_id = p_event_id
        AND i.categoria_assignada_id IS NOT NULL
        AND COALESCE(i_cp1.eliminat_per_incompareixences, false) = false
        AND COALESCE(i_cp2.eliminat_per_incompareixences, false) = false
        AND COALESCE(i_cp1.estat_jugador, 'actiu') <> 'retirat'
        AND COALESCE(i_cp2.estat_jugador, 'actiu') <> 'retirat'
    ),
    player_matches AS (
      SELECT r.*,
        CASE
          WHEN r.match_id IS NULL THEN NULL
          WHEN r.player_points > r.opponent_points THEN 'win'
          WHEN r.player_points = r.opponent_points THEN 'draw'
          ELSE 'loss'
        END as result
      FROM player_matches_raw r
    ),
    all_players AS (
      SELECT DISTINCT
        i.categoria_assignada_id as cat_id,
        i.soci_numero as s_numero,
        s.nom as s_nom,
        s.cognoms as s_cognoms,
        CASE
          WHEN COALESCE(i.eliminat_per_incompareixences, false) = true THEN 'retirat'
          WHEN i.estat_jugador = 'retirat' THEN 'retirat'
          ELSE 'actiu'
        END as estat_jugador,
        COALESCE(i.data_retirada, i.data_eliminacio) as data_retirada,
        CASE
          WHEN COALESCE(i.eliminat_per_incompareixences, false) = true THEN 'Desqualificat per 2 incompareixences'
          ELSE i.motiu_retirada
        END as motiu_retirada,
        COALESCE(i.eliminat_per_incompareixences, false) as eliminat_per_incompareixences
      FROM inscripcions i
      LEFT JOIN socis s ON s.numero_soci = i.soci_numero
      WHERE i.event_id = p_event_id
        AND i.categoria_assignada_id IS NOT NULL
    ),
    player_stats AS (
      SELECT
        ap.cat_id, ap.s_numero, ap.s_nom, ap.s_cognoms,
        ap.estat_jugador, ap.data_retirada, ap.motiu_retirada, ap.eliminat_per_incompareixences,
        COUNT(pm.match_id)::INTEGER as partides_jugades,
        COUNT(CASE WHEN pm.result = 'win' THEN 1 END)::INTEGER as partides_guanyades,
        COUNT(CASE WHEN pm.result = 'draw' THEN 1 END)::INTEGER as partides_empat,
        COUNT(CASE WHEN pm.result = 'loss' THEN 1 END)::INTEGER as partides_perdudes,
        (COUNT(CASE WHEN pm.result = 'win' THEN 1 END) * 2 +
         COUNT(CASE WHEN pm.result = 'draw' THEN 1 END))::INTEGER as punts,
        COALESCE(SUM(pm.player_caramboles), 0)::INTEGER as caramboles_totals,
        COALESCE(SUM(pm.entrades), 0)::INTEGER as entrades_totals,
        CASE
          WHEN SUM(pm.entrades) > 0 THEN
            ROUND((SUM(pm.player_caramboles)::NUMERIC / SUM(pm.entrades)::NUMERIC), 3)
          ELSE 0
        END as mitjana_general,
        COALESCE(MAX(
          CASE
            WHEN pm.entrades > 0 THEN
              ROUND((pm.player_caramboles::NUMERIC / pm.entrades::NUMERIC), 3)
            ELSE 0
          END), 0) as millor_mitjana
      FROM all_players ap
      LEFT JOIN player_matches pm ON ap.s_numero = pm.s_numero AND ap.cat_id = pm.cat_id
      GROUP BY ap.cat_id, ap.s_numero, ap.s_nom, ap.s_cognoms,
               ap.estat_jugador, ap.data_retirada, ap.motiu_retirada, ap.eliminat_per_incompareixences
    ),
    ranked_players AS (
      SELECT ps.*,
        ROW_NUMBER() OVER (
          PARTITION BY ps.cat_id
          ORDER BY ps.punts DESC, ps.mitjana_general DESC, ps.caramboles_totals DESC,
                   ps.s_cognoms ASC, ps.s_nom ASC
        )::INTEGER as posicio
      FROM player_stats ps
    )
    SELECT
      rp.cat_id as categoria_id,
      rp.posicio,
      rp.s_numero as soci_numero,
      rp.s_nom as soci_nom,
      rp.s_cognoms as soci_cognoms,
      rp.punts, rp.caramboles_totals, rp.entrades_totals,
      rp.mitjana_general, rp.millor_mitjana,
      rp.partides_jugades, rp.partides_guanyades, rp.partides_empat, rp.partides_perdudes,
      cat.nom as categoria_nom, cat.ordre_categoria as categoria_ordre,
      rp.estat_jugador, rp.data_retirada, rp.motiu_retirada, rp.eliminat_per_incompareixences
    FROM ranked_players rp
    LEFT JOIN categories cat ON rp.cat_id = cat.id
    ORDER BY cat.ordre_categoria ASC, rp.posicio ASC;

  ELSE
    RETURN QUERY
    SELECT
      c.categoria_id,
      c.posicio::INTEGER,
      c.soci_numero,
      s.nom as soci_nom,
      s.cognoms as soci_cognoms,
      c.punts::INTEGER,
      c.caramboles_favor::INTEGER as caramboles_totals,
      -- Back-càlcul: entrades = caramboles / mitjana (arrodonit).
      CASE
        WHEN c.mitjana_particular IS NOT NULL
         AND c.mitjana_particular > 0
         AND c.caramboles_favor IS NOT NULL
        THEN ROUND(c.caramboles_favor::NUMERIC / c.mitjana_particular)::INTEGER
        ELSE NULL
      END AS entrades_totals,
      c.mitjana_particular as mitjana_general,
      NULL::NUMERIC as millor_mitjana,
      c.partides_jugades::INTEGER,
      c.partides_guanyades::INTEGER,
      c.partides_empat::INTEGER,
      c.partides_perdudes::INTEGER,
      cat.nom as categoria_nom,
      cat.ordre_categoria as categoria_ordre,
      'actiu'::TEXT as estat_jugador,
      NULL::TIMESTAMP WITH TIME ZONE as data_retirada,
      NULL::TEXT as motiu_retirada,
      false as eliminat_per_incompareixences
    FROM classificacions c
    LEFT JOIN socis s ON s.numero_soci = c.soci_numero
    LEFT JOIN categories cat ON cat.id = c.categoria_id
    WHERE c.event_id = p_event_id
    ORDER BY cat.ordre_categoria ASC, c.posicio ASC;
  END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_social_league_classifications(uuid) TO anon, authenticated;
