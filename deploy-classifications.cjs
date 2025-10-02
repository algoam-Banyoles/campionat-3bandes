const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabase = createClient(
  'https://qbldqtaqawnahuzlzsjs.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibGRxdGFxYXduYWh1emx6c2pzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA1OTIwOCwiZXhwIjoyMDcyNjM1MjA4fQ.-tP6NsvVa6vMFcYXRbXjqQsKC-rm5DxUYi6MzJuiAVI'
);

async function deploy() {
  console.log('📦 Deploying classifications function...');

  // Test calling the function first with the active event
  const eventId = '8a81a82e-96c9-4c49-9fbe-b492394462ac';

  const { data, error } = await supabase.rpc('get_social_league_classifications', {
    p_event_id: eventId
  });

  if (error) {
    console.error('❌ Error:', error);
  } else {
    console.log('✅ Function returned', data?.length || 0, 'rows');
    if (data && data.length > 0) {
      console.log('Sample row:', data[0]);
    }
  }
}

deploy();
