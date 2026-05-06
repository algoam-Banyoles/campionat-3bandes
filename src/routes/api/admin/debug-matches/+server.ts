import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/supabaseClient';

export const GET: RequestHandler = async () => {
  try {
    // 1. Trobar l'event banda 2025-2026
    const { data: events } = await supabase
      .from('events')
      .select('id, nom, modalitat, temporada')
      .eq('tipus_competicio', 'lliga_social')
      .eq('modalitat', 'banda')
      .eq('temporada', '2025-2026');

    if (!events || events.length === 0) {
      return json({ error: 'Event not found' });
    }

    const eventId = events[0].id;

    // 2. Veure totes les partides amb els jugadors 5818 o 8181
    const { data: allMatches } = await supabase
      .from('calendari_partides')
      .select('id, jugador1_soci_numero, jugador2_soci_numero, estat, data_programada, categoria_id')
      .eq('event_id', eventId)
      .or('jugador1_soci_numero.eq.5818,jugador1_soci_numero.eq.8181,jugador2_soci_numero.eq.5818,jugador2_soci_numero.eq.8181');

    console.log(`Found ${allMatches?.length || 0} matches with players 5818 or 8181`);

    return json({
      event: events[0],
      totalMatches: allMatches?.length || 0,
      matches: allMatches || []
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unknown error' });
  }
};
