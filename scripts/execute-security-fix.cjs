/**
 * 🔧 SECURITY DEFINER VIEWS FIXER
 * 
 * Script per executar operacions DDL a la base de dades de Supabase
 * Específicament per arreglar els warnings de SECURITY DEFINER views
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

// Load environment variables
require('dotenv').config({ path: '.env.cloud' });

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Missing environment variables');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

async function executeSQL(sqlContent) {
    try {
        console.log('🔗 Connecting to Supabase...');
        
        // Split the SQL content into individual statements
        const statements = sqlContent
            .split(';')
            .map(stmt => stmt.trim())
            .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));

        console.log(`📋 Found ${statements.length} SQL statements to execute`);

        for (let i = 0; i < statements.length; i++) {
            const statement = statements[i];
            console.log(`\n🔍 Executing statement ${i + 1}/${statements.length}:`);
            console.log(`   ${statement.substring(0, 60)}...`);

            try {
                // Use the rpc function to execute raw SQL
                const { data, error } = await supabase.rpc('exec_sql', {
                    sql_query: statement
                });

                if (error) {
                    console.error(`❌ Error in statement ${i + 1}:`, error.message);
                    continue;
                }

                console.log(`✅ Statement ${i + 1} executed successfully`);
            } catch (err) {
                console.error(`❌ Exception in statement ${i + 1}:`, err.message);
                continue;
            }
        }

        console.log('\n🎉 Script execution completed!');
        
    } catch (error) {
        console.error('❌ Fatal error:', error.message);
        process.exit(1);
    }
}

// Read the SQL file and execute it
async function main() {
    try {
        const sqlFile = 'scripts/fix-security-definer-warnings.sql';
        console.log(`📖 Reading SQL file: ${sqlFile}`);
        
        const sqlContent = fs.readFileSync(sqlFile, 'utf8');
        console.log(`📄 File loaded successfully (${sqlContent.length} characters)`);
        
        await executeSQL(sqlContent);
        
    } catch (error) {
        console.error('❌ Error reading file:', error.message);
        process.exit(1);
    }
}

main();