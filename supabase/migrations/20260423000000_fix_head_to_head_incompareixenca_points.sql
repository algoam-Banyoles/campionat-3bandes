-- Fix: get_head_to_head_results must use punts_jugador1/2 to decide win/draw/loss
-- Rationale: for incompareixenca matches caramboles are 0/0 for both players, so comparing
-- caramboles alone returns "draw" (1-1). Instead, prefer the per-player stored points,
-- falling back to the caramboles comparison only when punts are NULL (legacy data).
-- This matches the pattern already used in get_social_league_classifications (see
-- 20260330000000_fix_social_incompareixenca_classifications_points.sql).

CREATE OR REPLACE FUNCTION public.get_head_to_head_results(p_event_id uuid, p_categoria_id uuid)
RETURNS TABLE(
  jugador1_nom text,
  jugador1_cognoms text,
  jugador1_numero_soci integer,
  jugador2_nom text,
  jugador2_cognoms text,
  jugador2_numero_soci integer,
  caramboles_jugador1 integer,
  caramboles_jugador2 integer,
  entrades_jugador1 integer,
  entrades_jugador2 integer,
  punts_jugador1 integer,
  punts_jugador2 integer,
  mitjana_jugador1 numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    s1.nom, s1.cognoms, s1.numero_soci,
    s2.nom, s2.cognoms, s2.numero_soci,
    cp.caramboles_jugador1::INTEGER,
    cp.caramboles_jugador2::INTEGER,
    COALESCE(cp.entrades_jugador1, cp.entrades, 0)::INTEGER,
    COALESCE(cp.entrades_jugador2, cp.entrades, 0)::INTEGER,
    COALESCE(
      cp.punts_jugador1,
      CASE
        WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
        WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
        ELSE 0
      END
    )::INTEGER,
    COALESCE(
      cp.punts_jugador2,
      CASE
        WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 2
        WHEN cp.caramboles_jugador2 = cp.caramboles_jugador1 THEN 1
        ELSE 0
      END
    )::INTEGER,
    CASE
      WHEN COALESCE(cp.entrades_jugador1, cp.entrades, 0) > 0
      THEN ROUND((cp.caramboles_jugador1::NUMERIC / COALESCE(cp.entrades_jugador1, cp.entrades)::NUMERIC), 3)
      ELSE 0
    END
  FROM calendari_partides cp
  LEFT JOIN socis s1 ON s1.numero_soci = cp.jugador1_soci_numero
  LEFT JOIN socis s2 ON s2.numero_soci = cp.jugador2_soci_numero
  LEFT JOIN inscripcions i1 ON i1.event_id = cp.event_id AND i1.soci_numero = cp.jugador1_soci_numero
  LEFT JOIN inscripcions i2 ON i2.event_id = cp.event_id AND i2.soci_numero = cp.jugador2_soci_numero
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
$function$;

GRANT EXECUTE ON FUNCTION public.get_head_to_head_results(uuid, uuid) TO anon, authenticated;
