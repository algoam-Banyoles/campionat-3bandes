-- ============================================================================
-- Migració: RPC admin_delete_handicap_event
-- Data: 2026-05-21
-- Descripció: Funció per esborrar completament un event hàndicap i totes les
--   seves dades derivades (config, participants, bracket_slots, matches i
--   calendari_partides). Reutilitzable per a futurs cleanups.
--
-- Protecció d'històric: refusa esborrar events amb
--   estat_competicio = 'finalitzat'. Els campionats acabats sempre queden
--   preservats com a històric (apareixen al dashboard /handicap a la secció
--   "Torneigs anteriors" i són accessibles via /handicap/resum?event={id}).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_delete_handicap_event(p_event_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event events%ROWTYPE;
  v_matches INTEGER;
  v_slots INTEGER;
  v_participants INTEGER;
  v_config INTEGER;
  v_calendari INTEGER;
BEGIN
  -- Defense-in-depth: només admins poden executar
  IF NOT public.is_admin_by_email() THEN
    RAISE EXCEPTION 'No autoritzat: només admins poden esborrar events hàndicap'
      USING ERRCODE = '42501';
  END IF;

  -- Verificar que l'event existeix
  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event no trobat: %', p_event_id
      USING ERRCODE = 'P0002';
  END IF;

  -- Verificar que és de tipus hàndicap (no esborrem accidentalment events socials/continu)
  IF v_event.tipus_competicio IS DISTINCT FROM 'handicap' THEN
    RAISE EXCEPTION 'L''event "%" no és de tipus hàndicap (tipus: %)',
      v_event.nom, COALESCE(v_event.tipus_competicio, 'NULL')
      USING ERRCODE = '22023';
  END IF;

  -- PROTECCIÓ D'HISTÒRIC: refusar si està finalitzat
  IF v_event.estat_competicio = 'finalitzat' THEN
    RAISE EXCEPTION 'L''event "%" està finalitzat i es preserva com a històric. No es pot esborrar via aquesta RPC.',
      v_event.nom
      USING ERRCODE = '42501';
  END IF;

  -- Comptar registres abans d'esborrar (per al resum)
  SELECT count(*) INTO v_matches
    FROM public.handicap_matches WHERE event_id = p_event_id;
  SELECT count(*) INTO v_slots
    FROM public.handicap_bracket_slots WHERE event_id = p_event_id;
  SELECT count(*) INTO v_participants
    FROM public.handicap_participants WHERE event_id = p_event_id;
  SELECT count(*) INTO v_config
    FROM public.handicap_config WHERE event_id = p_event_id;
  SELECT count(*) INTO v_calendari
    FROM public.calendari_partides WHERE event_id = p_event_id;

  -- Esborrar en ordre segur (matches abans que slots per la FK circular)
  DELETE FROM public.handicap_matches WHERE event_id = p_event_id;
  DELETE FROM public.handicap_bracket_slots WHERE event_id = p_event_id;
  DELETE FROM public.handicap_participants WHERE event_id = p_event_id;
  DELETE FROM public.handicap_config WHERE event_id = p_event_id;
  DELETE FROM public.calendari_partides WHERE event_id = p_event_id;
  DELETE FROM public.events WHERE id = p_event_id;

  RETURN json_build_object(
    'ok', true,
    'event_id', p_event_id,
    'event_nom', v_event.nom,
    'event_temporada', v_event.temporada,
    'deleted', json_build_object(
      'handicap_matches', v_matches,
      'handicap_bracket_slots', v_slots,
      'handicap_participants', v_participants,
      'handicap_config', v_config,
      'calendari_partides', v_calendari,
      'events', 1
    ),
    'message', format('Event hàndicap "%s" (%s) esborrat completament.',
                       v_event.nom, v_event.temporada)
  );
END;
$$;

COMMENT ON FUNCTION public.admin_delete_handicap_event(uuid) IS
  'Esborra un event hàndicap i totes les seves dades (config, participants, bracket, matches, calendari). Refusa events finalitzats per preservar l''històric.';

-- Permisos: només authenticated (amb check intern d'admin) i service_role
REVOKE EXECUTE ON FUNCTION public.admin_delete_handicap_event(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_delete_handicap_event(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_handicap_event(uuid)
  TO authenticated, service_role;
