-- Exclude withdrawn/disqualified players from head-to-head results

DROP FUNCTION IF EXISTS get_head_to_head_results(UUID, UUID);

CREATE OR REPLACE FUNCTION get_head_to_head_results(
  p_event_id UUID,
  p_categoria_id UUID
)
RETURNS TABLE (
  jugador1_id UUID,
  jugador1_nom TEXT,
  jugador1_cognoms TEXT,
  jugador1_numero_soci INTEGER,
  jugador2_id UUID,
  jugador2_nom TEXT,
  jugador2_cognoms TEXT,
  jugador2_numero_soci INTEGER,
  caramboles_jugador1 INTEGER,
  caramboles_jugador2 INTEGER,
  entrades_jugador1 INTEGER,
  entrades_jugador2 INTEGER,
  punts_jugador1 INTEGER,
  punts_jugador2 INTEGER,
  mitjana_jugador1 NUMERIC
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cp.jugador1_id,
    s1.nom as jugador1_nom,
    s1.cognoms as jugador1_cognoms,
    p1.numero_soci as jugador1_numero_soci,
    cp.jugador2_id,
    s2.nom as jugador2_nom,
    s2.cognoms as jugador2_cognoms,
    p2.numero_soci as jugador2_numero_soci,
    cp.caramboles_jugador1::INTEGER,
    cp.caramboles_jugador2::INTEGER,
    COALESCE(cp.entrades_jugador1, cp.entrades)::INTEGER as entrades_jugador1,
    COALESCE(cp.entrades_jugador2, cp.entrades)::INTEGER as entrades_jugador2,
    COALESCE(
      cp.punts_jugador1,
      CASE
        WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
        WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
        ELSE 0
      END
    )::INTEGER as punts_jugador1,
    COALESCE(
      cp.punts_jugador2,
      CASE
        WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
        WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1
        ELSE 0
      END
    )::INTEGER as punts_jugador2,
    CASE
      WHEN COALESCE(cp.entrades_jugador1, cp.entrades, 0) > 0
      THEN ROUND((cp.caramboles_jugador1::NUMERIC / COALESCE(cp.entrades_jugador1, cp.entrades)::NUMERIC), 3)
      ELSE 0
    END as mitjana_jugador1
  FROM calendari_partides cp
  LEFT JOIN players p1 ON cp.jugador1_id = p1.id
  LEFT JOIN socis s1 ON p1.numero_soci = s1.numero_soci
  LEFT JOIN players p2 ON cp.jugador2_id = p2.id
  LEFT JOIN socis s2 ON p2.numero_soci = s2.numero_soci
  LEFT JOIN inscripcions i1 ON i1.event_id = cp.event_id AND i1.soci_numero = p1.numero_soci
  LEFT JOIN inscripcions i2 ON i2.event_id = cp.event_id AND i2.soci_numero = p2.numero_soci
  WHERE cp.event_id = p_event_id
    AND cp.categoria_id = p_categoria_id
    AND cp.caramboles_jugador1 IS NOT NULL
    AND cp.caramboles_jugador2 IS NOT NULL
    AND COALESCE(cp.partida_anullada, false) = false
    AND COALESCE(i1.eliminat_per_incompareixences, false) = false
    AND COALESCE(i2.eliminat_per_incompareixences, false) = false
    AND COALESCE(i1.estat_jugador, 'actiu') <> 'retirat'
    AND COALESCE(i2.estat_jugador, 'actiu') <> 'retirat'
  ORDER BY s1.cognoms, s1.nom, s2.cognoms, s2.nom;
END;
$$;

GRANT EXECUTE ON FUNCTION get_head_to_head_results(UUID, UUID) TO authenticated, anon;

