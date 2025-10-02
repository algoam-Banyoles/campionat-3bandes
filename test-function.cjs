require('dotenv').config({ path: '.env.cloud' });

async function testFunction() {
  const { createClient } = require('@supabase/supabase-js');
  
  console.log('🔍 Environment variables:');
  console.log('PUBLIC_SUPABASE_URL:', process.env.PUBLIC_SUPABASE_URL ? '✅ Set' : '❌ Missing');
  console.log('PUBLIC_SUPABASE_ANON_KEY:', process.env.PUBLIC_SUPABASE_ANON_KEY ? '✅ Set' : '❌ Missing');
  console.log('VITE_SUPABASE_URL:', process.env.VITE_SUPABASE_URL ? '✅ Set' : '❌ Missing');
  console.log('VITE_SUPABASE_ANON_KEY:', process.env.VITE_SUPABASE_ANON_KEY ? '✅ Set' : '❌ Missing');
  
  const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.PUBLIC_SUPABASE_ANON_KEY;
  
  if (!supabaseUrl || !supabaseKey) {
    console.error('❌ Missing required environment variables');
    return;
  }
  
  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log('🧪 Testing get_social_league_classifications function...\n');

  try {
    // Test the function directly with correct parameter name
    const { data, error } = await supabase
      .rpc('get_social_league_classifications', {
        p_event_id: '8a81a82e-96c9-4c49-9fbe-b492394462ac'
      });

    if (error) {
      console.log('❌ Function error:', error);
    } else {
      console.log('✅ Function works!');
      console.log('📊 Results:', data.length, 'classifications');
      if (data.length > 0) {
        console.log('📋 Sample result:');
        console.log(`   ${data[0].nom} ${data[0].cognoms} (${data[0].soci_numero}) - ${data[0].categoria_nom}`);
        console.log(`   Partits: ${data[0].partits_jugats} | Punts: ${data[0].punts_classificacio}`);
      }
    }

    // Also test direct inscripcions query
    console.log('\n🔍 Testing direct inscripcions query...');
    const { data: inscripcions, error: inscripcionsError } = await supabase
      .from('inscripcions')
      .select('*')
      .eq('event_id', '8a81a82e-96c9-4c49-9fbe-b492394462ac')
      .eq('confirmat', true);

    if (inscripcionsError) {
      console.log('❌ Inscripcions error:', inscripcionsError);
    } else {
      console.log('✅ Inscripcions found:', inscripcions.length);
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

testFunction().catch(console.error);