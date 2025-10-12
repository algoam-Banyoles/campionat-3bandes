const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabaseUrl = 'https://qbldqtaqawnahuzlzsjs.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function applySQLFile(filePath) {
  console.log(`📄 Llegint ${filePath}...`);
  const sql = fs.readFileSync(filePath, 'utf8');

  console.log('🚀 Aplicant SQL al cloud...');
  const { data, error } = await supabase.rpc('exec_sql', { query: sql });

  if (error) {
    console.error('❌ Error:', error);

    // Try alternative: split and execute statement by statement
    console.log('🔄 Provant executar statement per statement...');
    const statements = sql.split(';').filter(s => s.trim());

    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i].trim();
      if (!stmt || stmt.startsWith('--')) continue;

      console.log(`   Executant statement ${i + 1}/${statements.length}...`);
      const { error: stmtError } = await supabase.rpc('exec_sql', { query: stmt + ';' });

      if (stmtError) {
        console.error(`   ❌ Error en statement ${i + 1}:`, stmtError.message);
      } else {
        console.log(`   ✅ Statement ${i + 1} OK`);
      }
    }
  } else {
    console.log('✅ SQL aplicat correctament!');
  }
}

applySQLFile('./supabase/sql/rpc_get_social_league_classifications_v2.sql')
  .then(() => {
    console.log('\n🎉 Procés completat!');
    process.exit(0);
  })
  .catch(err => {
    console.error('\n💥 Error fatal:', err);
    process.exit(1);
  });
