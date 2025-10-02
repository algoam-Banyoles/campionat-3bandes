require('dotenv').config({ path: '.env.cloud' });

async function debugClassificationsComponent() {
  const { createClient } = require('@supabase/supabase-js');
  
  const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  console.log('🔍 Debugging SocialLeagueClassifications component...\n');

  const eventId = '8a81a82e-96c9-4c49-9fbe-b492394462ac';

  try {
    console.log('1. 📂 Testing categories load...');
    // Test how the component loads categories
    const { data: categories, error: categoriesError } = await supabase
      .from('categories')
      .select('*')
      .eq('event_id', eventId)
      .order('ordre_categoria', { ascending: true });

    if (categoriesError) {
      console.error('❌ Categories error:', categoriesError);
    } else {
      console.log('✅ Categories loaded:', categories.length);
      categories.forEach(cat => {
        console.log(`   - ${cat.nom} (${cat.ordre_categoria}a, ${cat.distancia_caramboles} caramboles)`);
      });
    }

    console.log('\n2. 🏆 Testing classifications RPC...');
    // Test the RPC function call
    const { data: classifications, error: classificationsError } = await supabase
      .rpc('get_social_league_classifications', {
        p_event_id: eventId
      });

    if (classificationsError) {
      console.error('❌ Classifications error:', classificationsError);
    } else {
      console.log('✅ Classifications loaded:', classifications.length);
      
      // Group by category
      const byCategory = {};
      classifications.forEach(cl => {
        if (!byCategory[cl.categoria_id]) {
          byCategory[cl.categoria_id] = [];
        }
        byCategory[cl.categoria_id].push(cl);
      });

      console.log('\n📊 Classifications by category:');
      Object.entries(byCategory).forEach(([catId, players]) => {
        const categoryName = players[0]?.categoria_nom || 'Unknown';
        const playersWithMatches = players.filter(p => p.partides_jugades > 0).length;
        console.log(`   - ${categoryName}: ${players.length} players (${playersWithMatches} with matches)`);
      });
    }

    console.log('\n3. 📅 Testing last match date...');
    // Test last match loading
    const { data: lastMatch, error: lastMatchError } = await supabase
      .from('calendari_partides')
      .select('data_joc')
      .eq('event_id', eventId)
      .eq('estat', 'validat')
      .not('caramboles_jugador1', 'is', null)
      .not('caramboles_jugador2', 'is', null)
      .order('data_joc', { ascending: false })
      .limit(1)
      .single();

    if (lastMatchError) {
      console.error('❌ Last match error:', lastMatchError);
    } else {
      console.log('✅ Last match date:', lastMatch.data_joc);
    }

    console.log('\n4. 🔧 Component logic simulation...');
    // Simulate component logic
    if (categories && categories.length > 0 && classifications && classifications.length > 0) {
      console.log('✅ Component should display classifications');
      
      // Check if categories match classifications
      const categoryIds = new Set(categories.map(c => c.id));
      const classificationCategoryIds = new Set(classifications.map(c => c.categoria_id));
      
      console.log('📂 Category IDs from categories table:', Array.from(categoryIds));
      console.log('🏆 Category IDs from classifications:', Array.from(classificationCategoryIds));
      
      const missingCategories = Array.from(categoryIds).filter(id => !classificationCategoryIds.has(id));
      const extraCategories = Array.from(classificationCategoryIds).filter(id => !categoryIds.has(id));
      
      if (missingCategories.length > 0) {
        console.log('⚠️  Categories without classifications:', missingCategories);
      }
      if (extraCategories.length > 0) {
        console.log('⚠️  Classifications without categories:', extraCategories);
      }
      
    } else {
      console.log('❌ Component should show "No categories" message');
      console.log(`   Categories: ${categories?.length || 0}`);
      console.log(`   Classifications: ${classifications?.length || 0}`);
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

debugClassificationsComponent().catch(console.error);