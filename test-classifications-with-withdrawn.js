import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://qbldqtaqawnahuzlzsjs.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testClassifications() {
  console.log('🔍 Testing classifications with withdrawn player...\n');

  // Get the event ID for Campionat Social 3 Bandes 2025-2026
  const { data: events } = await supabase
    .from('events')
    .select('id, nom, temporada')
    .eq('nom', 'Campionat Social 3 Bandes')
    .eq('temporada', '2025-2026')
    .single();

  if (!events) {
    console.log('⚠️ Event not found');
    return;
  }

  console.log('📋 Event:', events.nom, events.temporada);
  console.log('🆔 Event ID:', events.id);

  // Get classifications
  const { data: classifications, error } = await supabase
    .rpc('get_social_league_classifications', {
      p_event_id: events.id
    });

  if (error) {
    console.error('❌ Error:', error);
    return;
  }

  console.log(`\n✅ Found ${classifications.length} players in classifications\n`);

  // Look for withdrawn player (Soci #7967)
  const withdrawnPlayer = classifications.find(c => c.soci_numero === 7967);

  if (withdrawnPlayer) {
    console.log('🎯 WITHDRAWN PLAYER FOUND IN CLASSIFICATIONS:');
    console.log('   Nom:', withdrawnPlayer.soci_nom, withdrawnPlayer.soci_cognoms);
    console.log('   Soci #:', withdrawnPlayer.soci_numero);
    console.log('   Posició:', withdrawnPlayer.posicio);
    console.log('   Categoria:', withdrawnPlayer.categoria_nom);
    console.log('   Estat:', withdrawnPlayer.estat_jugador);
    console.log('   Motiu retirada:', withdrawnPlayer.motiu_retirada);
    console.log('   Partides jugades:', withdrawnPlayer.partides_jugades);
    console.log('   Punts:', withdrawnPlayer.punts);
  } else {
    console.log('❌ WITHDRAWN PLAYER NOT FOUND IN CLASSIFICATIONS!');
    console.log('   Looking for Soci #7967 (Manuel Sánchez Molera)');
    console.log('\n📋 All players found:');
    classifications.forEach(c => {
      console.log(`   - Soci #${c.soci_numero}: ${c.soci_nom} ${c.soci_cognoms} (${c.estat_jugador || 'actiu'})`);
    });
  }

  // Show category distribution
  console.log('\n📊 Category distribution:');
  const byCategory = classifications.reduce((acc, c) => {
    const cat = c.categoria_nom || 'Sense categoria';
    if (!acc[cat]) acc[cat] = [];
    acc[cat].push(c);
    return acc;
  }, {});

  Object.entries(byCategory).forEach(([cat, players]) => {
    console.log(`   ${cat}: ${players.length} jugadors`);
    const withdrawn = players.filter(p => p.estat_jugador === 'retirat');
    if (withdrawn.length > 0) {
      console.log(`      (${withdrawn.length} retirats: ${withdrawn.map(w => `${w.soci_nom} ${w.soci_cognoms}`).join(', ')})`);
    }
  });
}

testClassifications().then(() => {
  console.log('\n✅ Test completed');
  process.exit(0);
}).catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
