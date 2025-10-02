require('dotenv').config({ path: '.env.cloud' });

async function testRealClassifications() {
  const { createClient } = require('@supabase/supabase-js');
  
  const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  console.log('🏆 Testing Real Classifications...\n');

  const eventId = '8a81a82e-96c9-4c49-9fbe-b492394462ac';

  try {
    const { data, error } = await supabase.rpc('get_social_league_classifications', {
      p_event_id: eventId
    });

    if (error) {
      console.error('❌ Error calling function:', error);
      return;
    }

    if (!data || data.length === 0) {
      console.log('📭 No classifications found');
      return;
    }

    console.log(`📊 Found ${data.length} players with classifications\n`);

    // Group by category
    const byCategory = {};
    data.forEach(player => {
      const catKey = `${player.categoria_ordre}a Categoria`;
      if (!byCategory[catKey]) {
        byCategory[catKey] = [];
      }
      byCategory[catKey].push(player);
    });

    Object.entries(byCategory).forEach(([category, players]) => {
      console.log(`\n🏅 ${category} (${players[0].categoria_distancia} caramboles):`);
      console.log('Pos | Jugador                    | PJ | PG | CF | CE | EJ | Mitjana');
      console.log('----|---------------------------|----|----|----|----|----|---------');
      
      players.slice(0, 10).forEach(p => {
        const name = `${p.soci_nom} ${p.soci_cognoms}`.substring(0, 25).padEnd(25);
        console.log(
          `${p.posicio.toString().padStart(3)} | ${name} | ${p.partides_jugades.toString().padStart(2)} | ${p.partides_guanyades.toString().padStart(2)} | ${p.caramboles_a_favor.toString().padStart(2)} | ${p.caramboles_en_contra.toString().padStart(2)} | ${p.entrades_jugades.toString().padStart(2)} | ${p.mitjana.toFixed(3)}`
        );
      });
      
      if (players.length > 10) {
        console.log(`... i ${players.length - 10} jugadors més`);
      }
    });

    // Show players with matches played
    const playersWithMatches = data.filter(p => p.partides_jugades > 0);
    console.log(`\n🎯 Players with matches played: ${playersWithMatches.length}`);
    
    if (playersWithMatches.length > 0) {
      console.log('\nTop performers:');
      playersWithMatches
        .sort((a, b) => b.mitjana - a.mitjana)
        .slice(0, 5)
        .forEach((p, idx) => {
          console.log(`${idx + 1}. ${p.soci_nom} ${p.soci_cognoms} - ${p.mitjana.toFixed(3)} mitjana (${p.partides_jugades} partides)`);
        });
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

testRealClassifications().catch(console.error);