require('dotenv').config({ path: '.env.cloud' });

async function getTableSchemas() {
  const { createClient } = require('@supabase/supabase-js');
  
  const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.PUBLIC_SUPABASE_ANON_KEY;
  
  if (!supabaseUrl || !supabaseKey) {
    throw new Error('Missing Supabase environment variables');
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log('🔍 Getting schema information for relevant tables...\n');

  const tables = ['inscripcions', 'socis', 'categories', 'calendari_partides'];
  
  for (const tableName of tables) {
    try {
      console.log(`📋 Table: ${tableName}`);
      console.log('='.repeat(50));
      
      const { data, error } = await supabase
        .rpc('get_table_schema', { table_name: tableName });
      
      if (error) {
        // Fallback: try to get a sample record to infer types
        const { data: sampleData, error: sampleError } = await supabase
          .from(tableName)
          .select('*')
          .limit(1);
        
        if (sampleError) {
          console.log(`❌ Error getting schema for ${tableName}:`, sampleError.message);
        } else if (sampleData && sampleData.length > 0) {
          console.log('Sample data (to infer types):');
          const sample = sampleData[0];
          for (const [key, value] of Object.entries(sample)) {
            const type = value === null ? 'null' : typeof value;
            const sqlType = inferSQLType(value);
            console.log(`  ${key}: ${type} (${sqlType}) - ${JSON.stringify(value)}`);
          }
        }
      } else {
        console.log('Schema:');
        console.log(data);
      }
      
      console.log('\n');
    } catch (err) {
      console.error(`❌ Error processing ${tableName}:`, err.message);
    }
  }
}

function inferSQLType(value) {
  if (value === null) return 'nullable';
  if (typeof value === 'string') {
    if (value.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)) return 'timestamp';
    if (value.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)) return 'uuid';
    return 'text';
  }
  if (typeof value === 'number') {
    if (Number.isInteger(value)) {
      if (value >= -32768 && value <= 32767) return 'smallint';
      if (value >= -2147483648 && value <= 2147483647) return 'integer';
      return 'bigint';
    }
    return 'numeric/decimal';
  }
  if (typeof value === 'boolean') return 'boolean';
  if (Array.isArray(value)) return 'array';
  if (typeof value === 'object') return 'jsonb';
  return 'unknown';
}

getTableSchemas().catch(console.error);