const { createClient } = require('@supabase/supabase-js');

// Configuració Supabase
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL || 'https://qbldqtaqawnahuzlzsjs.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI';

const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  try {
    console.log('🔧 Marcant events històrics com a públics...');

    // Marcar tots els events històrics finalitzats com a calendari publicat
    const { data, error } = await supabase
      .from('events')
      .update({ calendari_publicat: true })
      .in('temporada', ['2021-2022', '2022-2023', '2023-2024', '2024-2025'])
      .eq('estat_competicio', 'finalitzat')
      .select('id, nom, temporada');

    if (error) {
      console.error('❌ Error:', error);
      throw error;
    }

    console.log('✅ Events actualitzats:', data?.length || 0);
    console.log('📋 Events marcats com a públics:');
    data?.forEach(event => {
      console.log(`   • ${event.nom} (${event.temporada})`);
    });

    console.log('🎉 Actualització completada!');
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();