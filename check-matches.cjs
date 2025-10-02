require('dotenv').config({ path: '.env.cloud' });

async function checkMatches() {
  const { createClient } = require('@supabase/supabase-js');
  
  const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  console.log('🔍 Checking for played matches...\n');

  const eventId = '8a81a82e-96c9-4c49-9fbe-b492394462ac';

  try {
    // Count total matches
    const { count: totalMatches } = await supabase
      .from('calendari_partides')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', eventId);

    console.log('📊 Total matches scheduled:', totalMatches);

    // Count matches with results
    const { count: matchesWithResults } = await supabase
      .from('calendari_partides')
      .select('*', { count: 'exact', head: true })
      .eq('event_id', eventId)
      .not('caramboles_jugador1', 'is', null)
      .not('caramboles_jugador2', 'is', null);

    console.log('🏁 Matches with results:', matchesWithResults);

    // Get some matches with results (if any)
    if (matchesWithResults > 0) {
      const { data: playedMatches } = await supabase
        .from('calendari_partides')
        .select('*')
        .eq('event_id', eventId)
        .not('caramboles_jugador1', 'is', null)
        .not('caramboles_jugador2', 'is', null)
        .limit(3);

      console.log('\n📋 Sample played matches:');
      playedMatches.forEach((match, idx) => {
        console.log(`${idx + 1}. Player1: ${match.caramboles_jugador1} vs Player2: ${match.caramboles_jugador2} (${match.entrades} entrades)`);
      });
    }

    // Count matches by estado
    const { data: matchesByStatus } = await supabase
      .from('calendari_partides')
      .select('estat')
      .eq('event_id', eventId);

    const statusCount = {};
    matchesByStatus.forEach(match => {
      statusCount[match.estat] = (statusCount[match.estat] || 0) + 1;
    });

    console.log('\n📈 Matches by status:');
    Object.entries(statusCount).forEach(([status, count]) => {
      console.log(`   ${status}: ${count} matches`);
    });

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkMatches().catch(console.error);