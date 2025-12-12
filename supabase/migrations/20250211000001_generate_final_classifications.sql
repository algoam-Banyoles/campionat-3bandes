-- Funció per generar classificacions finals quan es finalitza un campionat
-- Aquesta funció agafa les classificacions de get_social_league_classifications
-- i les guarda a la taula classificacions

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

-- Permetre executar la funció a usuaris autenticats i anon
GRANT EXECUTE ON FUNCTION generate_final_classifications(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_final_classifications(UUID) TO anon;

-- Comentari de la funció
COMMENT ON FUNCTION generate_final_classifications IS 
'Genera i guarda les classificacions finals d''un campionat a la taula classificacions. 
Utilitza la funció get_social_league_classifications per calcular les classificacions 
en base als resultats de les partides jugades.';
