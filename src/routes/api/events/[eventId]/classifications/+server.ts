import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { getSupabaseEnv } from '$lib/server/env';
import type { RequestHandler } from './$types';

const { url, key } = getSupabaseEnv(true);

export const GET: RequestHandler = async ({ params }) => {
  const { eventId } = params;

  if (!eventId) {
    return json({ error: 'Event ID is required' }, { status: 400 });
  }

  try {
    const supabaseAdmin = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false }
    });

    // Carreguem l'event i les categories
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
      return json(
        { error: 'Aquest event no és un campionat social o eliminatòria' },
        { status: 400 }
      );
    }

    // Usem la RPC actualitzada (post-Fase 5c) que llegeix directament de
    // calendari_partides, sense dependre de la taula `players` (eliminada).
    const { data: rows, error: rpcError } = await supabaseAdmin.rpc(
      'get_social_league_classifications',
      { p_event_id: eventId }
    );

    if (rpcError) {
      console.error('❌ API: Error loading classifications:', rpcError);
      return json({ error: 'Error loading classifications' }, { status: 500 });
    }

    // Format compatible amb el client: cada fila incorpora els camps de
    // categoria i soci niats (com si vinguessin de PostgREST amb joins).
    const categoriesMap = new Map<string, any>(
      (event.categories ?? []).map((c: any) => [c.id, c])
    );

    const classifications = (rows ?? []).map((r: any) => ({
      id: `${r.categoria_id}-${r.soci_numero}`,
      event_id: eventId,
      categoria_id: r.categoria_id,
      posicio: r.posicio,
      partides_jugades: r.partides_jugades,
      partides_guanyades: r.partides_guanyades,
      partides_perdudes: r.partides_perdudes,
      partides_empat: r.partides_empat,
      punts: r.punts,
      caramboles_favor: r.caramboles_totals,
      caramboles_contra: null,
      caramboles_totals: r.caramboles_totals,
      entrades_totals: r.entrades_totals,
      mitjana_particular: r.mitjana_general,
      mitjana_general: r.mitjana_general,
      millor_mitjana: r.millor_mitjana,
      estat_jugador: r.estat_jugador,
      eliminat_per_incompareixences: r.eliminat_per_incompareixences,
      soci_numero: r.soci_numero,
      player: {
        id: null,
        nom: r.soci_nom ?? '',
        cognoms: r.soci_cognoms ?? '',
        numero_soci: r.soci_numero
      },
      categoria: categoriesMap.get(r.categoria_id) ?? {
        id: r.categoria_id,
        nom: r.categoria_nom,
        ordre_categoria: r.categoria_ordre
      }
    }));

    if (classifications.length > 0) {
      return json({
        event,
        classifications,
        inscriptions: [],
        hasClassifications: true
      });
    }

    // Fallback: no hi ha dades de classificacions (ex: event en preparació).
    // Retornem les inscripcions perquè el client pugui mostrar almenys els
    // jugadors apuntats.
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
      .order('data_inscripcio', { ascending: true });

    if (inscriptionsError) {
      console.error('❌ API: Error loading inscriptions:', inscriptionsError);
      return json({ error: 'Error loading inscriptions' }, { status: 500 });
    }

    return json({
      event,
      classifications: [],
      inscriptions: inscriptionsData ?? [],
      hasClassifications: false
    });
  } catch (error) {
    console.error('❌ API: Unexpected error:', error);
    return json({ error: 'Internal server error' }, { status: 500 });
  }
};
