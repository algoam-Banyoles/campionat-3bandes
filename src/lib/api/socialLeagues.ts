import { supabase } from '$lib/supabaseClient';
import type { Database } from '$lib/database.types';

// Tipus per als events de lligues socials
export interface SocialLeagueEvent {
  id: string;
  nom: string;
  temporada: string;
  modalitat: 'tres_bandes' | 'lliure' | 'banda';
  tipus_competicio: 'lliga_social';
  estat_competicio: string;
  data_inici: string | null;
  data_fi: string | null;
  actiu: boolean;
  categories: SocialLeagueCategory[];
}

export interface SocialLeagueCategory {
  id: string;
  nom: string;
  distancia_caramboles: number;
  ordre_categoria: number;
  max_entrades: number;
  min_jugadors: number;
  max_jugadors: number;
  classificacions: Classification[];
}

export interface Classification {
  id: string;
  posicio: number;
  player_id: string;
  player_nom: string;
  player_cognom: string;
  partides_jugades: number;
  partides_guanyades: number;
  partides_perdudes: number;
  partides_empat: number;
  punts: number;
  caramboles_favor: number;
  caramboles_contra: number;
  mitjana_particular: number | null;
}

// API FUNCTIONS

/**
 * Obtenir tots els events de lligues socials històrics
 */
export async function getSocialLeagueEvents(): Promise<SocialLeagueEvent[]> {
  const { data: events, error } = await supabase
    .from('events')
    .select(`
      id,
      nom,
      temporada,
      modalitat,
      tipus_competicio,
      estat_competicio,
      data_inici,
      data_fi,
      actiu,
      categories (
        id,
        nom,
        distancia_caramboles,
        ordre_categoria,
        max_entrades,
        min_jugadors,
        max_jugadors
      )
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
    categories: event.categories?.sort((a, b) => a.ordre_categoria - b.ordre_categoria) || []
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
      estat_competicio,
      data_inici,
      data_fi,
      actiu,
      categories (
        id,
        nom,
        distancia_caramboles,
        ordre_categoria,
        max_entrades,
        min_jugadors,
        max_jugadors,
        classificacions (
          id,
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
            cognom
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
    categories: event.categories?.map(category => ({
      ...category,
      classificacions: category.classificacions?.map(cl => ({
        id: cl.id,
        posicio: cl.posicio,
        player_id: cl.player_id,
        player_nom: cl.players?.nom || '',
        player_cognom: cl.players?.cognom || '',
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
 * Obtenir estadístiques generals de les lligues socials
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
        cognom
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
    posicio: cl.posicio,
    player_id: cl.player_id,
    player_nom: cl.players?.nom || '',
    player_cognom: cl.players?.cognom || '',
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
        cognom
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
    if (!result.players || !result.categories?.events) return;

    const playerKey = `${result.players.nom} ${result.players.cognom}`;

    if (!playersMap.has(playerKey)) {
      playersMap.set(playerKey, {
        player: result.players,
        classifications: []
      });
    }

    playersMap.get(playerKey).classifications.push({
      temporada: result.categories.events.temporada,
      modalitat: result.categories.events.modalitat,
      categoria: result.categories.nom,
      posicio: result.posicio,
      punts: result.punts,
      partides_jugades: result.partides_jugades
    });
  });

  return Array.from(playersMap.values());
}