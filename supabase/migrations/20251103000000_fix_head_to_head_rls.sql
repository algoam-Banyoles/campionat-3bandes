-- Migration: Fix head-to-head results function to use individual entrades and punts
-- Date: 2025-11-03
-- Description:
--   1. Uses existing entrades_jugador1, entrades_jugador2, punts_jugador1, punts_jugador2 columns
--   2. Fixes blank entries in graella by properly handling RLS in SECURITY DEFINER function
--   3. Migrates existing data and updates function to use individual values

-- Step 1: Migrate existing data from entrades to individual columns
-- If entrades has a value, copy it to both jugador columns (temporary, will be updated manually later)
UPDATE calendari_partides
SET
  entrades_jugador1 = COALESCE(entrades_jugador1, entrades),
  entrades_jugador2 = COALESCE(entrades_jugador2, entrades)
WHERE entrades IS NOT NULL
  AND (entrades_jugador1 IS NULL OR entrades_jugador2 IS NULL);

-- Step 2: Calculate and populate punts for existing validated matches
UPDATE calendari_partides
SET
  punts_jugador1 = CASE
    WHEN caramboles_jugador1 > caramboles_jugador2 THEN 2
    WHEN caramboles_jugador1 = caramboles_jugador2 THEN 1
    ELSE 0
  END,
  punts_jugador2 = CASE
    WHEN caramboles_jugador2 > caramboles_jugador1 THEN 2
    WHEN caramboles_jugador2 = caramboles_jugador1 THEN 1
    ELSE 0
  END
WHERE estat = 'validat'
  AND caramboles_jugador1 IS NOT NULL
  AND caramboles_jugador2 IS NOT NULL
  AND (punts_jugador1 IS NULL OR punts_jugador2 IS NULL);

-- Step 3: Drop and recreate the function with proper RLS handling
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
  -- Bypass RLS for this query since it's SECURITY DEFINER
  -- This ensures socis data is accessible regardless of RLS policies
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
    -- Use stored points if available, otherwise calculate: 2 for win, 1 for draw, 0 for loss
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
    -- Calculate average (mitjana): caramboles / entrades for jugador1
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
  WHERE cp.event_id = p_event_id
    AND cp.categoria_id = p_categoria_id
    AND cp.estat = 'validat'
    AND cp.caramboles_jugador1 IS NOT NULL
    AND cp.caramboles_jugador2 IS NOT NULL
  ORDER BY s1.cognoms, s1.nom, s2.cognoms, s2.nom;
END;
$$;

-- Grant execute permission to both authenticated and anonymous users
GRANT EXECUTE ON FUNCTION get_head_to_head_results(UUID, UUID) TO authenticated, anon;

-- Add comment explaining the security model
COMMENT ON FUNCTION get_head_to_head_results(UUID, UUID) IS
  'Retorna resultats head-to-head per una categoria. SECURITY DEFINER permet accés a socis bypassing RLS.';
