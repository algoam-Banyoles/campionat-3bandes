import { supabase } from '$lib/supabaseClient';
import { createClient } from '@supabase/supabase-js';
import type {
  SocialLeagueEvent,
  SocialLeagueCategory,
  Classification,
  SearchResult,
  Soci,
  Inscripcio,
  CalendariPartida,
  ConfiguracioCalendari,
  Category,
  UUID
} from '$lib/types';
import { fkOne, normalizeSociFromFK } from '$lib/utils/supabaseJoins';

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
          soci_numero,
          partides_jugades,
          partides_guanyades,
          partides_perdudes,
          partides_empat,
          punts,
          caramboles_favor,
          caramboles_contra,
          mitjana_particular,
          socis:socis!classificacions_soci_numero_fkey (
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
      classificacions: category.classificacions?.map((cl: any) => {
        const soci = normalizeSociFromFK(cl.socis);
        return {
          id: cl.id,
          event_id: cl.event_id,
          categoria_id: cl.categoria_id,
          soci_id: cl.soci_id,
          posicio: cl.posicio,
          soci_numero: cl.soci_numero,
          player_nom: soci.nom || '',
          player_cognom: soci.cognoms || '',
          partides_jugades: cl.partides_jugades,
          partides_guanyades: cl.partides_guanyades,
          partides_perdudes: cl.partides_perdudes,
          partides_empat: cl.partides_empat,
          punts: cl.punts,
          caramboles_favor: cl.caramboles_favor,
          caramboles_contra: cl.caramboles_contra,
          mitjana_particular: cl.mitjana_particular
        };
      }).sort((a: any, b: any) => a.posicio - b.posicio) || []
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
  const { count: eventsCount } = await supabase
    .from('events')
    .select('id', { count: 'exact', head: true })
    .eq('tipus_competicio', 'lliga_social');

  // Comptar categories
  const { count: categoriesCount } = await supabase
    .from('categories')
    .select('id', { count: 'exact', head: true });

  // Comptar classificacions
  const { count: classificationsCount } = await supabase
    .from('classificacions')
    .select('id', { count: 'exact', head: true });

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
    total_events: eventsCount ?? 0,
    total_categories: categoriesCount ?? 0,
    total_classifications: classificationsCount ?? 0,
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
      soci_numero,
      partides_jugades,
      partides_guanyades,
      partides_perdudes,
      partides_empat,
      punts,
      caramboles_favor,
      caramboles_contra,
      mitjana_particular,
      socis:socis!classificacions_soci_numero_fkey (
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

  return classifications?.map((cl: any) => {
    const soci = normalizeSociFromFK(cl.socis);
    return {
      id: cl.id,
      event_id: cl.event_id,
      categoria_id: cl.categoria_id,
      soci_id: cl.soci_id,
      posicio: cl.posicio,
      soci_numero: cl.soci_numero,
      player_nom: soci.nom || '',
      player_cognom: soci.cognoms || '',
      partides_jugades: cl.partides_jugades,
      partides_guanyades: cl.partides_guanyades,
      partides_perdudes: cl.partides_perdudes,
      partides_empat: cl.partides_empat,
      punts: cl.punts,
      caramboles_favor: cl.caramboles_favor,
      caramboles_contra: cl.caramboles_contra,
      mitjana_particular: cl.mitjana_particular
    };
  }) || [];
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
  // Fase 5c-S3: accedim directament a `socis` via FK `soci_numero`
  // (la taula `players` ja no existeix).
  const { data: results, error } = await supabase
    .from('classificacions')
    .select(`
      posicio,
      punts,
      partides_jugades,
      soci_numero,
      socis:socis!classificacions_soci_numero_fkey (
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
    .limit(1000);

  if (error) {
    console.error('Error searching player classifications:', error);
    throw error;
  }

  // Agrupar per jugador (filtrar per nom al client per permetre cerca insensible a accents)
  const playersMap = new Map();

  results?.forEach(result => {
    const soci = fkOne((result as any).socis);
    const categories = fkOne((result as any).categories);
    const events = fkOne((categories as any)?.events);

    if (!soci || !events || !categories) return;

    const nom = (soci as any).nom ?? '';
    const cognoms = (soci as any).cognoms ?? '';

    // Filtre al client (el .ilike de PostgREST no pot filtrar a través de FK fàcilment)
    if (!nom.toLowerCase().includes(playerName.toLowerCase()) &&
        !cognoms.toLowerCase().includes(playerName.toLowerCase())) return;

    const playerKey = `${nom} ${cognoms}`.trim();

    if (!playersMap.has(playerKey)) {
      playersMap.set(playerKey, {
        player: { nom, cognom: cognoms },
        classifications: []
      });
    }

    playersMap.get(playerKey).classifications.push({
      temporada: (events as any).temporada,
      modalitat: (events as any).modalitat,
      categoria: (categories as any).nom,
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
    // First get the calendar matches (Fase 5c-S2c-2: usem soci_numero directe)
    const { data: partides, error: partidesError } = await supabase
      .from('calendari_partides')
      .select(`
        id,
        data_programada,
        hora_inici,
        taula_assignada,
        estat,
        jugador1_soci_numero,
        jugador2_soci_numero,
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

    // Get unique soci numbers and category IDs
    const sociNumbers = [...new Set([
      ...partides.map(p => p.jugador1_soci_numero),
      ...partides.map(p => p.jugador2_soci_numero)
    ].filter(Boolean))] as number[];

    const categoryIds = [...new Set(partides.map(p => p.categoria_id).filter(Boolean))];

    // Fetch socis i categories en paral·lel
    const [sociResult, categoriesResult] = await Promise.all([
      supabase
        .from('socis')
        .select('numero_soci, nom, cognoms')
        .in('numero_soci', sociNumbers),
      supabase.from('categories').select('id, nom').in('id', categoryIds)
    ]);

    // Create lookup maps (numero_soci → fullName)
    const playersMap = new Map<number, string>();
    if (sociResult.data) {
      sociResult.data.forEach((s: any) => {
        playersMap.set(s.numero_soci, `${s.nom ?? ''} ${s.cognoms ?? ''}`.trim());
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
      playersMap.get(partida.jugador1_soci_numero as any) || '',
      playersMap.get(partida.jugador2_soci_numero as any) || ''
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
  // Apliquem un filtre server-side per limitar la descàrrega i refinem al client (accents).
  const { data: socis, error } = await supabase
    .from('socis')
    .select('numero_soci, nom, cognoms')
    .eq('de_baixa', false)
    .or(`nom.ilike.%${playerName}%,cognoms.ilike.%${playerName}%`)
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

  // Obtenir la millor mitjana històrica de les classificacions.
  // Fase 5c-S2c-2: ja podem filtrar directament per `soci_numero` sense
  // passar per la taula `players`.
  const socisNumbers = filteredSocis.map(s => s.numero_soci);

  const { data: classificacions, error: classErr } = await supabase
    .from('classificacions')
    .select('soci_numero, mitjana_particular')
    .in('soci_numero', socisNumbers)
    .gt('mitjana_particular', 0);

  if (classErr) {
    console.warn('Error fetching classifications:', classErr);
  }

  // Combinar dades dels socis amb les seves millors mitjanes històriques
  return filteredSocis.map(soci => {
    const sociClass = classificacions?.filter((c: any) => c.soci_numero === soci.numero_soci) || [];
    const bestMitjana = sociClass.length > 0
      ? Math.max(...sociClass.map((c: any) => c.mitjana_particular))
      : null;

    return {
      numero_soci: soci.numero_soci,
      nom: soci.nom,
      cognoms: soci.cognoms || '',
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
    
    // Obtenir jugadors inscrits via RPC (funciona per anònims i autenticats)
    const { data: inscriptionsData, error: inscriptionsError } = await supabase
      .rpc('get_inscripcions_with_socis', { p_event_id: eventId });

    if (inscriptionsError) {
      console.error('Error fetching inscriptions via RPC:', inscriptionsError);
      throw inscriptionsError;
    }

    // Filtrar per categoria i excloure retirats/desqualificats
    const activeInscriptions = (inscriptionsData || []).filter((i: any) =>
      i.categoria_assignada_id === categoriaId &&
      i.estat_jugador !== 'retirat' && !i.eliminat_per_incompareixences
    );

    // Obtenir els soci_numeros dels inscrits actius
    const sociNumbers = activeInscriptions.map((i: any) => i.soci_numero) || [];

    // Crear llista de jugadors des de les inscripcions (clau = soci_numero)
    const playersMap = new Map<string, any>();
    activeInscriptions.forEach((inscription: any) => {
      const key = String(inscription.soci_numero);
      if (!playersMap.has(key)) {
        playersMap.set(key, {
          id: key,
          nom: inscription.nom,
          cognoms: inscription.cognoms,
          numero_soci: inscription.soci_numero
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
        const j1Key = String(row.jugador1_numero_soci);
        const j2Key = String(row.jugador2_numero_soci);

        // Afegir jugadors de les partides al mapa (per si de cas)
        if (!playersMap.has(j1Key)) {
          playersMap.set(j1Key, {
            id: j1Key,
            nom: row.jugador1_nom,
            cognoms: row.jugador1_cognoms,
            numero_soci: row.jugador1_numero_soci
          });
        }

        if (!playersMap.has(j2Key)) {
          playersMap.set(j2Key, {
            id: j2Key,
            nom: row.jugador2_nom,
            cognoms: row.jugador2_cognoms,
            numero_soci: row.jugador2_numero_soci
          });
        }

        // Add match data for player1 vs player2
        const matchKey = `${j1Key}_${j2Key}`;
        matches.set(matchKey, {
          caramboles: row.caramboles_jugador1,
          entrades: row.entrades_jugador1,
          punts: row.punts_jugador1,
          mitjana: parseFloat(row.mitjana_jugador1)
        });

        // Add reverse match data for player2 vs player1
        const reverseMatchKey = `${j2Key}_${j1Key}`;

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
 * Resultat d'una partida head-to-head amb context d'event i categoria.
 */
export interface HeadToHeadHistoryMatch {
  id: string;
  event_id: string;
  event_nom: string | null;
  event_temporada: string | null;
  event_modalitat: string | null;
  categoria_id: string | null;
  categoria_nom: string | null;
  data_joc: string | null;
  data_programada: string | null;
  /** Caramboles de player1 (l'usuari hi posa el seu primer soci en la query). */
  caramboles_player1: number;
  caramboles_player2: number;
  entrades: number | null;
  /** 1 = player1 guanya, 2 = player2 guanya, 0 = empat. */
  winner: 0 | 1 | 2;
}

export interface HeadToHeadHistorySummary {
  matches: HeadToHeadHistoryMatch[];
  player1Wins: number;
  player2Wins: number;
  draws: number;
  player1TotalCaramboles: number;
  player2TotalCaramboles: number;
  totalEntrades: number;
}

/**
 * Llegeix totes les partides jugades entre dos socis a través de tots
 * els events. Retorna els resultats amb `caramboles_player1` reordenats
 * perquè sempre corresponguin a `player1SociNumero`.
 */
export async function getHeadToHeadHistory(
  player1SociNumero: number,
  player2SociNumero: number
): Promise<HeadToHeadHistorySummary> {
  if (!player1SociNumero || !player2SociNumero || player1SociNumero === player2SociNumero) {
    return {
      matches: [],
      player1Wins: 0,
      player2Wins: 0,
      draws: 0,
      player1TotalCaramboles: 0,
      player2TotalCaramboles: 0,
      totalEntrades: 0
    };
  }

  const { data, error } = await supabase
    .from('calendari_partides')
    .select(
      `
      id,
      event_id,
      categoria_id,
      data_joc,
      data_programada,
      jugador1_soci_numero,
      jugador2_soci_numero,
      caramboles_jugador1,
      caramboles_jugador2,
      entrades,
      partida_anullada,
      events ( nom, temporada, modalitat ),
      categories ( nom )
    `
    )
    .or(
      `and(jugador1_soci_numero.eq.${player1SociNumero},jugador2_soci_numero.eq.${player2SociNumero}),and(jugador1_soci_numero.eq.${player2SociNumero},jugador2_soci_numero.eq.${player1SociNumero})`
    )
    .not('caramboles_jugador1', 'is', null)
    .not('caramboles_jugador2', 'is', null)
    .or('partida_anullada.is.null,partida_anullada.eq.false')
    .order('data_joc', { ascending: false, nullsFirst: false });

  if (error) {
    console.error('Error fetching head-to-head history:', error);
    throw error;
  }

  const matches: HeadToHeadHistoryMatch[] = [];
  let player1Wins = 0;
  let player2Wins = 0;
  let draws = 0;
  let player1TotalCaramboles = 0;
  let player2TotalCaramboles = 0;
  let totalEntrades = 0;

  for (const row of (data || []) as any[]) {
    const evt = fkOne(row.events) as any;
    const cat = fkOne(row.categories) as any;
    // Normalitzem perquè caramboles_player1 sempre correspongui a player1SociNumero
    const isPlayer1First = row.jugador1_soci_numero === player1SociNumero;
    const car1 = isPlayer1First ? row.caramboles_jugador1 : row.caramboles_jugador2;
    const car2 = isPlayer1First ? row.caramboles_jugador2 : row.caramboles_jugador1;

    let winner: 0 | 1 | 2 = 0;
    if (car1 > car2) winner = 1;
    else if (car2 > car1) winner = 2;
    else winner = 0;

    if (winner === 1) player1Wins++;
    else if (winner === 2) player2Wins++;
    else draws++;
    player1TotalCaramboles += car1 || 0;
    player2TotalCaramboles += car2 || 0;
    totalEntrades += row.entrades || 0;

    matches.push({
      id: row.id,
      event_id: row.event_id,
      event_nom: evt?.nom ?? null,
      event_temporada: evt?.temporada ?? null,
      event_modalitat: evt?.modalitat ?? null,
      categoria_id: row.categoria_id,
      categoria_nom: cat?.nom ?? null,
      data_joc: row.data_joc,
      data_programada: row.data_programada,
      caramboles_player1: car1,
      caramboles_player2: car2,
      entrades: row.entrades,
      winner
    });
  }

  return {
    matches,
    player1Wins,
    player2Wins,
    draws,
    player1TotalCaramboles,
    player2TotalCaramboles,
    totalEntrades
  };
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
    event_nom: `Social ${record.modalitat} ${record.year - 1}-${record.year}`,
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
