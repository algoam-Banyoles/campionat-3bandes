-- =====================================================
-- DEPLOYMENT SCRIPT: Head-to-Head Results Function
-- =====================================================
--
-- INSTRUCTIONS:
-- 1. Go to your Supabase Dashboard
-- 2. Navigate to: SQL Editor
-- 3. Create a new query
-- 4. Copy and paste this entire script
-- 5. Click "Run" to execute
--
-- This will create the get_head_to_head_results() function
-- needed for the Head-to-Head Results Grid feature.
-- =====================================================

-- Drop function if it already exists (to allow re-running)
DROP FUNCTION IF EXISTS get_head_to_head_results(UUID, UUID);

-- Create the head-to-head results function
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
  entrades INTEGER,
  punts_jugador1 INTEGER,
  mitjana_jugador1 NUMERIC
)
SECURITY DEFINER
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
    cp.entrades::INTEGER,
    -- Calculate points: 2 for win, 1 for draw, 0 for loss
    CASE
      WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 2
      WHEN cp.caramboles_jugador1 = cp.caramboles_jugador2 THEN 1
      ELSE 0
    END as punts_jugador1,
    -- Calculate average (mitjana): caramboles / entrades
    CASE
      WHEN cp.entrades > 0 THEN ROUND((cp.caramboles_jugador1::NUMERIC / cp.entrades::NUMERIC), 3)
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
  ORDER BY s1.nom, s2.nom;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_head_to_head_results(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_head_to_head_results(UUID, UUID) TO anon;

-- Verify the function was created successfully
SELECT
  'SUCCESS: Function get_head_to_head_results created!' as status,
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'get_head_to_head_results';
