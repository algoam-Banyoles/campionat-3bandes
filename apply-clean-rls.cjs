require('dotenv').config({ path: '.env.cloud' });
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

async function applyCleanRLS() {
    const supabase = createClient(
        process.env.PUBLIC_SUPABASE_URL, 
        process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    console.log('🔧 Applying clean RLS policies...');
    
    const sql = fs.readFileSync('fix-rls-clean.sql', 'utf8');
    
    // Split into individual statements
    const statements = sql
        .split(';')
        .map(stmt => stmt.trim())
        .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));

    for (const statement of statements) {
        if (statement.trim()) {
            try {
                console.log('🔄 Executing:', statement.substring(0, 50) + '...');
                
                const { error } = await supabase.rpc('exec_sql', { sql: statement });
                
                if (error) {
                    console.log('❌ Error:', error.message);
                } else {
                    console.log('✅ Success');
                }
            } catch (err) {
                console.log('❌ Exception:', err.message);
            }
        }
    }
    
    console.log('🎉 RLS policies update completed!');
}

applyCleanRLS().catch(console.error);