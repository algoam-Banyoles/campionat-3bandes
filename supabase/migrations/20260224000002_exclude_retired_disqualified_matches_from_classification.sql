-- Exclude matches involving withdrawn/disqualified players from social league classification calculations

DROP FUNCTION IF EXISTS get_social_league_classifications(UUID);

CREATE OR REPLACE FUNCTION get_social_league_classifications(p_event_id UUID)
RETURNS TABLE (
  player_id UUID,
  categoria_id UUID,
  posicio INTEGER,
  soci_numero INTEGER,
  soci_nom TEXT,
  soci_cognoms TEXT,
  punts INTEGER,
  caramboles_totals INTEGER,
  entrades_totals INTEGER,
  mitjana_general NUMERIC,
  millor_mitjana NUMERIC,
  partides_jugades INTEGER,
  partides_guanyades INTEGER,
  partides_empat INTEGER,
  partides_perdudes INTEGER,
  categoria_nom TEXT,
  categoria_ordre SMALLINT,
  estat_jugador TEXT,
  data_retirada TIMESTAMPTZ,
  motiu_retirada TEXT,
  eliminat_per_incompareixences BOOLEAN
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_matches AS (
    SELECT
      i.categoria_assignada_id as categoria_id,
      p.id as player_id,
      p.numero_soci as soci_numero,
      s.nom as soci_nom,
      s.cognoms as soci_cognoms,
      cp.id as match_id,
      cp.caramboles_jugador1,
      cp.caramboles_jugador2,
      CASE
        WHEN cp.jugador1_id = p.id THEN COALESCE(cp.entrades_jugador1, cp.entrades, 0)
        WHEN cp.jugador2_id = p.id THEN COALESCE(cp.entrades_jugador2, cp.entrades, 0)
        ELSE 0
      END as entrades,
      CASE
        WHEN cp.jugador1_id = p.id THEN cp.caramboles_jugador1
        WHEN cp.jugador2_id = p.id THEN cp.caramboles_jugador2
        ELSE NULL
      END as player_caramboles,
      CASE
        WHEN cp.jugador1_id = p.id THEN cp.caramboles_jugador2
        WHEN cp.jugador2_id = p.id THEN cp.caramboles_jugador1
        ELSE NULL
      END as opponent_caramboles,
      CASE
        WHEN cp.jugador1_id = p.id AND cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 'win'
        WHEN cp.jugador2_id = p.id AND cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 'win'
        WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 'draw'
        ELSE 'loss'
      END as result
    FROM inscripcions i
    INNER JOIN players p ON i.soci_numero = p.numero_soci
    LEFT JOIN socis s ON p.numero_soci = s.numero_soci
    LEFT JOIN calendari_partides cp ON (cp.jugador1_id = p.id OR cp.jugador2_id = p.id)
      AND cp.event_id = i.event_id
      AND cp.caramboles_jugador1 IS NOT NULL
      AND cp.caramboles_jugador2 IS NOT NULL
      AND COALESCE(cp.partida_anullada, false) = false
    LEFT JOIN players cp_j1 ON cp.jugador1_id = cp_j1.id
    LEFT JOIN players cp_j2 ON cp.jugador2_id = cp_j2.id
    LEFT JOIN inscripcions i_cp1 ON i_cp1.event_id = i.event_id AND i_cp1.soci_numero = cp_j1.numero_soci
    LEFT JOIN inscripcions i_cp2 ON i_cp2.event_id = i.event_id AND i_cp2.soci_numero = cp_j2.numero_soci
    WHERE i.event_id = p_event_id
      AND i.categoria_assignada_id IS NOT NULL
      AND COALESCE(i_cp1.eliminat_per_incompareixences, false) = false
      AND COALESCE(i_cp2.eliminat_per_incompareixences, false) = false
      AND COALESCE(i_cp1.estat_jugador, 'actiu') <> 'retirat'
      AND COALESCE(i_cp2.estat_jugador, 'actiu') <> 'retirat'
  ),
  all_players AS (
    SELECT DISTINCT
      i.categoria_assignada_id as categoria_id,
      p.id as player_id,
      p.numero_soci as soci_numero,
      s.nom as soci_nom,
      s.cognoms as soci_cognoms,
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
    INNER JOIN players p ON i.soci_numero = p.numero_soci
    LEFT JOIN socis s ON p.numero_soci = s.numero_soci
    WHERE i.event_id = p_event_id
      AND i.categoria_assignada_id IS NOT NULL
  ),
  player_stats AS (
    SELECT
      ap.categoria_id,
      ap.player_id,
      ap.soci_numero,
      ap.soci_nom,
      ap.soci_cognoms,
      ap.estat_jugador,
      ap.data_retirada,
      ap.motiu_retirada,
      ap.eliminat_per_incompareixences,
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
        END
      ), 0) as millor_mitjana
    FROM all_players ap
    LEFT JOIN player_matches pm ON ap.player_id = pm.player_id AND ap.categoria_id = pm.categoria_id
    GROUP BY ap.categoria_id, ap.player_id, ap.soci_numero, ap.soci_nom, ap.soci_cognoms, ap.estat_jugador, ap.data_retirada, ap.motiu_retirada, ap.eliminat_per_incompareixences
  ),
  ranked_players AS (
    SELECT
      ps.*,
      ROW_NUMBER() OVER (
        PARTITION BY ps.categoria_id
        ORDER BY
          ps.punts DESC,
          ps.mitjana_general DESC,
          ps.caramboles_totals DESC,
          ps.soci_cognoms ASC,
          ps.soci_nom ASC
      )::INTEGER as posicio
    FROM player_stats ps
  )
  SELECT
    rp.player_id,
    rp.categoria_id,
    rp.posicio,
    rp.soci_numero,
    rp.soci_nom,
    rp.soci_cognoms,
    rp.punts,
    rp.caramboles_totals,
    rp.entrades_totals,
    rp.mitjana_general,
    rp.millor_mitjana,
    rp.partides_jugades,
    rp.partides_guanyades,
    rp.partides_empat,
    rp.partides_perdudes,
    cat.nom as categoria_nom,
    cat.ordre_categoria as categoria_ordre,
    rp.estat_jugador,
    rp.data_retirada,
    rp.motiu_retirada,
    rp.eliminat_per_incompareixences
  FROM ranked_players rp
  LEFT JOIN categories cat ON rp.categoria_id = cat.id
  ORDER BY cat.ordre_categoria ASC, rp.posicio ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_social_league_classifications(UUID) TO anon, authenticated;

