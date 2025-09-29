require('dotenv').config({ path: '.env.cloud' });
const { createClient } = require('@supabase/supabase-js');

// Test amb usuari anònim per simular el frontend
const supabase = createClient(
  process.env.PUBLIC_SUPABASE_URL, 
  process.env.PUBLIC_SUPABASE_ANON_KEY,
  { auth: { persistSession: false } }
);

async function testMatchResultsFormatting() {
  console.log('🧪 Testing match results formatting like the component would...');
  
  // Get a published event
  const { data: events } = await supabase
    .from('events')
    .select('id, nom')
    .eq('calendari_publicat', true)
    .limit(1);
  
  if (!events || events.length === 0) {
    console.log('❌ No published events found');
    return;
  }
  
  const eventId = events[0].id;
  console.log('🎯 Testing with event:', events[0].nom);
  
  // Call the RPC function (like the component does)
  const { data: matches, error: rpcError } = await supabase
    .rpc('get_match_results_public', { p_event_id: eventId });
  
  if (rpcError) {
    console.log('❌ RPC error:', rpcError);
    return;
  }
  
  if (!matches || matches.length === 0) {
    console.log('ℹ️ No matches found');
    return;
  }
  
  console.log('✅ Found', matches.length, 'matches');
  
  // Simulate the NEW formatPlayerName function
  function formatPlayerName(nom, cognoms) {
    if (!nom && !cognoms) return 'Jugador desconegut';
    const fullName = `${nom || ''} ${cognoms || ''}`.trim();
    return fullName || 'Jugador desconegut';
  }
  
  console.log('\n🔍 Testing player name formatting (NEW WAY):');
  for (let i = 0; i < Math.min(3, matches.length); i++) {
    const match = matches[i];
    const player1Name = formatPlayerName(match.jugador1_nom, match.jugador1_cognoms);
    const player2Name = formatPlayerName(match.jugador2_nom, match.jugador2_cognoms);
    
    console.log(`Match ${i + 1}:`);
    console.log(`  Player 1: ${player1Name}`);
    console.log(`  Player 2: ${player2Name}`);
    console.log(`  Category: ${match.categoria_nom}`);
    console.log('');
  }
  
  console.log('✅ Component should now show proper player names instead of "Desconegut"!');
}

testMatchResultsFormatting();