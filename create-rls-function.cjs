require('dotenv').config({ path: '.env.cloud' });
const { createClient } = require('@supabase/supabase-js');

async function createAndExecuteFunction() {
    const supabase = createClient(
        process.env.PUBLIC_SUPABASE_URL, 
        process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    console.log('🔧 Creating temporary function to execute RLS fixes...');
    
    try {
        // First, create a temporary function to execute our SQL
        const createFunctionSQL = `
        CREATE OR REPLACE FUNCTION temp_fix_rls_policies()
        RETURNS text AS $$
        BEGIN
            -- Drop existing problematic policies
            DROP POLICY IF EXISTS "Calendari visible per tots els usuaris autenticats" ON calendari_partides;
            DROP POLICY IF EXISTS "Public access to published calendar matches" ON calendari_partides;
            DROP POLICY IF EXISTS "Authenticated users can view all calendar matches" ON calendari_partides;
            
            -- Create new public access policy
            EXECUTE 'CREATE POLICY "calendari_public_access" ON calendari_partides
                FOR SELECT USING (
                    estat IN (''validat'', ''confirmat'', ''jugat'') 
                    AND EXISTS (
                        SELECT 1 FROM events e
                        WHERE e.id = calendari_partides.event_id
                        AND e.calendari_publicat = true
                    )
                )';
            
            -- Create authenticated access policy
            EXECUTE 'CREATE POLICY "calendari_auth_access" ON calendari_partides
                FOR SELECT USING (auth.role() = ''authenticated'')';
            
            RETURN 'RLS policies updated successfully';
        END;
        $$ LANGUAGE plpgsql SECURITY DEFINER;
        `;
        
        console.log('📝 Creating function...');
        const { error: createError } = await supabase.rpc('exec_sql', { sql: createFunctionSQL });
        
        if (createError) {
            // Try direct query approach
            console.log('⚠️ Function creation via RPC failed, trying direct approach...');
            
            // Let's try using the JavaScript client to update policies manually
            // First, check if we can access the auth system
            const { data: adminCheck, error: adminError } = await supabase.auth.getUser();
            console.log('👤 Auth check:', adminCheck ? 'Has session' : 'No session');
            
            // Try a simple test query to see what permissions we have
            const { data: testData, error: testError } = await supabase
                .from('calendari_partides')
                .select('id')
                .limit(1);
                
            if (testError) {
                console.log('❌ Test query error:', testError.message);
            } else {
                console.log('✅ Test query successful, found', testData?.length, 'records');
            }
            
            return;
        }
        
        console.log('✅ Function created, executing...');
        const { data: result, error: execError } = await supabase.rpc('temp_fix_rls_policies');
        
        if (execError) {
            console.log('❌ Function execution error:', execError.message);
        } else {
            console.log('✅ Function result:', result);
        }
        
        // Clean up: drop the temporary function
        console.log('🧹 Cleaning up...');
        await supabase.rpc('exec_sql', { sql: 'DROP FUNCTION IF EXISTS temp_fix_rls_policies()' });
        
    } catch (error) {
        console.log('❌ Unexpected error:', error.message);
    }
}

createAndExecuteFunction().catch(console.error);