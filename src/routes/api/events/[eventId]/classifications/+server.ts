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

    const categoriesMap = new Map<string, any>(
      (event.categories ?? []).map((c: any) => [c.id, c])
    );

    // ─── Estratègia 1 ───────────────────────────────────────────────
    // Per a events amb partides actuals, fem servir la RPC en temps real
    // (llegeix de calendari_partides + inscripcions).
    const { data: rpcRows, error: rpcError } = await supabaseAdmin.rpc(
      'get_social_league_classifications',
      { p_event_id: eventId }
    );

    if (rpcError) {
      console.error('❌ API: Error loading classifications RPC:', rpcError);
      // No retornem error: provem amb la taula classificacions
    }

    if (rpcRows && rpcRows.length > 0) {
      const classifications = rpcRows.map((r: any) => ({
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

      return json({
        event,
        classifications,
        inscriptions: [],
        hasClassifications: true,
        source: 'realtime'
      });
    }

    // ─── Estratègia 2 ───────────────────────────────────────────────
    // Events històrics: llegim directament de la taula `classificacions`
    // (guardada) i enriquim amb dades de socis (nom/cognoms) via JOIN.
    const { data: histRows, error: histError } = await supabaseAdmin
      .from('classificacions')
      .select(`
        id,
        event_id,
        categoria_id,
        posicio,
        partides_jugades,
        partides_guanyades,
        partides_perdudes,
        partides_empat,
        punts,
        caramboles_favor,
        caramboles_contra,
        mitjana_particular,
        soci_numero,
        socis:soci_numero (numero_soci, nom, cognoms)
      `)
      .eq('event_id', eventId)
      .order('posicio', { ascending: true });

    if (histError) {
      console.error('❌ API: Error loading historical classifications:', histError);
      return json({ error: 'Error loading classifications' }, { status: 500 });
    }

    if (histRows && histRows.length > 0) {
      const classifications = histRows.map((r: any) => {
        const soci = Array.isArray(r.socis) ? r.socis[0] : r.socis;
        // Per dades històriques no guardem caramboles_totals/entrades_totals
        // separats. La mitjana_particular sol ser caramboles/entrades ja
        // calculada; la conservem tal qual.
        return {
          id: r.id,
          event_id: r.event_id,
          categoria_id: r.categoria_id,
          posicio: r.posicio,
          partides_jugades: r.partides_jugades,
          partides_guanyades: r.partides_guanyades,
          partides_perdudes: r.partides_perdudes,
          partides_empat: r.partides_empat,
          punts: r.punts,
          caramboles_favor: r.caramboles_favor,
          caramboles_contra: r.caramboles_contra,
          caramboles_totals: r.caramboles_favor,
          entrades_totals: null,
          mitjana_particular: r.mitjana_particular,
          mitjana_general: r.mitjana_particular,
          millor_mitjana: null,
          soci_numero: r.soci_numero,
          player: {
            id: null,
            nom: soci?.nom ?? '',
            cognoms: soci?.cognoms ?? '',
            numero_soci: r.soci_numero ?? soci?.numero_soci
          },
          categoria: categoriesMap.get(r.categoria_id) ?? {
            id: r.categoria_id,
            nom: 'Sense categoria',
            ordre_categoria: 999
          }
        };
      });

      return json({
        event,
        classifications,
        inscriptions: [],
        hasClassifications: true,
        source: 'historical'
      });
    }

    // ─── Estratègia 3 ───────────────────────────────────────────────
    // Fallback final: inscripcions (per events en preparació / en curs
    // que encara no tenen ni classificacions guardades).
    const { data: inscriptionsData, error: inscriptionsError } = await supabaseAdmin
      .from('inscripcions')
      .select(`
        *,
        socis (numero_soci, nom, cognoms),
        categoria_assignada:categories (id, nom, ordre_categoria, distancia_caramboles)
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
      hasClassifications: false,
      source: 'inscriptions'
    });
  } catch (error) {
    console.error('❌ API: Unexpected error:', error);
    return json({ error: 'Internal server error' }, { status: 500 });
  }
};
