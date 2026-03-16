import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { getSupabaseEnv } from '$lib/server/env';
import type { RequestHandler } from './$types';

const { url, key } = getSupabaseEnv(true);

export const GET: RequestHandler = async ({ params, request }) => {
  const { eventId } = params;

  if (!eventId) {
    return json({ error: 'Event ID is required' }, { status: 400 });
  }

  try {
    // Create Supabase client with service role for historical events access
    const supabaseAdmin = createClient(
      url,
      key,
      {
        auth: { persistSession: false, autoRefreshToken: false }
      }
    );

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
      return json({ error: 'Aquest event no és un campionat social o eliminatòria' }, { status: 400 });
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

    if (classificacionsError) {
      console.error('❌ API: Error loading classifications:', classificacionsError);
      return json({ error: 'Error loading classifications' }, { status: 500 });
    }

    // If no classifications found, try to generate them on-the-fly for finalized events
    if (!classificacionsData || classificacionsData.length === 0) {

      // Try to generate classifications if the event is finalized
      if (event.estat_competicio === 'finalitzat') {
        console.log('📊 API: No classifications found for finalized event, generating...');
        try {
          const { data: genResult, error: genError } = await supabaseAdmin
            .rpc('generate_final_classifications', { p_event_id: eventId });

          if (!genError && genResult && genResult.length > 0 && genResult[0].success) {
            console.log('✅ API: Classifications generated:', genResult[0].message);

            // Re-fetch the newly generated classifications
            const { data: newClassifications, error: newClassError } = await supabaseAdmin
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

            if (!newClassError && newClassifications && newClassifications.length > 0) {
              return json({
                event,
                classifications: newClassifications,
                inscriptions: [],
                hasClassifications: true
              });
            }
          }
        } catch (genErr) {
          console.error('⚠️ API: Could not generate classifications:', genErr);
        }
      }

      // Fallback to inscriptions if no classifications could be generated
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