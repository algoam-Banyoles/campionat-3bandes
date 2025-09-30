import { supabase } from '$lib/supabaseClient';
import { createClient } from '@supabase/supabase-js';
import type {
  SocialLeagueEvent,
  SocialLeagueCategory,
  Classification,
  SearchResult,
  Player,
  Soci,
  Inscripcio,
  CalendariPartida,
  ConfiguracioCalendari,
  Category,
  UUID
} from '$lib/types';

// API FUNCTIONS

/**
 * Obtenir tots els events de campionats socials històrics
 */
export async function getSocialLeagueEvents(): Promise<SocialLeagueEvent[]> {
  // Get events without categories first to avoid RLS issues
  const { data: events, error } = await supabase
    .from('events')
    .select(`
      id,
      nom,
      temporada,
      modalitat,
      tipus_competicio,
      format_joc,
      estat_competicio,
      data_inici,
      data_fi,
      max_participants,
      quota_inscripcio,
      actiu,
      creat_el
    `)
    .eq('tipus_competicio', 'lliga_social')
    .order('temporada', { ascending: false })
    .order('modalitat');

  if (error) {
    console.error('Error fetching social league events:', error);
    throw error;
  }

  return events?.map(event => ({
    ...event,
    created_at: event.creat_el, // Map creat_el to created_at for type compatibility
    categories: [] // For now, return empty categories to avoid RLS issues
  })) || [];
}

/**
 * Obtenir un event específic amb les seves categories i classificacions
 */
export async function getSocialLeagueEventById(eventId: string): Promise<SocialLeagueEvent | null> {
  const { data: event, error } = await supabase
    .from('events')
    .select(`
      id,
      nom,
      temporada,
      modalitat,
      tipus_competicio,
      format_joc,
      estat_competicio,
      data_inici,
      data_fi,
      max_participants,
      quota_inscripcio,
      actiu,
      creat_el,
      categories (
        id,
        event_id,
        nom,
        distancia_caramboles,
        ordre_categoria,
        max_entrades,
        min_jugadors,
        max_jugadors,
        promig_minim,
        created_at,
        classificacions (
          id,
          event_id,
          categoria_id,
          soci_id,
          posicio,
          player_id,
          partides_jugades,
          partides_guanyades,
          partides_perdudes,
          partides_empat,
          punts,
          caramboles_favor,
          caramboles_contra,
          mitjana_particular,
          players (
            nom,
            cognoms
          )
        )
      )
    `)
    .eq('id', eventId)
    .eq('tipus_competicio', 'lliga_social')
    .single();

  if (error) {
    console.error('Error fetching social league event:', error);
    throw error;
  }

  if (!event) return null;

  return {
    ...event,
    created_at: event.creat_el, // Map creat_el to created_at for type compatibility
    categories: event.categories?.map(category => ({
      ...category,
      classificacions: category.classificacions?.map(cl => ({
        id: cl.id,
        event_id: cl.event_id,
        categoria_id: cl.categoria_id,
        soci_id: cl.soci_id,
        posicio: cl.posicio,
        player_id: cl.player_id,
        player_nom: cl.players?.nom || '',
        player_cognom: cl.players?.cognoms || '',
        partides_jugades: cl.partides_jugades,
        partides_guanyades: cl.partides_guanyades,
        partides_perdudes: cl.partides_perdudes,
        partides_empat: cl.partides_empat,
        punts: cl.punts,
        caramboles_favor: cl.caramboles_favor,
        caramboles_contra: cl.caramboles_contra,
        mitjana_particular: cl.mitjana_particular
      })).sort((a, b) => a.posicio - b.posicio) || []
    })).sort((a, b) => a.ordre_categoria - b.ordre_categoria) || []
  };
}

/**
 * Obtenir events agrupats per temporada i modalitat
 */
export async function getSocialLeagueEventsBySeasonAndModality(): Promise<{
  [temporada: string]: {
    [modalitat: string]: SocialLeagueEvent;
  };
}> {
  const events = await getSocialLeagueEvents();

  const grouped: { [temporada: string]: { [modalitat: string]: SocialLeagueEvent } } = {};

  events.forEach(event => {
    if (!grouped[event.temporada]) {
      grouped[event.temporada] = {};
    }
    grouped[event.temporada][event.modalitat] = event;
  });

  return grouped;
}

/**
 * Obtenir estadístiques generals dels campionats socials
 */
export async function getSocialLeagueStats(): Promise<{
  total_events: number;
  total_categories: number;
  total_classifications: number;
  events_per_season: { [temporada: string]: number };
  events_per_modality: { [modalitat: string]: number };
}> {
  // Comptar events
  const { data: eventsCount } = await supabase
    .from('events')
    .select('id', { count: 'exact' })
    .eq('tipus_competicio', 'lliga_social');

  // Comptar categories
  const { data: categoriesCount } = await supabase
    .from('categories')
    .select('id', { count: 'exact' });

  // Comptar classificacions
  const { data: classificationsCount } = await supabase
    .from('classificacions')
    .select('id', { count: 'exact' });

  // Events per temporada
  const { data: eventsBySeasonData } = await supabase
    .from('events')
    .select('temporada')
    .eq('tipus_competicio', 'lliga_social');

  const events_per_season: { [temporada: string]: number } = {};
  eventsBySeasonData?.forEach(event => {
    events_per_season[event.temporada] = (events_per_season[event.temporada] || 0) + 1;
  });

  // Events per modalitat
  const { data: eventsByModalityData } = await supabase
    .from('events')
    .select('modalitat')
    .eq('tipus_competicio', 'lliga_social');

  const events_per_modality: { [modalitat: string]: number } = {};
  eventsByModalityData?.forEach(event => {
    if (event.modalitat) {
      events_per_modality[event.modalitat] = (events_per_modality[event.modalitat] || 0) + 1;
    }
  });

  return {
    total_events: eventsCount?.length || 0,
    total_categories: categoriesCount?.length || 0,
    total_classifications: classificationsCount?.length || 0,
    events_per_season,
    events_per_modality
  };
}

/**
 * Obtenir classificacions d'una categoria específica
 */
export async function getCategoryClassifications(categoryId: string): Promise<Classification[]> {
  const { data: classifications, error } = await supabase
    .from('classificacions')
    .select(`
      id,
      event_id,
      categoria_id,
      soci_id,
      posicio,
      player_id,
      partides_jugades,
      partides_guanyades,
      partides_perdudes,
      partides_empat,
      punts,
      caramboles_favor,
      caramboles_contra,
      mitjana_particular,
      players (
        nom,
        cognoms
      )
    `)
    .eq('categoria_id', categoryId)
    .order('posicio');

  if (error) {
    console.error('Error fetching category classifications:', error);
    throw error;
  }

  return classifications?.map(cl => ({
    id: cl.id,
    event_id: cl.event_id,
    categoria_id: cl.categoria_id,
    soci_id: cl.soci_id,
    posicio: cl.posicio,
    player_id: cl.player_id,
    player_nom: Array.isArray(cl.players) ? (cl.players[0] as any)?.nom || '' : (cl.players as any)?.nom || '',
    player_cognom: Array.isArray(cl.players) ? (cl.players[0] as any)?.cognoms || '' : (cl.players as any)?.cognoms || '',
    partides_jugades: cl.partides_jugades,
    partides_guanyades: cl.partides_guanyades,
    partides_perdudes: cl.partides_perdudes,
    partides_empat: cl.partides_empat,
    punts: cl.punts,
    caramboles_favor: cl.caramboles_favor,
    caramboles_contra: cl.caramboles_contra,
    mitjana_particular: cl.mitjana_particular
  })) || [];
}

/**
 * Buscar jugadors en les classificacions
 */
export async function searchPlayerInClassifications(playerName: string): Promise<{
  player: { nom: string; cognom: string };
  classifications: {
    temporada: string;
    modalitat: string;
    categoria: string;
    posicio: number;
    punts: number;
    partides_jugades: number;
  }[];
}[]> {
  const { data: results, error } = await supabase
    .from('classificacions')
    .select(`
      posicio,
      punts,
      partides_jugades,
      players (
        nom,
        cognoms
      ),
      categories (
        nom,
        events (
          temporada,
          modalitat
        )
      )
    `)
    .ilike('players.nom', `%${playerName}%`);

  if (error) {
    console.error('Error searching player classifications:', error);
    throw error;
  }

  // Agrupar per jugador
  const playersMap = new Map();

  results?.forEach(result => {
    const players = Array.isArray(result.players) ? result.players[0] : result.players;
    const categories = Array.isArray(result.categories) ? result.categories[0] : result.categories;
    const events = Array.isArray(categories?.events) ? categories.events[0] : categories?.events;

    if (!players || !events || !categories) return;

    const playerKey = `${players.nom} ${players.cognoms}`;

    if (!playersMap.has(playerKey)) {
      playersMap.set(playerKey, {
        player: { nom: players.nom, cognom: players.cognoms },
        classifications: []
      });
    }

    playersMap.get(playerKey).classifications.push({
      temporada: events.temporada,
      modalitat: events.modalitat,
      categoria: categories.nom,
      posicio: result.posicio,
      punts: result.punts,
      partides_jugades: result.partides_jugades
    });
  });

  return Array.from(playersMap.values());
}

/**
 * Exportar calendari de campionat social a CSV
 */
export async function exportCalendariToCSV(eventId: string): Promise<string> {
  try {
    // First get the calendar matches
    const { data: partides, error: partidesError } = await supabase
      .from('calendari_partides')
      .select(`
        id,
        data_programada,
        hora_inici,
        taula_assignada,
        estat,
        jugador1_id,
        jugador2_id,
        categoria_id
      `)
      .eq('event_id', eventId)
      .order('data_programada')
      .order('hora_inici');

    if (partidesError) {
      console.error('Error fetching calendar matches:', partidesError);
      throw partidesError;
    }

    if (!partides || partides.length === 0) {
      throw new Error('No hi ha partides al calendari per exportar');
    }

    // Get unique player IDs and category IDs
    const playerIds = [...new Set([
      ...partides.map(p => p.jugador1_id),
      ...partides.map(p => p.jugador2_id)
    ].filter(Boolean))];

    const categoryIds = [...new Set(partides.map(p => p.categoria_id).filter(Boolean))];

    // Fetch players and categories separately
    const [playersResult, categoriesResult] = await Promise.all([
      supabase.from('players').select('id, nom').in('id', playerIds),
      supabase.from('categories').select('id, nom').in('id', categoryIds)
    ]);

    // Create lookup maps
    const playersMap = new Map();
    if (playersResult.data) {
      playersResult.data.forEach(player => {
        playersMap.set(player.id, player.nom);
      });
    }

    const categoriesMap = new Map();
    if (categoriesResult.data) {
      categoriesResult.data.forEach(category => {
        categoriesMap.set(category.id, category.nom);
      });
    }

    // Capçalera del CSV
    const headers = ['ID Partida', 'Categoria', 'Data', 'Hora', 'Taula', 'Estat', 'Jugador 1', 'Jugador 2'];

    // Convertir dades a format CSV
    const rows = partides.map(partida => [
      partida.id,
      categoriesMap.get(partida.categoria_id) || '',
      partida.data_programada || '',
      partida.hora_inici || '',
      partida.taula_assignada || '',
      partida.estat || '',
      playersMap.get(partida.jugador1_id) || '',
      playersMap.get(partida.jugador2_id) || ''
    ]);

    // Combinar capçalera i files
    const csvContent = [headers, ...rows]
      .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
      .join('\n');

    return csvContent;
  } catch (error) {
    console.error('Error in exportCalendariToCSV:', error);
    throw error;
  }
}

/**
 * Buscar socis actius per a inscripcions socials
 */
export async function searchActivePlayers(playerName: string): Promise<{
  numero_soci: number;
  nom: string;
  cognoms: string;
  telefon: string | null;
  email: string | null;
  historicalAverage: number | null;
}[]> {
  // Buscar socis actius - cerca en nom o cognoms
  const { data: socis, error } = await supabase
    .from('socis')
    .select('numero_soci, nom, cognoms, telefon, email')
    .eq('de_baixa', false)
    .or(`nom.ilike.%${playerName}%,cognoms.ilike.%${playerName}%`)
    .order('nom');

  if (error) {
    console.error('Error searching active players:', error);
    throw error;
  }

  if (!socis || socis.length === 0) {
    return [];
  }

  // Obtenir mitjanes històriques de les dues últimes temporades
  // Temporada 2024/2025 = any 2025, Temporada 2023/2024 = any 2024
  const currentYear = new Date().getFullYear();
  const lastTwoYears = [currentYear, currentYear - 1];

  const socisNumbers = socis.map(s => s.numero_soci);

  const { data: mitjanes, error: mitjErr } = await supabase
    .from('mitjanes_historiques')
    .select('soci_id, mitjana, year, modalitat')
    .in('soci_id', socisNumbers)
    .in('year', lastTwoYears)
    .eq('modalitat', '3 BANDES'); // Default to 3 BANDES for social leagues

  if (mitjErr) {
    console.warn('Error fetching historical averages:', mitjErr);
  }

  // Combinar dades dels socis amb les seves millors mitjanes històriques
  return socis.map(soci => {
    const playerMitjanes = mitjanes?.filter(m => m.soci_id === soci.numero_soci) || [];
    const bestMitjana = playerMitjanes.length > 0
      ? Math.max(...playerMitjanes.map(m => m.mitjana))
      : null;

    return {
      numero_soci: soci.numero_soci,
      nom: soci.nom,
      cognoms: soci.cognoms || '',
      telefon: soci.telefon,
      email: soci.email,
      historicalAverage: bestMitjana
    };
  });
}

/**
 * Obtenir l'històric de mitjanes d'un jugador per modalitat
 */
export async function getPlayerAverageHistory(playerNumeroSoci: number, modalitat?: string) {
  // Get player ID from numero_soci
  const { data: player, error: playerError } = await supabase
    .from('players')
    .select('id')
    .eq('numero_soci', playerNumeroSoci)
    .single();

  if (playerError || !player) {
    console.error('Error fetching player:', playerError);
    return [];
  }

  // Build query to get classifications with event and category info
  let query = supabase
    .from('classificacions')
    .select(`
      id,
      posicio,
      mitjana_particular,
      punts,
      caramboles_favor,
      caramboles_contra,
      partides_jugades,
      partides_guanyades,
      partides_perdudes,
      event_id,
      categories (
        nom
      ),
      events!inner (
        id,
        nom,
        temporada,
        modalitat,
        tipus_competicio
      )
    `)
    .eq('player_id', player.id)
    .eq('events.tipus_competicio', 'lliga_social')
    .order('events.temporada', { ascending: true });

  // Filter by modality if provided
  if (modalitat) {
    query = query.eq('events.modalitat', modalitat);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Error fetching player history:', error);
    return [];
  }

  // Transform and group by temporada and modalitat
  return (data || []).map((classification: any) => ({
    temporada: classification.events.temporada,
    modalitat: classification.events.modalitat,
    event_nom: classification.events.nom,
    categoria_nom: classification.categories?.nom || '',
    posicio: classification.posicio,
    mitjana_particular: classification.mitjana_particular,
    punts: classification.punts,
    caramboles_favor: classification.caramboles_favor,
    caramboles_contra: classification.caramboles_contra,
    partides_jugades: classification.partides_jugades,
    partides_guanyades: classification.partides_guanyades,
    partides_perdudes: classification.partides_perdudes
  }));
}