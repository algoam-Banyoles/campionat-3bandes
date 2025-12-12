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
  // Get events first
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

  if (!events || events.length === 0) {
    return [];
  }

  // Get all categories for these events
  const eventIds = events.map(e => e.id);
  const { data: categories, error: catError } = await supabase
    .from('categories')
    .select('*')
    .in('event_id', eventIds)
    .order('ordre_categoria');

  if (catError) {
    console.error('Error fetching categories:', catError);
  }

  // Group categories by event_id
  const categoriesByEvent = new Map<string, any[]>();
  categories?.forEach(cat => {
    if (!categoriesByEvent.has(cat.event_id)) {
      categoriesByEvent.set(cat.event_id, []);
    }
    categoriesByEvent.get(cat.event_id)!.push(cat);
  });

  return events.map(event => ({
    ...event,
    created_at: event.creat_el, // Map creat_el to created_at for type compatibility
    categories: categoriesByEvent.get(event.id) || []
  }));
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
  email: string | null;
  historicalAverage: number | null;
}[]> {
  // Normalitzar el text de cerca (eliminar accents i convertir a minúscules)
  const normalizeText = (text: string): string => {
    return text
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, ''); // Elimina els accents
  };

  const searchTermNormalized = normalizeText(playerName);

  // Buscar socis actius - cerca en nom o cognoms (insensible a accents i majúscules)
  // Obtenim tots els socis actius i filtrem en el client per poder buscar sense accents
  const { data: socis, error } = await supabase
    .from('socis')
    .select('numero_soci, nom, cognoms, email')
    .eq('de_baixa', false)
    .order('nom');

  if (error) {
    console.error('Error searching active players:', error);
    throw error;
  }

  // Filtrar en el client per cerca insensible a accents i majúscules
  const filteredSocis = socis?.filter(soci => {
    const nomNormalized = normalizeText(soci.nom || '');
    const cognomsNormalized = normalizeText(soci.cognoms || '');
    return nomNormalized.includes(searchTermNormalized) ||
           cognomsNormalized.includes(searchTermNormalized);
  }) || [];

  if (filteredSocis.length === 0) {
    return [];
  }

  // Obtenir la millor mitjana històrica de les classificacions
  // Primer necessitem obtenir els player_id corresponents als numero_soci
  const socisNumbers = filteredSocis.map(s => s.numero_soci);

  const { data: players, error: playersErr } = await supabase
    .from('players')
    .select('id, numero_soci')
    .in('numero_soci', socisNumbers);

  if (playersErr) {
    console.warn('Error fetching players:', playersErr);
  }

  // Crear un map de numero_soci -> player_id
  const playerIdMap = new Map(players?.map(p => [p.numero_soci, p.id]) || []);

  // Obtenir les millors mitjanes de classificacions
  const playerIds = players?.map(p => p.id) || [];

  const { data: classificacions, error: classErr } = await supabase
    .from('classificacions')
    .select('player_id, mitjana_particular')
    .in('player_id', playerIds)
    .gt('mitjana_particular', 0);

  if (classErr) {
    console.warn('Error fetching classifications:', classErr);
  }

  // Combinar dades dels socis amb les seves millors mitjanes històriques
  return filteredSocis.map(soci => {
    const playerId = playerIdMap.get(soci.numero_soci);
    const playerClassificacions = classificacions?.filter(c => c.player_id === playerId) || [];
    const bestMitjana = playerClassificacions.length > 0
      ? Math.max(...playerClassificacions.map(c => c.mitjana_particular))
      : null;

    return {
      numero_soci: soci.numero_soci,
      nom: soci.nom,
      cognoms: soci.cognoms || '',
      email: soci.email,
      historicalAverage: bestMitjana
    };
  });
}

/**
 * Obtenir graella de resultats creuats (head-to-head) per a una categoria
 */
export async function getHeadToHeadResults(eventId: string, categoriaId: string): Promise<{
  players: Array<{
    id: string;
    nom: string;
    cognoms: string | null;
    numero_soci: number;
  }>;
  matches: Map<string, {
    caramboles: number;
    entrades: number;
    punts: number;
    mitjana: number;
  }>;
}> {
  try {
    console.log('Fetching head-to-head results for:', { eventId, categoriaId });
    
    // Primer, obtenir tots els jugadors inscrits a la categoria
    const { data: inscriptionsData, error: inscriptionsError } = await supabase
      .from('inscripcions')
      .select(`
        id,
        soci_numero,
        socis!inner (
          numero_soci,
          nom,
          cognoms
        )
      `)
      .eq('event_id', eventId)
      .eq('categoria_assignada_id', categoriaId);

    if (inscriptionsError) {
      console.error('Error fetching inscriptions:', inscriptionsError);
      throw inscriptionsError;
    }

    // Obtenir els players IDs dels socis inscrits
    const sociNumbers = inscriptionsData?.map(i => i.soci_numero) || [];
    
    const { data: playersData, error: playersError } = await supabase
      .from('players')
      .select('id, numero_soci')
      .in('numero_soci', sociNumbers);

    if (playersError) {
      console.error('Error fetching players:', playersError);
      throw playersError;
    }

    // Crear mapa de numero_soci -> player_id
    const sociToPlayerMap = new Map<number, string>();
    (playersData || []).forEach(p => sociToPlayerMap.set(p.numero_soci, p.id));

    // Crear llista de jugadors des de les inscripcions
    const playersMap = new Map<string, any>();
    (inscriptionsData || []).forEach((inscription: any) => {
      const playerId = sociToPlayerMap.get(inscription.soci_numero);
      if (playerId && inscription.socis) {
        playersMap.set(playerId, {
          id: playerId,
          nom: inscription.socis.nom,
          cognoms: inscription.socis.cognoms,
          numero_soci: inscription.socis.numero_soci
        });
      }
    });

    console.log(`Found ${playersMap.size} players in category`);

    // Ara obtenir els resultats de les partides
    const { data, error } = await supabase.rpc('get_head_to_head_results', {
      p_event_id: eventId,
      p_categoria_id: categoriaId
    });

    if (error) {
      console.error('Error fetching head-to-head results:', error);
      throw error;
    }

    const matches = new Map<string, any>();

    if (data && data.length > 0) {
      console.log(`Received ${data.length} match records from database`);

      data.forEach((row: any) => {
        // Afegir jugadors de les partides al mapa (per si de cas)
        if (!playersMap.has(row.jugador1_id)) {
          playersMap.set(row.jugador1_id, {
            id: row.jugador1_id,
            nom: row.jugador1_nom,
            cognoms: row.jugador1_cognoms,
            numero_soci: row.jugador1_numero_soci
          });
        }

        if (!playersMap.has(row.jugador2_id)) {
          playersMap.set(row.jugador2_id, {
            id: row.jugador2_id,
            nom: row.jugador2_nom,
            cognoms: row.jugador2_cognoms,
            numero_soci: row.jugador2_numero_soci
          });
        }

        // Add match data for player1 vs player2
        const matchKey = `${row.jugador1_id}_${row.jugador2_id}`;
        matches.set(matchKey, {
          caramboles: row.caramboles_jugador1,
          entrades: row.entrades_jugador1,
          punts: row.punts_jugador1,
          mitjana: parseFloat(row.mitjana_jugador1)
        });

        // Add reverse match data for player2 vs player1
        const reverseMatchKey = `${row.jugador2_id}_${row.jugador1_id}`;

        // Calculate punts_jugador2 from database if available, otherwise calculate
        const punts_jugador2 = row.punts_jugador2 ?? (
          row.caramboles_jugador2 > row.caramboles_jugador1 ? 2 :
          row.caramboles_jugador2 === row.caramboles_jugador1 ? 1 : 0
        );

        const mitjana_jugador2 = row.entrades_jugador2 > 0 ? row.caramboles_jugador2 / row.entrades_jugador2 : 0;

        matches.set(reverseMatchKey, {
          caramboles: row.caramboles_jugador2,
          entrades: row.entrades_jugador2,
          punts: punts_jugador2,
          mitjana: parseFloat(mitjana_jugador2.toFixed(3))
        });
      });
    } else {
      console.log('No match results found yet, showing empty grid with inscribed players');
    }

    // Convert players map to sorted array
    const allPlayers = Array.from(playersMap.values());
    console.log(`Extracted ${allPlayers.length} unique players`);

    // Log if any players have missing data
    const playersWithMissingData = allPlayers.filter(p => !p.nom || !p.cognoms);
    if (playersWithMissingData.length > 0) {
      console.warn(`Warning: ${playersWithMissingData.length} players have missing nom or cognoms:`, playersWithMissingData);
    }

    const players = allPlayers
      .filter(player => player.nom && player.cognoms) // Filter out players with missing data
      .sort((a, b) => {
        const cognomA = a.cognoms || '';
        const cognomB = b.cognoms || '';
        const result = cognomA.localeCompare(cognomB, 'ca');
        return result !== 0 ? result : (a.nom || '').localeCompare(b.nom || '', 'ca');
      });

    console.log(`Returning ${players.length} valid players and ${matches.size} match records`);
    return { players, matches };
  } catch (error) {
    console.error('Error in getHeadToHeadResults:', error);
    throw error;
  }
}

/**
 * Obtenir l'històric de mitjanes d'un jugador per modalitat
 */
export async function getPlayerAverageHistory(playerNumeroSoci: number, modalitat?: string) {
  // Mapatge de modalitats
  const modalitatMapping: Record<string, string> = {
    'tres_bandes': '3 BANDES',
    'lliure': 'LLIURE',
    'banda': 'BANDA'
  };

  // Build query to get historical averages
  let query = supabase
    .from('mitjanes_historiques')
    .select('soci_id, year, modalitat, mitjana')
    .eq('soci_id', playerNumeroSoci)
    .order('year', { ascending: true });

  // Filter by modality if provided
  if (modalitat && modalitatMapping[modalitat]) {
    query = query.eq('modalitat', modalitatMapping[modalitat]);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Error fetching player history:', error);
    return [];
  }

  // Transform data to match expected format
  const modalitatInverseMapping: Record<string, string> = {
    '3 BANDES': 'tres_bandes',
    'LLIURE': 'lliure',
    'BANDA': 'banda'
  };

  const results = (data || []).map((record: any) => ({
    temporada: `${record.year - 1}-${record.year}`, // Convert year to temporada format (e.g., 2024 -> 2023-2024)
    modalitat: modalitatInverseMapping[record.modalitat] || record.modalitat.toLowerCase(),
    event_nom: `Lliga Social ${record.modalitat} ${record.year - 1}-${record.year}`,
    categoria_nom: '', // Not available in mitjanes_historiques
    posicio: 0, // Not available in mitjanes_historiques
    mitjana_particular: record.mitjana,
    punts: 0, // Not available
    caramboles_favor: 0, // Not available
    caramboles_contra: 0, // Not available
    partides_jugades: 0, // Not available
    partides_guanyades: 0, // Not available
    partides_perdudes: 0 // Not available
  }));

  return results;
}