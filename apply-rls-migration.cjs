/**
 * Apply RLS migration to fix public calendar access
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

async function applyMigration() {
    // Load environment variables from .env.cloud
    require('dotenv').config({ path: '.env.cloud' });
    
    const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    
    if (!supabaseUrl || !supabaseServiceKey) {
        console.error('❌ Missing environment variables');
        console.error('PUBLIC_SUPABASE_URL:', supabaseUrl ? '✅' : '❌');
        console.error('SUPABASE_SERVICE_ROLE_KEY:', supabaseServiceKey ? '✅' : '❌');
        return;
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
        auth: {
            autoRefreshToken: false,
            persistSession: false
        }
    });

    console.log('🔗 Connected to cloud database');

    // Read the migration file
    const migrationSQL = fs.readFileSync('migrations_archive/20250929161158_public_calendar_access.sql', 'utf8');
    
    console.log('📋 Applying RLS migration for public calendar access...');

    try {
        // Execute each SQL statement separately
        const statements = migrationSQL
            .split(';')
            .map(stmt => stmt.trim())
            .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));

        for (const statement of statements) {
            if (statement.trim()) {
                console.log('🔄 Executing:', statement.substring(0, 60) + '...');
                
                const { error } = await supabase.rpc('exec_sql', { sql: statement });
                
                if (error) {
                    console.error('❌ Error executing statement:', error.message);
                    console.error('Statement:', statement);
                } else {
                    console.log('✅ Statement executed successfully');
                }
            }
        }

        console.log('🎉 Migration completed!');
        
    } catch (error) {
        console.error('❌ Migration failed:', error);
    }
}

applyMigration();