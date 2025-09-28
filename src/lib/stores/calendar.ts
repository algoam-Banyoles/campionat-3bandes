// src/lib/stores/calendar.ts
import { writable, derived, get } from 'svelte/store';
import { supabase } from '$lib/supabaseClient';

export type CalendarView = 'month' | 'week';

export type EsdevenimentClub = {
  id: string;
  titol: string;
  descripcio: string | null;
  data_inici: string;
  data_fi: string | null;
  tipus: 'general' | 'torneig' | 'social' | 'manteniment';
  visible_per_tots: boolean;
  creat_per: string | null;
  event_id: string | null;
};

export type RepteCalendari = {
  id: string;
  reptador_nom: string;
  reptat_nom: string;
  data_programada: string;
  estat: string;
  pos_reptador: number | null;
  pos_reptat: number | null;
  observacions: string | null;
};

export type PartidaCalendari = {
  id: string;
  jugador1_nom: string;
  jugador2_nom: string;
  data_programada: string;
  hora_inici: string;
  taula_assignada: number;
  estat: string;
  event_nom: string;
  categoria_nom: string;
  observacions_junta: string | null;
};

export type CalendarEvent = {
  id: string;
  title: string;
  description?: string;
  start: Date;
  end?: Date;
  type: 'challenge' | 'event';
  subtype?: string;
  data?: EsdevenimentClub | RepteCalendari;
};

// Store per la data actual del calendari
export const currentDate = writable(new Date());

// Store per la vista actual (mensual/setmanal)
export const calendarView = writable<CalendarView>('week');

// Store per esdeveniments del club
export const esdeveniments = writable<EsdevenimentClub[]>([]);

// Store per reptes programats
export const reptesProgramats = writable<RepteCalendari[]>([]);

// Store per partides dels campionats socials
export const partidesCalendari = writable<PartidaCalendari[]>([]);

// Store loading
export const calendarLoading = writable(false);

// Store per errors
export const calendarError = writable<string | null>(null);

// Store derivat que combina tots els esdeveniments per al calendari
export const calendarEvents = derived(
  [esdeveniments, reptesProgramats, partidesCalendari],
  ([$esdeveniments, $reptesProgramats, $partidesCalendari]) => {
    const events: CalendarEvent[] = [];
    
    // Afegir esdeveniments del club
    $esdeveniments.forEach(event => {
      events.push({
        id: `event-${event.id}`,
        title: event.titol,
        description: event.descripcio || undefined,
        start: new Date(event.data_inici),
        end: event.data_fi ? new Date(event.data_fi) : undefined,
        type: 'event',
        subtype: event.tipus,
        data: event
      });
    });
    
    // Afegir reptes programats
    $reptesProgramats.forEach(repte => {
      events.push({
        id: `challenge-${repte.id}`,
        title: `🎯 ${repte.reptador_nom} vs ${repte.reptat_nom}`,
        description: repte.observacions || undefined,
        start: new Date(repte.data_programada),
        type: 'challenge',
        subtype: repte.estat,
        data: repte
      });
    });
    
    // Afegir partides dels campionats socials
    $partidesCalendari.forEach(partida => {
      const dataHora = new Date(`${partida.data_programada}T${partida.hora_inici}`);
      events.push({
        id: `match-${partida.id}`,
        title: `🏆 ${partida.jugador1_nom} vs ${partida.jugador2_nom}`,
        description: `${partida.event_nom} - ${partida.categoria_nom}\nTaula: ${partida.taula_assignada}${partida.observacions_junta ? `\n${partida.observacions_junta}` : ''}`,
        start: dataHora,
        type: 'challenge',
        subtype: `campionat-social-${partida.estat}`,
        data: partida
      });
    });
    
    return events.sort((a, b) => a.start.getTime() - b.start.getTime());
  }
);

// Store derivat per obtenir esdeveniments d'un dia específic
export const getEventsForDate = derived(
  calendarEvents,
  ($calendarEvents) => (date: Date) => {
    const targetDate = new Date(date);
    targetDate.setHours(0, 0, 0, 0);
    
    return $calendarEvents.filter(event => {
      const eventDate = new Date(event.start);
      eventDate.setHours(0, 0, 0, 0);
      
      if (event.end) {
        const endDate = new Date(event.end);
        endDate.setHours(23, 59, 59, 999);
        return targetDate >= eventDate && targetDate <= endDate;
      }
      
      return targetDate.getTime() === eventDate.getTime();
    });
  }
);

// Funcions per carregar dades
export async function loadEsdeveniments(): Promise<void> {
  try {
    calendarLoading.set(true);
    calendarError.set(null);
    
    const { data, error } = await supabase
      .from('esdeveniments_club')
      .select('*')
      .order('data_inici', { ascending: true });
    
    if (error) {
      throw new Error(error.message);
    }
    
    esdeveniments.set(data || []);
  } catch (error: any) {
    calendarError.set(error.message);
    esdeveniments.set([]);
  } finally {
    calendarLoading.set(false);
  }
}

export async function loadReptesProgramats(): Promise<void> {
  try {
    calendarLoading.set(true);
    calendarError.set(null);
    
    const { data, error } = await supabase
      .from('challenges')
      .select(`
        id,
        data_programada,
        estat,
        pos_reptador,
        pos_reptat,
        observacions,
        reptador:reptador_id(nom),
        reptat:reptat_id(nom)
      `)
      .not('data_programada', 'is', null)
      .order('data_programada', { ascending: true });
    
    if (error) {
      throw new Error(error.message);
    }
    
    const reptes: RepteCalendari[] = (data || []).map(item => ({
      id: item.id,
      reptador_nom: (item.reptador as any)?.nom || 'Desconegut',
      reptat_nom: (item.reptat as any)?.nom || 'Desconegut',
      data_programada: item.data_programada,
      estat: item.estat,
      pos_reptador: item.pos_reptador,
      pos_reptat: item.pos_reptat,
      observacions: item.observacions
    }));
    
    reptesProgramats.set(reptes);
  } catch (error: any) {
    calendarError.set(error.message);
    reptesProgramats.set([]);
  } finally {
    calendarLoading.set(false);
  }
}

export async function loadPartidesCalendari(): Promise<void> {
  try {
    calendarLoading.set(true);
    calendarError.set(null);
    
    const { data, error } = await supabase
      .from('calendari_partides')
      .select(`
        id,
        data_programada,
        hora_inici,
        taula_assignada,
        estat,
        observacions_junta,
        jugador1:jugador1_id(nom),
        jugador2:jugador2_id(nom),
        events!inner(nom),
        categories!inner(nom)
      `)
      .order('data_programada', { ascending: true });
    
    if (error) {
      throw new Error(error.message);
    }
    
    const partides: PartidaCalendari[] = (data || []).map(item => ({
      id: item.id,
      jugador1_nom: (item.jugador1 as any)?.nom || 'Desconegut',
      jugador2_nom: (item.jugador2 as any)?.nom || 'Desconegut',
      data_programada: item.data_programada,
      hora_inici: item.hora_inici,
      taula_assignada: item.taula_assignada,
      estat: item.estat,
      event_nom: (item.events as any)?.nom || 'Campionat',
      categoria_nom: (item.categories as any)?.nom || 'Categoria',
      observacions_junta: item.observacions_junta
    }));
    
    partidesCalendari.set(partides);
  } catch (error: any) {
    calendarError.set(error.message);
    partidesCalendari.set([]);
  } finally {
    calendarLoading.set(false);
  }
}

export async function deleteEsdeveniment(id: string): Promise<void> {
  try {
    calendarLoading.set(true);
    calendarError.set(null);
    
    const { error } = await supabase
      .from('esdeveniments_club')
      .delete()
      .eq('id', id);
    
    if (error) {
      throw new Error(error.message);
    }
    
    // Actualitzar els stores eliminant l'esdeveniment
    esdeveniments.update(events => events.filter(event => event.id !== id));
    
  } catch (error: any) {
    calendarError.set(error.message);
    throw error;
  } finally {
    calendarLoading.set(false);
  }
}

export async function refreshCalendarData(): Promise<void> {
  await Promise.all([
    loadEsdeveniments(),
    loadReptesProgramats(),
    loadPartidesCalendari()
  ]);
}

// Funcions d'utilitat per dates
export function navigateToDate(date: Date): void {
  currentDate.set(new Date(date));
}

export function navigateToToday(): void {
  currentDate.set(new Date());
}

export function navigateMonth(direction: 1 | -1): void {
  currentDate.update(date => {
    const newDate = new Date(date);
    newDate.setMonth(newDate.getMonth() + direction);
    return newDate;
  });
}

export function navigateWeek(direction: 1 | -1): void {
  currentDate.update(date => {
    const newDate = new Date(date);
    newDate.setDate(newDate.getDate() + (direction * 7));
    return newDate;
  });
}

export function setCalendarView(view: CalendarView): void {
  calendarView.set(view);
}