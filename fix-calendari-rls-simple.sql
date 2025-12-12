-- Fix RLS policies for calendari_partides
-- Solution: Use auth.uid() and a helper function instead of querying auth.users directly

-- Step 1: Create a helper function to check if current user is admin
CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_email TEXT;
BEGIN
  -- Get current user's email from auth.users
  SELECT email INTO user_email
  FROM auth.users
  WHERE id = auth.uid();
  
  -- Check if email exists in admins table
  RETURN EXISTS (
    SELECT 1 FROM public.admins
    WHERE admins.email = user_email
  );
END;
$$;

-- Step 2: Drop existing admin policies
DROP POLICY IF EXISTS "calendari_admin_update" ON calendari_partides;
DROP POLICY IF EXISTS "calendari_admin_insert" ON calendari_partides;
DROP POLICY IF EXISTS "calendari_admin_delete" ON calendari_partides;

-- Step 3: Create new admin policies using the helper function

-- UPDATE policy for admins
CREATE POLICY "calendari_admin_update" ON calendari_partides
    FOR UPDATE 
    USING (public.is_current_user_admin())
    WITH CHECK (public.is_current_user_admin());

-- INSERT policy for admins
CREATE POLICY "calendari_admin_insert" ON calendari_partides
    FOR INSERT 
    WITH CHECK (public.is_current_user_admin());

-- DELETE policy for admins
CREATE POLICY "calendari_admin_delete" ON calendari_partides
    FOR DELETE 
    USING (public.is_current_user_admin());

-- Step 4: Verify the setup
DO $$
DECLARE
    admin_count INTEGER;
    policy_count INTEGER;
    func_exists BOOLEAN;
BEGIN
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'is_current_user_admin'
    ) INTO func_exists;
    
    SELECT COUNT(*) INTO admin_count FROM admins;
    SELECT COUNT(*) INTO policy_count 
        FROM pg_policies 
        WHERE tablename = 'calendari_partides' 
        AND cmd IN ('UPDATE', 'INSERT', 'DELETE');
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ RLS POLICIES FIXED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Status:';
    RAISE NOTICE '  - Helper function exists: %', func_exists;
    RAISE NOTICE '  - Admins configured: %', admin_count;
    RAISE NOTICE '  - Write policies created: %', policy_count;
    RAISE NOTICE '';
    
    IF NOT func_exists THEN
        RAISE WARNING '⚠️  Helper function not created!';
    END IF;
    
    IF admin_count = 0 THEN
        RAISE WARNING '⚠️  No admins configured!';
    END IF;
    
    IF policy_count < 3 THEN
        RAISE WARNING '⚠️  Missing write policies!';
    END IF;
    
    RAISE NOTICE '🎯 Test the function:';
    RAISE NOTICE '  SELECT public.is_current_user_admin();';
    RAISE NOTICE '';
END $$;

-- Display current admins
SELECT 
    '📧 Current admin emails:' as info,
    email 
FROM admins;
