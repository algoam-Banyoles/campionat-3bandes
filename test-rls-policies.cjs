require('dotenv').config({ path: '.env.cloud' });
const { createClient } = require('@supabase/supabase-js');

async function testRLSPolicies() {
    console.log('🔍 Testing RLS policies for calendar public access...');

    // Test with anon key (public access)
    const publicSupabase = createClient(
        process.env.PUBLIC_SUPABASE_URL, 
        process.env.PUBLIC_SUPABASE_ANON_KEY
    );

    // Test with service role (admin access)
    const adminSupabase = createClient(
        process.env.PUBLIC_SUPABASE_URL, 
        process.env.SUPABASE_SERVICE_ROLE_KEY
    );

    console.log('\n📊 ADMIN ACCESS (Service Role):');
    try {
        const { data: adminMatches, error: adminError } = await adminSupabase
            .from('calendari_partides')
            .select(`
                id,
                data_programada,
                hora_inici,
                estat,
                event_id,
                events(nom, calendari_publicat)
            `)
            .eq('estat', 'validat')
            .limit(3);

        if (adminError) {
            console.log('❌ Admin Error:', adminError.message);
        } else {
            console.log('✅ Admin can see', adminMatches?.length, 'validated matches');
            adminMatches?.forEach(match => {
                console.log(`  - Event: ${match.events?.nom} (published: ${match.events?.calendari_publicat})`);
            });
        }
    } catch (err) {
        console.log('❌ Admin access failed:', err.message);
    }

    console.log('\n🌐 PUBLIC ACCESS (Anon Key):');
    try {
        const { data: publicMatches, error: publicError } = await publicSupabase
            .from('calendari_partides')
            .select('id, data_programada, hora_inici, estat, event_id')
            .eq('estat', 'validat')
            .limit(3);

        if (publicError) {
            console.log('❌ Public Error:', publicError.message);
            console.log('   Code:', publicError.code);
            console.log('   Details:', publicError.details);
        } else {
            console.log('✅ Public can see', publicMatches?.length, 'validated matches');
        }
    } catch (err) {
        console.log('❌ Public access failed:', err.message);
    }

    // Test direct query to see the difference
    console.log('\n🔍 TESTING PUBLISHED EVENTS ACCESS:');
    try {
        const { data: events, error: eventsError } = await publicSupabase
            .from('events')
            .select('id, nom, calendari_publicat')
            .eq('calendari_publicat', true);
            
        if (eventsError) {
            console.log('❌ Events Error:', eventsError.message);
        } else {
            console.log('✅ Public can see', events?.length, 'published events');
            
            if (events?.length > 0) {
                // Now try a manual check
                const eventId = events[0].id;
                console.log(`\n🎯 Checking matches for event ${events[0].nom} (${eventId}):`);
                
                const { data: manualMatches, error: manualError } = await adminSupabase
                    .from('calendari_partides')
                    .select('id, estat, event_id')
                    .eq('event_id', eventId)
                    .eq('estat', 'validat');
                    
                if (manualError) {
                    console.log('❌ Manual check error:', manualError.message);
                } else {
                    console.log(`📋 Found ${manualMatches?.length} validated matches for this published event`);
                }
            }
        }
    } catch (err) {
        console.log('❌ Events access failed:', err.message);
    }
}

testRLSPolicies().catch(console.error);