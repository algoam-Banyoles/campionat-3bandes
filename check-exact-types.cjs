require('dotenv').config({ path: '.env.cloud' });

async function checkExactTypes() {
  const { createClient } = require('@supabase/supabase-js');
  
  const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.PUBLIC_SUPABASE_ANON_KEY;
  
  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log('🔍 Checking exact data types in categories table...\n');

  try {
    // Get column information from information_schema
    const { data, error } = await supabase
      .from('information_schema.columns')
      .select('column_name, data_type, is_nullable, column_default')
      .eq('table_name', 'categories')
      .eq('table_schema', 'public')
      .order('ordinal_position');

    if (error) {
      console.log('❌ Error:', error.message);
      
      // Fallback: Try raw SQL query
      console.log('🔄 Trying alternative method...');
      const { data: rawData, error: rawError } = await supabase.rpc('exec_sql', {
        sql: `SELECT column_name, data_type, is_nullable, column_default 
              FROM information_schema.columns 
              WHERE table_name = 'categories' AND table_schema = 'public' 
              ORDER BY ordinal_position;`
      });
      
      if (rawError) {
        console.log('❌ Raw query error:', rawError.message);
      } else {
        console.log('✅ Raw query result:', rawData);
      }
    } else {
      console.log('✅ Categories table schema:');
      console.log(data);
    }
  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkExactTypes().catch(console.error);