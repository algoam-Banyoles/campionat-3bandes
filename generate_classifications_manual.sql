-- ============================================================================
-- EXECUTAR AQUEST SQL A LA CONSOLA SQL DE SUPABASE
-- ============================================================================
-- Aquest script crea la funció per generar classificacions finals
-- i després les genera per al campionat especificat
-- ============================================================================

-- Pas 1: Crear la funció
CREATE OR REPLACE FUNCTION generate_final_classifications(p_event_id UUID)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  classifications_count INTEGER
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER := 0;
  v_event_record RECORD;
BEGIN
  -- Verificar que l'event existeix
  SELECT id, nom, estat_competicio INTO v_event_record
  FROM events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Event no trobat', 0;
    RETURN;
  END IF;

  -- Esborrar classificacions existents per aquest event
  DELETE FROM classificacions WHERE event_id = p_event_id;

  -- Insertar noves classificacions des de la funció RPC
  INSERT INTO classificacions (
    event_id,
    categoria_id,
    player_id,
    posicio,
    partides_jugades,
    partides_guanyades,
    partides_perdudes,
    partides_empat,
    punts,
    caramboles_favor,
    caramboles_contra,
    mitjana_particular,
    updated_at
  )
  SELECT
    p_event_id,
    cl.categoria_id,
    cl.player_id,
    cl.posicio,
    cl.partides_jugades,
    cl.partides_guanyades,
    cl.partides_perdudes,
    cl.partides_empat,
    cl.punts,
    cl.caramboles_totals as caramboles_favor,
    cl.entrades_totals as caramboles_contra,
    cl.millor_mitjana as mitjana_particular,
    NOW()
  FROM get_social_league_classifications(p_event_id) cl;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN QUERY SELECT TRUE, 
    format('Classificacions generades correctament: %s jugadors classificats', v_count),
    v_count;
END;
$$;

-- Permetre executar la funció
GRANT EXECUTE ON FUNCTION generate_final_classifications(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_final_classifications(UUID) TO anon;

COMMENT ON FUNCTION generate_final_classifications IS 
'Genera i guarda les classificacions finals d''un campionat a la taula classificacions.';

-- ============================================================================
-- Pas 2: Generar classificacions per al Campionat Social 3 Bandes 2025-2026
-- ============================================================================

SELECT * FROM generate_final_classifications('8a81a82e-96c9-4c49-9fbe-b492394462ac');

-- ============================================================================
-- Pas 3: Verificar les classificacions generades
-- ============================================================================

SELECT 
  c.posicio,
  p.nom,
  cat.nom as categoria,
  c.punts,
  c.partides_jugades,
  c.caramboles_favor,
  c.caramboles_contra,
  c.mitjana_particular
FROM classificacions c
JOIN players p ON c.player_id = p.id
JOIN categories cat ON c.categoria_id = cat.id
WHERE c.event_id = '8a81a82e-96c9-4c49-9fbe-b492394462ac'
ORDER BY cat.ordre_categoria, c.posicio
LIMIT 20;
