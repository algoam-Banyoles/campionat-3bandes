-- ===============================================
-- DYNAMIC FUNCTION SEARCH_PATH FIX GENERATOR
-- ===============================================
-- This script generates the correct ALTER statements for all functions
-- Run this first to generate the actual fix statements

DO $$
DECLARE
    func_record RECORD;
    fix_statement TEXT;
    total_functions INTEGER := 0;
    fixed_functions INTEGER := 0;
BEGIN
    -- Get all functions that need search_path fixing
    FOR func_record IN
        SELECT 
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments,
            p.oid as function_oid
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
            AND (p.proconfig IS NULL OR NOT p.proconfig::text LIKE '%search_path=%')
        ORDER BY p.proname
    LOOP
        total_functions := total_functions + 1;
        
        -- Build the ALTER statement with correct signature
        fix_statement := 'ALTER FUNCTION ' || func_record.schema_name || '.' || 
                        func_record.function_name || '(' || func_record.arguments || 
                        ') SET search_path = '''';';
        
        -- Execute the fix
        BEGIN
            EXECUTE fix_statement;
            fixed_functions := fixed_functions + 1;
            RAISE NOTICE 'FIXED: % (% functions)', func_record.function_name, func_record.arguments;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'ERROR fixing %: %', func_record.function_name, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== SUMMARY ===';
    RAISE NOTICE 'Total functions found: %', total_functions;
    RAISE NOTICE 'Successfully fixed: %', fixed_functions;
    RAISE NOTICE 'Failed: %', (total_functions - fixed_functions);
    
    -- Verification
    IF fixed_functions > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE 'Verification: Checking if functions are now secure...';
    END IF;
END $$;

-- Final verification query
SELECT 
    'VERIFICATION: Functions still with mutable search_path' as message,
    COUNT(*) as remaining_functions
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
        'rotate_waiting_list', 'penalize_unprogrammed_after_timeout', 'apply_match_result',
        'swap_positions', 'admin_run_maintenance_and_log', 'sweep_overdue_challenges_from_settings',
        'trg_challenges_validate', 'admin_run_maintenance', 'admin_apply_no_show',
        'admin_run_all_sweeps', 'reset_event_to_initial'
    )
    AND (p.proconfig IS NULL OR NOT p.proconfig::text LIKE '%search_path=%');

-- Show functions that are now properly secured
SELECT 
    p.proname as function_name,
    'SEARCH_PATH SECURED ✓' as status,
    p.proconfig as search_path_setting
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
    AND p.proconfig IS NOT NULL 
    AND p.proconfig::text LIKE '%search_path=%' 
    AND p.proname IN (
        'trg_challenges_accept', 'admin_update_settings', '_set_search_path',
        'promote_first_waiting', 'schedule_challenge_expiry_notifications',
        'waitlist_append', 'waitlist_pop_first', 'sweep_overdue_challenges_mvp'
    )
ORDER BY p.proname
LIMIT 10;