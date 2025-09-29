const { createClient } = require('@supabase/supabase-js');

// Configuració Supabase
const supabaseUrl = 'https://qbldqtaqawnahuzlzsjs.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI';

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

async function testAccess() {
  try {
    console.log('🧪 Testing Supabase access with service role...');

    const eventId = '46bd92e1-fbd9-4e71-97c0-6f56df2d5711';
    console.log('🔍 Testing access to event:', eventId);

    // Test 1: Direct event query
    const { data: event, error: eventError } = await supabase
      .from('events')
      .select('*')
      .eq('id', eventId)
      .single();

    if (eventError) {
      console.error('❌ Event query error:', eventError);
    } else {
      console.log('✅ Event found:', event?.nom, event?.temporada);
    }

    // Test 2: Event with categories join
    const { data: eventWithCategories, error: categoriesError } = await supabase
      .from('events')
      .select(`
        id,
        nom,
        temporada,
        modalitat,
        tipus_competicio,
        estat_competicio,
        categories (
          id,
          nom,
          distancia_caramboles,
          ordre_categoria
        )
      `)
      .eq('id', eventId)
      .single();

    if (categoriesError) {
      console.error('❌ Event+Categories query error:', categoriesError);
    } else {
      console.log('✅ Event with categories found:', eventWithCategories?.nom);
      console.log('   Categories:', eventWithCategories?.categories?.length || 0);
    }

    // Test 3: Classifications query
    const { data: classificacions, error: classificacionsError } = await supabase
      .from('classificacions')
      .select(`
        *,
        player:players (
          id,
          nom,
          numero_soci
        ),
        categoria:categories (
          id,
          nom,
          ordre_categoria
        )
      `)
      .eq('event_id', eventId)
      .order('posicio', { ascending: true })
      .limit(5);

    if (classificacionsError) {
      console.error('❌ Classifications query error:', classificacionsError);
    } else {
      console.log('✅ Classifications found:', classificacions?.length || 0);
      classificacions?.forEach((c, i) => {
        console.log(`   ${i+1}. Pos ${c.posicio}: ${c.player?.nom || 'Unknown'} (${c.punts} pts)`);
      });
    }

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

testAccess();