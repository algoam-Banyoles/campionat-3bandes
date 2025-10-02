// Test simple count
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.cloud' });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

async function testCount() {
  try {
    const { count, error } = await supabase
      .from('inscripcions')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', '8a81a82e-96c9-4c49-9fbe-b492394462ac')
      .eq('confirmat', true);

    if (error) throw error;
    
    console.log(`📊 Total inscripcions confirmades: ${count}`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

testCount();