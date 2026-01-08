-- Migration: Fix function search_path security warnings
-- Date: 2025-12-12
-- Purpose: Set proper search_path for SECURITY DEFINER functions
--
-- Supabase recommends using an empty or restricted search_path for SECURITY DEFINER functions
-- to prevent search_path injection attacks. We use 'pg_catalog, public' which is more secure.

-- Fix reactivate_player_in_league function
CREATE OR REPLACE FUNCTION public.reactivate_player_in_league(
  p_event_id UUID,
  p_player_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_soci_numero INTEGER;
  v_rows_updated INTEGER;
BEGIN
  -- Get player's numero_soci
  SELECT numero_soci INTO v_soci_numero
  FROM public.players
  WHERE id = p_player_id;

  IF v_soci_numero IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not found'
    );
  END IF;

  -- Reactivate by setting retired_at to NULL
  UPDATE public.inscripcions
  SET retired_at = NULL
  WHERE event_id = p_event_id
    AND soci_numero = v_soci_numero
    AND retired_at IS NOT NULL;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not found in event or already active'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Player reactivated successfully'
  );
END;
$$;

COMMENT ON FUNCTION public.reactivate_player_in_league(UUID, UUID) IS
'Reactivates a retired player in a league. SECURITY: Uses empty search_path with fully qualified table names.';

-- Fix retire_player_from_league function
CREATE OR REPLACE FUNCTION public.retire_player_from_league(
  p_event_id UUID,
  p_player_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_soci_numero INTEGER;
  v_rows_updated INTEGER;
BEGIN
  -- Get player's numero_soci
  SELECT numero_soci INTO v_soci_numero
  FROM public.players
  WHERE id = p_player_id;

  IF v_soci_numero IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not found'
    );
  END IF;

  -- Retire player by setting retired_at
  UPDATE public.inscripcions
  SET retired_at = NOW()
  WHERE event_id = p_event_id
    AND soci_numero = v_soci_numero
    AND retired_at IS NULL;

  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  IF v_rows_updated = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Player not found in event or already retired'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Player retired successfully'
  );
END;
$$;

COMMENT ON FUNCTION public.retire_player_from_league(UUID, UUID) IS
'Retires a player from a league. SECURITY: Uses empty search_path with fully qualified table names.';
