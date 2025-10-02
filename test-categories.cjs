require('dotenv').config({ path: '.env.cloud' });

async function testCategories() {
  const { createClient } = require('@supabase/supabase-js');
  
  const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.PUBLIC_SUPABASE_ANON_KEY;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('❌ Missing required environment variables');
    return;
  }
  
  // Test with anon key first (like the component)
  const supabaseAnon = createClient(supabaseUrl, supabaseAnonKey);
  
  // Test with service key to bypass RLS
  const supabaseService = createClient(supabaseUrl, supabaseServiceKey);

  console.log('🧪 Testing categories access...\n');

  const eventId = '8a81a82e-96c9-4c49-9fbe-b492394462ac';

  try {
    // Test with anon key (same as component)
    console.log('🔍 Testing categories with ANON key (like component)...');
    const { data: categoriesAnon, error: categoriesAnonError } = await supabaseAnon
      .from('categories')
      .select('*')
      .eq('event_id', eventId)
      .order('ordre_categoria', { ascending: true });

    if (categoriesAnonError) {
      console.log('❌ Categories (anon) error:', categoriesAnonError);
    } else {
      console.log('✅ Categories (anon) found:', categoriesAnon.length);
    }

    // Test with service key (to bypass RLS)
    console.log('\n🔍 Testing categories with SERVICE key (bypass RLS)...');
    const { data: categoriesService, error: categoriesServiceError } = await supabaseService
      .from('categories')
      .select('*')
      .eq('event_id', eventId)
      .order('ordre_categoria', { ascending: true });

    if (categoriesServiceError) {
      console.log('❌ Categories (service) error:', categoriesServiceError);
    } else {
      console.log('✅ Categories (service) found:', categoriesService.length);
      if (categoriesService.length > 0) {
        console.log('📋 Categories:');
        categoriesService.forEach((cat, index) => {
          console.log(`   ${index + 1}. ${cat.nom} (${cat.distancia_caramboles} caramboles)`);
        });
      }
    }

    // Test classifications function with anon key
    console.log('\n🔍 Testing get_social_league_classifications function (anon)...');
    const { data: classificationsAnon, error: classificationsAnonError } = await supabaseAnon
      .rpc('get_social_league_classifications', {
        p_event_id: eventId
      });

    if (classificationsAnonError) {
      console.log('❌ Classifications (anon) error:', classificationsAnonError);
    } else {
      console.log('✅ Classifications (anon) found:', classificationsAnon.length);
      if (classificationsAnon.length > 0) {
        console.log('\n📋 Classifications by category:');
        
        // Group by category
        const byCategory = {};
        classificationsAnon.forEach(c => {
          if (!byCategory[c.categoria_nom]) {
            byCategory[c.categoria_nom] = [];
          }
          byCategory[c.categoria_nom].push(c);
        });
        
        // Show distribution
        Object.keys(byCategory).sort().forEach(catName => {
          const players = byCategory[catName];
          console.log(`   ${catName}: ${players.length} jugadors`);
          
          // Show first 3 players as sample
          players.slice(0, 3).forEach((player, idx) => {
            console.log(`     ${idx + 1}. ${player.soci_nom} ${player.soci_cognoms} (Pos: ${player.posicio}, Punts: ${player.punts})`);
          });
          if (players.length > 3) {
            console.log(`     ... i ${players.length - 3} més`);
          }
        });
      }
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

testCategories().catch(console.error);