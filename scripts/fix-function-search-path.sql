-- ===============================================
-- FIX FUNCTION SEARCH_PATH SECURITY
-- ===============================================
-- Fixes all functions to prevent search_path injection attacks
-- This script adds SET search_path = '' to all functions

-- trg_challenges_accept
ALTER FUNCTION public.trg_challenges_accept() SET search_path = '';

-- admin_update_settings  
ALTER FUNCTION public.admin_update_settings(json) SET search_path = '';

-- _set_search_path
ALTER FUNCTION public._set_search_path() SET search_path = '';

-- promote_first_waiting
ALTER FUNCTION public.promote_first_waiting(integer) SET search_path = '';

-- schedule_challenge_expiry_notifications
ALTER FUNCTION public.schedule_challenge_expiry_notifications() SET search_path = '';

-- waitlist_append (appears twice in linter - same function)
ALTER FUNCTION public.waitlist_append(integer) SET search_path = '';

-- waitlist_pop_first (appears twice in linter - same function)  
ALTER FUNCTION public.waitlist_pop_first() SET search_path = '';

-- sweep_overdue_challenges_mvp
ALTER FUNCTION public.sweep_overdue_challenges_mvp() SET search_path = '';

-- process_refusal_or_timeout
ALTER FUNCTION public.process_refusal_or_timeout(integer) SET search_path = '';

-- get_waiting_list
ALTER FUNCTION public.get_waiting_list() SET search_path = '';

-- apply_voluntary_leave
ALTER FUNCTION public.apply_voluntary_leave(integer) SET search_path = '';

-- admin_update_challenge_state
ALTER FUNCTION public.admin_update_challenge_state(integer, text) SET search_path = '';

-- run_challenge_deadlines
ALTER FUNCTION public.run_challenge_deadlines() SET search_path = '';

-- enforce_max_rank_gap
ALTER FUNCTION public.enforce_max_rank_gap(integer) SET search_path = '';

-- trg_matches_apply_result
ALTER FUNCTION public.trg_matches_apply_result() SET search_path = '';

-- is_admin (appears twice in linter - same function)
ALTER FUNCTION public.is_admin() SET search_path = '';

-- get_ranking
ALTER FUNCTION public.get_ranking() SET search_path = '';

-- is_admin_by_email
ALTER FUNCTION public.is_admin_by_email(text) SET search_path = '';

-- can_create_challenge
ALTER FUNCTION public.can_create_challenge(integer, integer) SET search_path = '';

-- trg_inc_reprogramacions
ALTER FUNCTION public.trg_inc_reprogramacions() SET search_path = '';

-- fn_challenges_set_positions
ALTER FUNCTION public.fn_challenges_set_positions(integer) SET search_path = '';

-- apply_no_show_win
ALTER FUNCTION public.apply_no_show_win(integer, integer) SET search_path = '';

-- current_player_id
ALTER FUNCTION public.current_player_id() SET search_path = '';

-- record_match_and_resolve
ALTER FUNCTION public.record_match_and_resolve(integer, integer, integer, integer, integer) SET search_path = '';

-- accept_challenge
ALTER FUNCTION public.accept_challenge(integer) SET search_path = '';

-- _app_settings_set_updated_at
ALTER FUNCTION public._app_settings_set_updated_at() SET search_path = '';

-- create_default_notification_preferences
ALTER FUNCTION public.create_default_notification_preferences() SET search_path = '';

-- create_challenge
ALTER FUNCTION public.create_challenge(integer, integer, integer) SET search_path = '';

-- get_posicio
ALTER FUNCTION public.get_posicio(integer) SET search_path = '';

-- update_updated_at_column
ALTER FUNCTION public.update_updated_at_column() SET search_path = '';

-- sweep_overdue_challenges_from_settings_mvp
ALTER FUNCTION public.sweep_overdue_challenges_from_settings_mvp() SET search_path = '';

-- sweep_inactivity_from_settings
ALTER FUNCTION public.sweep_inactivity_from_settings() SET search_path = '';

-- swap_if_below
ALTER FUNCTION public.swap_if_below(integer, integer) SET search_path = '';

-- shift_down_player
ALTER FUNCTION public.shift_down_player(integer) SET search_path = '';

-- fn_matches_finalize
ALTER FUNCTION public.fn_matches_finalize(integer) SET search_path = '';

-- sweep_overdue_challenges_from_settings_mvp2
ALTER FUNCTION public.sweep_overdue_challenges_from_settings_mvp2() SET search_path = '';

-- update_actualitzat_el_column
ALTER FUNCTION public.update_actualitzat_el_column() SET search_path = '';

-- shift_block_down
ALTER FUNCTION public.shift_block_down(integer, integer, integer) SET search_path = '';

-- guard_unique_membership
ALTER FUNCTION public.guard_unique_membership() SET search_path = '';

-- sweep_overdue_challenges_mvp2
ALTER FUNCTION public.sweep_overdue_challenges_mvp2() SET search_path = '';

-- can_create_challenge_detail
ALTER FUNCTION public.can_create_challenge_detail(integer, integer) SET search_path = '';

-- _admins_email_lowercase
ALTER FUNCTION public._admins_email_lowercase() SET search_path = '';

-- resolve_access_challenge
ALTER FUNCTION public.resolve_access_challenge(integer, integer, boolean, integer, integer) SET search_path = '';

-- rotate_waiting_list
ALTER FUNCTION public.rotate_waiting_list() SET search_path = '';

-- penalize_unprogrammed_after_accept
ALTER FUNCTION public.penalize_unprogrammed_after_accept() SET search_path = '';

-- apply_match_result
ALTER FUNCTION public.apply_match_result(integer, integer, integer, integer, integer) SET search_path = '';

-- swap_positions
ALTER FUNCTION public.swap_positions(integer, integer) SET search_path = '';

-- admin_run_maintenance_and_log
ALTER FUNCTION public.admin_run_maintenance_and_log(text) SET search_path = '';

-- sweep_overdue_challenges_from_settings
ALTER FUNCTION public.sweep_overdue_challenges_from_settings() SET search_path = '';

-- trg_challenges_validate
ALTER FUNCTION public.trg_challenges_validate() SET search_path = '';

-- admin_run_maintenance
ALTER FUNCTION public.admin_run_maintenance(text) SET search_path = '';

-- admin_apply_no_show
ALTER FUNCTION public.admin_apply_no_show(integer, integer) SET search_path = '';

-- admin_run_all_sweeps
ALTER FUNCTION public.admin_run_all_sweeps() SET search_path = '';

-- reset_event_to_initial
ALTER FUNCTION public.reset_event_to_initial(integer) SET search_path = '';

-- Verification: Check if any functions still have mutable search_path
-- This should return EMPTY if all are fixed
SELECT 
    proname as function_name,
    'STILL MUTABLE SEARCH_PATH' as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' 
    AND p.proname IN (
        'trg_challenges_accept', 'admin_update_settings', '_set_search_path',
        'promote_first_waiting', 'schedule_challenge_expiry_notifications',
        'waitlist_append', 'waitlist_pop_first', 'sweep_overdue_challenges_mvp',
        'process_refusal_or_timeout', 'get_waiting_list', 'apply_voluntary_leave',
        'admin_update_challenge_state', 'run_challenge_deadlines', 'enforce_max_rank_gap',
        'trg_matches_apply_result', 'is_admin', 'get_ranking', 'is_admin_by_email',
        'can_create_challenge', 'trg_inc_reprogramacions', 'fn_challenges_set_positions',
        'apply_no_show_win', 'current_player_id', 'record_match_and_resolve',
        'accept_challenge', '_app_settings_set_updated_at', 'create_default_notification_preferences',
        'create_challenge', 'get_posicio', 'update_updated_at_column',
        'sweep_overdue_challenges_from_settings_mvp', 'sweep_inactivity_from_settings',
        'swap_if_below', 'shift_down_player', 'fn_matches_finalize',
        'sweep_overdue_challenges_from_settings_mvp2', 'update_actualitzat_el_column',
        'shift_block_down', 'guard_unique_membership', 'sweep_overdue_challenges_mvp2',
        'can_create_challenge_detail', '_admins_email_lowercase', 'resolve_access_challenge',
        'rotate_waiting_list', 'penalize_unprogrammed_after_accept', 'apply_match_result',
        'swap_positions', 'admin_run_maintenance_and_log', 'sweep_overdue_challenges_from_settings',
        'trg_challenges_validate', 'admin_run_maintenance', 'admin_apply_no_show',
        'admin_run_all_sweeps', 'reset_event_to_initial'
    )
    AND prosecdef = false  -- Functions without SECURITY DEFINER
    AND (p.proconfig IS NULL OR NOT p.proconfig::text LIKE '%search_path=%');

-- Show functions that now have fixed search_path
SELECT 
    p.proname as function_name,
    'SEARCH_PATH FIXED' as status,
    p.proconfig as search_path_setting
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' 
    AND p.proname IN (
        'trg_challenges_accept', 'admin_update_settings', '_set_search_path',
        'promote_first_waiting', 'schedule_challenge_expiry_notifications',
        'waitlist_append', 'waitlist_pop_first', 'sweep_overdue_challenges_mvp'
    )
    AND p.proconfig IS NOT NULL 
    AND p.proconfig::text LIKE '%search_path=%'
ORDER BY p.proname;