import type { PageServerLoad } from './$types';
import { supabase } from '$lib/supabaseClient';
import { error } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ params }) => {
  const { eventId } = params;

  try {
    // Carregar event i verificar que existeix
    const { data: event, error: eventError } = await supabase
      .from('events')
      .select('*')
      .eq('id', eventId)
      .eq('tipus_competicio', 'lliga_social')
      .single();

    if (eventError || !event) {
      throw error(404, 'Event no trobat');
    }

    // Carregar categories de l'event
    const { data: categories, error: categoriesError } = await supabase
      .from('categories')
      .select('*')
      .eq('event_id', eventId)
      .order('ordre_categoria');

    if (categoriesError) {
      console.error('Error loading categories:', categoriesError);
    }

    // Carregar configuració del calendari
    const { data: calendarConfig, error: configError } = await supabase
      .from('configuracio_calendari')
      .select('*')
      .eq('event_id', eventId)
      .single();

    if (configError && configError.code !== 'PGRST116') {
      console.error('Error loading calendar config:', configError);
    }

    // Carregar partits del calendari
    const { data: matches, error: matchesError } = await supabase
      .from('calendari_partides')
      .select(`
        *,
        categories!inner (
          nom,
          ordre_categoria
        ),
        jugador1:players!calendari_partides_jugador1_id_fkey (
          nom,
          cognoms,
          numero_soci
        ),
        jugador2:players!calendari_partides_jugador2_id_fkey (
          nom,
          cognoms,
          numero_soci
        )
      `)
      .eq('event_id', eventId)
      .order('data_programada', { ascending: true });

    if (matchesError) {
      console.error('Error loading matches:', matchesError);
    }

    return {
      event,
      categories: categories || [],
      matches: matches || [],
      calendarConfig: calendarConfig || {
        dies_setmana: ['dl', 'dt', 'dc', 'dj', 'dv'],
        hores_disponibles: ['18:00', '19:00'],
        taules_per_slot: 3
      }
    };

  } catch (e) {
    console.error('Error loading event data:', e);
    throw error(500, 'Error carregant les dades de l\'event');
  }
};