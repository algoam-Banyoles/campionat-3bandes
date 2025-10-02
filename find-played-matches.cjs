require('dotenv').config({ path: '.env.cloud' });

async function findPlayedMatches() {
  const { createClient } = require('@supabase/supabase-js');
  
  const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  console.log('🔍 Finding the 5 played matches...\n');

  const eventId = '8a81a82e-96c9-4c49-9fbe-b492394462ac';

  try {
    // Get matches with results
    const { data: playedMatches, error } = await supabase
      .from('calendari_partides')
      .select('*')
      .eq('event_id', eventId)
      .not('caramboles_jugador1', 'is', null)
      .not('caramboles_jugador2', 'is', null);

    if (error) {
      console.error('❌ Error:', error);
      return;
    }

    console.log(`🎯 Found ${playedMatches.length} played matches:`);
    
    playedMatches.forEach((match, idx) => {
      console.log(`\n${idx + 1}. Match ID: ${match.id}`);
      console.log(`   Event: ${match.event_id}`);
      console.log(`   Player1: ${match.jugador1_id} - ${match.caramboles_jugador1} caramboles`);
      console.log(`   Player2: ${match.jugador2_id} - ${match.caramboles_jugador2} caramboles`);
      console.log(`   Entries: ${match.entrades}`);
      console.log(`   Date played: ${match.data_joc}`);
      console.log(`   Status: ${match.estat}`);
    });

    // Check if we need to understand the relationship to socis
    if (playedMatches.length > 0) {
      console.log('\n🔗 Now let\'s check how these player IDs relate to socis...\n');
      
      // Get one inscription to see the structure
      const { data: inscription } = await supabase
        .from('inscripcions')
        .select('*')
        .eq('event_id', eventId)
        .limit(1)
        .single();
      
      console.log('📋 Sample inscription structure:');
      console.log(JSON.stringify(inscription, null, 2));
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

findPlayedMatches().catch(console.error);