-- RPC per actualitzar l'estat d'una partida
CREATE OR REPLACE FUNCTION public.update_match_status(
  p_match_id UUID,
  p_new_status TEXT
)
RETURNS TABLE(ok BOOLEAN, error TEXT, match_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INT;
BEGIN
  -- Actualitza l'estat
  UPDATE public.calendari_partides
  SET estat = p_new_status
  WHERE id = p_match_id;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  
  IF v_count > 0 THEN
    RETURN QUERY SELECT true, NULL::TEXT, p_match_id;
  ELSE
    RETURN QUERY SELECT false, 'Match not found or already in that status'::TEXT, p_match_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_match_status(UUID, TEXT) TO authenticated, anon;
