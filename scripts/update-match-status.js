#!/usr/bin/env node
/**
 * Script para actualizar el estado de la partida Inocentes vs Polls
 * del campionat social de banda 2025/2026 a "pendent_programar"
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL || 'https://rqnjwhigzqvhwcsxmdal.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Error: Falta SUPABASE_URL o SUPABASE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function updateMatchStatus() {
  try {
    console.log('🔍 Buscando evento de campionat social banda 2025/2026...');

    // 1. Trobar l'event
    const { data: events, error: eventError } = await supabase
      .from('events')
      .select('id, nom, modalitat, temporada')
      .eq('tipus_competicio', 'lliga_social')
      .eq('modalitat', 'banda')
      .eq('temporada', '2025-2026')
      .limit(1);

    if (eventError) {
      throw new Error(`Error finding event: ${eventError.message}`);
    }

    if (!events || events.length === 0) {
      console.warn('⚠️ No se encontró evento de campionat social banda 2025/2026');
      return;
    }

    const event = events[0];
    console.log(`✅ Evento encontrado: ${event.nom} (${event.id})`);

    // 2. Trobar la partida
    console.log('🔍 Buscando partida Inocentes (5818) vs Polls (8181)...');

    const { data: matches, error: matchError } = await supabase
      .from('calendari_partides')
      .select('id, jugador1_soci_numero, jugador2_soci_numero, estat, data_programada')
      .eq('event_id', event.id)
      .or('and(jugador1_soci_numero.eq.5818,jugador2_soci_numero.eq.8181),and(jugador1_soci_numero.eq.8181,jugador2_soci_numero.eq.5818)')
      .eq('estat', 'validat');

    if (matchError) {
      throw new Error(`Error finding match: ${matchError.message}`);
    }

    if (!matches || matches.length === 0) {
      console.warn('⚠️ No se encontró partida validada Inocentes vs Polls');
      return;
    }

    const match = matches[0];
    console.log(`✅ Partida encontrada:`);
    console.log(`   ID: ${match.id}`);
    console.log(`   Jugador 1: ${match.jugador1_soci_numero}`);
    console.log(`   Jugador 2: ${match.jugador2_soci_numero}`);
    console.log(`   Estado actual: ${match.estat}`);
    console.log(`   Data programada: ${match.data_programada}`);

    // 3. Actualitzar l'estat
    console.log('\n🔄 Actualizando estado a "pendent_programar"...');

    const { data: updated, error: updateError } = await supabase
      .from('calendari_partides')
      .update({ estat: 'pendent_programar' })
      .eq('id', match.id)
      .select();

    if (updateError) {
      throw new Error(`Error updating match: ${updateError.message}`);
    }

    if (updated && updated.length > 0) {
      const updatedMatch = updated[0];
      console.log(`✅ Partida actualizada correctamente!`);
      console.log(`   ID: ${updatedMatch.id}`);
      console.log(`   Nuevo estado: ${updatedMatch.estat}`);
      console.log(`\n✨ La partida de Inocentes vs Polls ahora aparecerá como "Pendent de programar"`);
    } else {
      console.warn('⚠️ La partida no se actualizó correctamente');
    }
  } catch (error) {
    console.error('❌ Error:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

updateMatchStatus();
