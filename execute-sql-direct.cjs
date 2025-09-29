require('dotenv').config({ path: '.env.cloud' });

async function executeSQL() {
    const url = process.env.PUBLIC_SUPABASE_URL;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    
    console.log('🔧 Executing SQL via REST API...');
    
    // Simple approach: try to drop and recreate the public access policy only
    const sql = `
    -- Drop existing public access policy if it exists
    DROP POLICY IF EXISTS "calendari_public_access" ON calendari_partides;
    
    -- Create new public access policy
    CREATE POLICY "calendari_public_access" ON calendari_partides
        FOR SELECT USING (
            estat IN ('validat', 'confirmat', 'jugat') 
            AND EXISTS (
                SELECT 1 FROM events e
                WHERE e.id = calendari_partides.event_id
                AND e.calendari_publicat = true
            )
        );
    `;
    
    try {
        const response = await fetch(`${url}/rest/v1/rpc/exec`, {
            method: 'POST',
            headers: {
                'apikey': serviceKey,
                'Authorization': `Bearer ${serviceKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ sql })
        });
        
        const result = await response.text();
        console.log('📊 SQL execution result:', result);
        
        if (!response.ok) {
            console.log('❌ HTTP Error:', response.status, response.statusText);
        } else {
            console.log('✅ SQL executed successfully');
        }
        
    } catch (error) {
        console.log('❌ Fetch error:', error.message);
    }
}

executeSQL().catch(console.error);