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

    // Show first player structure to debug
    console.log('🔍 Sample player data:');
    console.log(JSON.stringify(data[0], null, 2));

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
      console.log(`\n🏅 ${category} (${players[0].categoria_distancia || 'N/A'} caramboles):`);
      console.log('Pos | Jugador                    | PJ | PG | CF | CE | EJ | Mitjana');
      console.log('----|---------------------------|----|----|----|----|----|---------');
      
      players.slice(0, 5).forEach(p => {
        const name = `${p.soci_nom} ${p.soci_cognoms}`.substring(0, 25).padEnd(25);
        const pos = (p.posicio || 0).toString().padStart(3);
        const pj = (p.partides_jugades || 0).toString().padStart(2);
        const pg = (p.partides_guanyades || 0).toString().padStart(2);
        const cf = (p.caramboles_a_favor || 0).toString().padStart(2);
        const ce = (p.caramboles_en_contra || 0).toString().padStart(2);
        const ej = (p.entrades_jugades || 0).toString().padStart(2);
        const mitjana = (p.mitjana || 0).toFixed(3);
        
        console.log(`${pos} | ${name} | ${pj} | ${pg} | ${cf} | ${ce} | ${ej} | ${mitjana}`);
      });
      
      if (players.length > 5) {
        console.log(`... i ${players.length - 5} jugadors més`);
      }
    });

    // Show players with matches played
    const playersWithMatches = data.filter(p => (p.partides_jugades || 0) > 0);
    console.log(`\n🎯 Players with matches played: ${playersWithMatches.length}`);

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

testRealClassifications().catch(console.error);