import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function applyMigration() {
  console.log('🚀 Applying incompareixences migration...');

  // Read the migration file
  const migrationPath = path.join(__dirname, '..', 'supabase', 'migrations', '20250130000000_add_incompareixences_support.sql');
  const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

  // Split the SQL into individual statements (rough split by semicolons)
  const statements = migrationSQL
    .split(';')
    .map(s => s.trim())
    .filter(s => s.length > 0 && !s.startsWith('--') && s !== 'COMMENT');

  console.log(`📝 Found ${statements.length} SQL statements`);

  for (let i = 0; i < statements.length; i++) {
    const statement = statements[i] + ';';
    console.log(`\n${i + 1}/${statements.length} Executing statement...`);
    console.log('SQL:', statement.substring(0, 100) + '...');

    try {
      const { error } = await supabase.rpc('exec_sql', { sql: statement });

      if (error) {
        console.error(`❌ Error executing statement ${i + 1}:`, error);
        // Continue with next statement
      } else {
        console.log(`✅ Statement ${i + 1} executed successfully`);
      }
    } catch (err) {
      console.error(`❌ Exception executing statement ${i + 1}:`, err);
      // Continue with next statement
    }
  }

  console.log('\n✅ Migration process completed!');
  console.log('\n⚠️  Note: Some statements may have failed. Please check the output above.');
  console.log('You may need to run the SQL manually in the Supabase SQL Editor.');
}

applyMigration();
