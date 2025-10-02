-- Migration to fix Function Search Path Mutable warnings
-- Sets search_path for functions to prevent security warnings
-- Created: 2025-10-02

-- Fix search_path for get_match_results_public
ALTER FUNCTION public.get_match_results_public SET search_path = '';

-- Fix search_path for get_eligible_promotions
ALTER FUNCTION public.get_eligible_promotions SET search_path = '';

-- Fix search_path for trg_matches_apply_result
ALTER FUNCTION public.trg_matches_apply_result SET search_path = '';

-- Fix search_path for update_classificacio_timestamp
ALTER FUNCTION public.update_classificacio_timestamp SET search_path = '';

-- Fix search_path for fn_matches_finalize
ALTER FUNCTION public.fn_matches_finalize SET search_path = '';

-- Fix search_path for get_event_public
ALTER FUNCTION public.get_event_public SET search_path = '';

-- Fix search_path for get_classifications_public
ALTER FUNCTION public.get_classifications_public SET search_path = '';

-- Fix search_path for get_social_league_classifications
ALTER FUNCTION public.get_social_league_classifications SET search_path = '';

-- Fix search_path for apply_automatic_promotions
ALTER FUNCTION public.apply_automatic_promotions SET search_path = '';

-- Add comment for documentation
COMMENT ON SCHEMA public IS 'Schema segur amb search_path fixat per funcions - Migration 020';