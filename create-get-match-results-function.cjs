/**
 * Script per crear la funció get_match_results_public mitjançant l'API REST de Supabase
 */

const { createClient } = require('@supabase/supabase-js');

// Load environment variables from .env.cloud
require('dotenv').config({ path: '.env.cloud' });

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Missing required environment variables');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

async function createFunction() {
    console.log('🔧 Creant funció get_match_results_public...');
    
    const functionSQL = `
-- RPC function to get match results for public access (no authentication required)
-- Updated to read results directly from calendari_partides (for social leagues)
CREATE OR REPLACE FUNCTION get_match_results_public(p_event_id UUID)
RETURNS TABLE (
  id UUID,
  categoria_id UUID,
  data_programada TIMESTAMPTZ,
  hora_inici TIME,
  jugador1_id UUID,
  jugador2_id UUID,
  estat TEXT,
  taula_assignada INTEGER,
  observacions_junta TEXT,
  jugador1_nom TEXT,
  jugador1_cognoms TEXT,
  jugador1_numero_soci INTEGER,
  jugador2_nom TEXT,
  jugador2_cognoms TEXT,
  jugador2_numero_soci INTEGER,
  categoria_nom TEXT,
  categoria_distancia INTEGER,
  caramboles_reptador SMALLINT,
  caramboles_reptat SMALLINT,
  entrades SMALLINT,
  resultat TEXT,
  match_id UUID
)
SECURITY DEFINER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cp.id,
    cp.categoria_id,
    cp.data_programada,
    cp.hora_inici,
    cp.jugador1_id,
    cp.jugador2_id,
    cp.estat,
    cp.taula_assignada,
    cp.observacions_junta,
    s1.nom as jugador1_nom,
    s1.cognoms as jugador1_cognoms,
    p1.numero_soci as jugador1_numero_soci,
    s2.nom as jugador2_nom,
    s2.cognoms as jugador2_cognoms,
    p2.numero_soci as jugador2_numero_soci,
    cat.nom as categoria_nom,
    cat.distancia_caramboles as categoria_distancia,
    -- For social leagues, results are stored directly in calendari_partides
    cp.caramboles_jugador1 as caramboles_reptador,
    cp.caramboles_jugador2 as caramboles_reptat,
    cp.entrades,
    CASE
      WHEN cp.caramboles_jugador1 > cp.caramboles_jugador2 THEN 'guanya_reptador'
      WHEN cp.caramboles_jugador2 > cp.caramboles_jugador1 THEN 'guanya_reptat'
      ELSE 'empat'
    END as resultat,
    cp.match_id
  FROM public.calendari_partides cp
  LEFT JOIN public.players p1 ON cp.jugador1_id = p1.id
  LEFT JOIN public.socis s1 ON p1.numero_soci = s1.numero_soci
  LEFT JOIN public.players p2 ON cp.jugador2_id = p2.id
  LEFT JOIN public.socis s2 ON p2.numero_soci = s2.numero_soci
  LEFT JOIN public.categories cat ON cp.categoria_id = cat.id
  WHERE cp.event_id = p_event_id
    AND cp.estat = 'validat'
    AND cp.caramboles_jugador1 IS NOT NULL
    AND cp.caramboles_jugador2 IS NOT NULL
  ORDER BY cp.data_programada DESC, cp.hora_inici DESC;
END;
$$;

-- Grant execute permission to anonymous users
GRANT EXECUTE ON FUNCTION get_match_results_public(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_match_results_public(UUID) TO authenticated;
`;

    try {
        // Executar la funció mitjançant una consulta SQL raw
        const { data, error } = await supabase.rpc('exec_sql', { sql_statement: functionSQL });
        
        if (error) {
            console.error('❌ Error creant la funció:', error);
            
            // Provem de forma alternativa
            console.log('🔄 Provant mètode alternatiu...');
            
            // Utilitzem fetch directament per executar SQL
            const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${supabaseServiceKey}`,
                    'apikey': supabaseServiceKey
                },
                body: JSON.stringify({ sql_statement: functionSQL })
            });
            
            if (!response.ok) {
                console.error('❌ Error amb mètode alternatiu:', await response.text());
                return false;
            }
            
            console.log('✅ Funció creada amb mètode alternatiu!');
            return true;
        }
        
        console.log('✅ Funció creada correctament!');
        return true;
        
    } catch (err) {
        console.error('❌ Error inesperat:', err);
        return false;
    }
}

async function testFunction() {
    console.log('🧪 Provant la funció...');
    
    try {
        // Obtenir un event actiu
        const { data: events, error: eventsError } = await supabase
            .from('events')
            .select('id')
            .eq('actiu', true)
            .limit(1);
            
        if (eventsError) {
            console.error('❌ Error obtenint events:', eventsError);
            return;
        }
        
        if (!events || events.length === 0) {
            console.log('⚠️  No hi ha events actius per provar');
            return;
        }
        
        const eventId = events[0].id;
        console.log(`🔍 Provant amb event ID: ${eventId}`);
        
        // Provar la funció
        const { data, error } = await supabase.rpc('get_match_results_public', {
            p_event_id: eventId
        });
        
        if (error) {
            console.error('❌ Error provant la funció:', error);
        } else {
            console.log(`✅ La funció funciona! Retorna ${data.length} resultats`);
        }
        
    } catch (err) {
        console.error('❌ Error provant la funció:', err);
    }
}

async function main() {
    console.log('🚀 Iniciant creació de la funció get_match_results_public...');
    
    const success = await createFunction();
    
    if (success) {
        await testFunction();
        console.log('🎉 Procés completat!');
    } else {
        console.log('❌ No s\'ha pogut crear la funció');
        process.exit(1);
    }
}

main().catch(console.error);