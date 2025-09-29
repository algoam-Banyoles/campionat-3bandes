import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL } from '$env/static/public';
import { SUPABASE_SERVICE_ROLE_KEY } from '$env/static/private';
import type { RequestHandler } from './$types';

const supabaseAdmin = createClient(PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

export const GET: RequestHandler = async ({ params }) => {
  const { eventId } = params;

  if (!eventId) {
    return json({ error: 'Event ID is required' }, { status: 400 });
  }

  try {
    console.log('🔍 API: Loading classifications for event:', eventId);

    // First get the event to verify it exists and is a social league
    const { data: event, error: eventError } = await supabaseAdmin
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

    if (eventError) {
      console.error('❌ API: Error loading event:', eventError);
      return json({ error: 'Event not found' }, { status: 404 });
    }

    if (!['lliga_social', 'eliminatories'].includes(event.tipus_competicio)) {
      return json({ error: 'Aquest event no és una lliga social o eliminatòria' }, { status: 400 });
    }

    // Get classifications with proper joins using service role
    const { data: classificacionsData, error: classificacionsError } = await supabaseAdmin
      .from('classificacions')
      .select(`
        *,
        player:players (
          id,
          nom,
          email,
          numero_soci
        ),
        categoria:categories (
          id,
          nom,
          ordre_categoria,
          distancia_caramboles
        )
      `)
      .eq('event_id', eventId)
      .order('posicio', { ascending: true });

    console.log('📊 API: Classifications query result:', {
      dataLength: classificacionsData?.length || 0,
      error: classificacionsError
    });

    if (classificacionsError) {
      console.error('❌ API: Error loading classifications:', classificacionsError);
      return json({ error: 'Error loading classifications' }, { status: 500 });
    }

    // If no classifications found, try to get inscriptions as fallback
    if (!classificacionsData || classificacionsData.length === 0) {
      console.log('ℹ️ API: No classifications found, trying inscriptions');

      const { data: inscriptionsData, error: inscriptionsError } = await supabaseAdmin
        .from('inscripcions')
        .select(`
          *,
          socis (
            numero_soci,
            nom,
            cognoms
          ),
          categoria_assignada:categories (
            id,
            nom,
            ordre_categoria,
            distancia_caramboles
          )
        `)
        .eq('event_id', eventId)
        .eq('confirmat', true)
        .order('data_inscripcio', { ascending: true });

      if (inscriptionsError) {
        console.error('❌ API: Error loading inscriptions:', inscriptionsError);
        return json({ error: 'Error loading inscriptions' }, { status: 500 });
      }

      return json({
        event,
        classifications: [],
        inscriptions: inscriptionsData || [],
        hasClassifications: false
      });
    }

    // Return classifications data
    return json({
      event,
      classifications: classificacionsData,
      inscriptions: [],
      hasClassifications: true
    });

  } catch (error) {
    console.error('❌ API: Unexpected error:', error);
    return json({ error: 'Internal server error' }, { status: 500 });
  }
};